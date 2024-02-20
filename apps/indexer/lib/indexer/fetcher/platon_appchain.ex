defmodule Indexer.Fetcher.PlatonAppchain do
  @moduledoc """
  Contains common functions for PlatonAppchain.* fetchers.
  """
  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query
  import Bitwise

  import EthereumJSONRPC,
         only: [fetch_block_number_by_tag: 2, json_rpc: 2, integer_to_quantity: 1, quantity_to_integer: 1, request: 1]

  import Explorer.Helper, only: [parse_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Indexer.{Helper}
  alias Explorer.Chain.PlatonAppchain
  alias Indexer.Fetcher.PlatonAppchain.{L1Event, L1Execute, L2Event, L2Execute, L2ValidatorEvent, Commitment, Checkpoint}


  @fetcher_name :platon_appchain

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    Logger.metadata(fetcher: @fetcher_name)

    :ignore
  end


  # 周期类型：roung: 共识周期; epoch：结算周期
  @period_type [round: 1, epoch: 2]
  @l1_events_tx_type [deposit: 1, stake: 2, addStake: 3, delegate: 4]

  @l2_events_tx_type [withdraw: 1, stakeWithdraw: 2, degationWithdraw: 3]

  @l2_validator_event_action_type [ValidatorRegistered: 1, StakeAdded: 2, DegationAdded: 3, UnStaked: 4, UnDelegated: 5, Slashed: 6]

  @l2_validator_status [Valid: 0b0000, Invalid: 0b0001, LowBlocks: 0b0010, LowThreshold: 0b0100, Duplicated: 0b1000, Unstaked: 0b00100000, Slashing: 0b01000000]

  # 缺省的出块间隔时间，毫秒
  @default_block_interval 1000
  @block_check_interval_range_size 100

  # 0-candidate(质押节点) 1-active(201共识节点后续人) 2-verifying(43共识节点)
  @l2_validator_role %{Active: 0, Verifying: 1, Candidate: 2}

  def l2_round_size() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_round_size]
  end

  def l2_epoch_size() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_epoch_size]
  end

  def l2_rpc_arguments() do
    json_rpc_named_arguments(l2_rpc_url())
  end

  def l1_rpc_arguments() do
    json_rpc_named_arguments(l1_rpc_url())
  end

  def l2_rpc_url() do
    System.get_env("ETHEREUM_JSONRPC_HTTP_URL")
  end

  def l1_rpc_url() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:platon_appchain_l1_rpc]
  end

  def l2_validator_contract_address() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_validator_contract_address]
  end


  def default_block_interval() do
    @default_block_interval
  end

  def period_type() do
    @period_type
  end

  def l1_events_tx_type() do
    @l1_events_tx_type
  end

  def l2_events_tx_type() do
    @l2_events_tx_type
  end

  def l2_validator_event_action_type() do
    @l2_validator_event_action_type
  end


  def l2_validator_role() do
    @l2_validator_role
  end

  def l2_validator_status() do
    @l2_validator_status
  end

  def l2_validator_is_slashed(status) do
    @l2_validator_status[:Slashing] == band(@l2_validator_status[:Slashing], status)
  end

  def l2_validator_is_unstaked(status) do
    @l2_validator_status[:Unstaked] == band(@l2_validator_status[:Unstaked], status)
  end

  def l2_validator_is_duplicated(status) do
    @l2_validator_status[:Duplicated] == band(@l2_validator_status[:Duplicated], status)
  end

  def l2_validator_is_lowBlocks(status) do
    @l2_validator_status[:LowBlocks] == band(@l2_validator_status[:LowBlocks], status)
  end

  def l2_validator_is_lowThreshold(status) do
    @l2_validator_status[:LowThreshold] == band(@l2_validator_status[:LowThreshold], status)
  end

  def l2_validator_is_invalid(status) do
    @l2_validator_status[:Invalid] == band(@l2_validator_status[:Invalid], status)
  end

  def calculateL2Round(current_block_number, round_size) do
    if rem(current_block_number,round_size)==0 do
      div(current_block_number, round_size)
    else
      div(current_block_number, round_size) + 1
    end
  end

  def calculateNextL2RoundBlockNumber(current_block_number, round_size) do
    next_round = calculateL2Round(current_block_number, round_size)
    next_round * round_size + 1
  end

  def calculateL2Epoch(current_block_number, epoch_size) do
    if rem(current_block_number,epoch_size)==0 do
      div(current_block_number, epoch_size)
    else
      div(current_block_number, epoch_size) + 1
    end
  end

  def calculateNextL2EpochBlockNumber(current_block_number, epoch_size) do
    epoch = calculateL2Epoch(current_block_number, epoch_size)
    epoch * epoch_size + 1
  end


  # 返回 JSON rpc 请求时的参数
  def json_rpc_named_arguments(rpc_url) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: rpc_url,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          list(),
          list(),
          non_neg_integer()
        ) :: {:ok, list()} | {:error, term()}
  def get_logs_by_topics(from_block, to_block, address, topics, json_rpc_named_arguments, retries) do
    processed_from_block = if is_integer(from_block), do: integer_to_quantity(from_block), else: from_block
    processed_to_block = if is_integer(to_block), do: integer_to_quantity(to_block), else: to_block

    req =
      request(%{
        id: 0,
        method: "eth_getLogs",
        params: [
          %{
            :fromBlock => processed_from_block,
            :toBlock => processed_to_block,
            :address => address,
            :topics => topics
          }
        ]
      })

    error_message = &"Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          binary(),
          list(),
          non_neg_integer()
        ) :: {:ok, list()} | {:error, term()}
  def get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries) do
    get_logs_by_topics(from_block, to_block, address, [topic0], json_rpc_named_arguments, retries)
#    processed_from_block = if is_integer(from_block), do: integer_to_quantity(from_block), else: from_block
#    processed_to_block = if is_integer(to_block), do: integer_to_quantity(to_block), else: to_block
#
#    req =
#      request(%{
#        id: 0,
#        method: "eth_getLogs",
#        params: [
#          %{
#            :fromBlock => processed_from_block,
#            :toBlock => processed_to_block,
#            :address => address,
#            :topics => [topic0]
#          }
#        ]
#      })
#
#    error_message = &"Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(&1)}"
#
#    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  defp get_transaction_by_hash(hash, json_rpc_named_arguments, retries) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    error_message = &"eth_getTransactionByHash failed. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp get_last_l1_item(table) when table in [Explorer.Chain.PlatonAppchain.L1Event, Explorer.Chain.PlatonAppchain.L1Execute] do
    query =
      from(item in table,
        select: {item.block_number, item.hash},
        order_by: [desc: item.event_id],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end
  defp get_last_l1_item(table) when table in [Explorer.Chain.PlatonAppchain.Checkpoint] do
    query =  from(item in table,
      select: {item.block_number, item.hash},
      order_by: [desc: item.block_number],
      limit: 1
    )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end


  @spec get_last_l2_item(module()) :: {non_neg_integer(), binary() | nil}
  def get_last_l2_item(table) when table in [Explorer.Chain.PlatonAppchain.L2Event, Explorer.Chain.PlatonAppchain.L2Execute] do
    query =
      from(item in table,
        select: {item.block_number, item.hash},
        order_by: [desc: item.event_id],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  def get_last_l2_item(table) when table in [Explorer.Chain.PlatonAppchain.L2ValidatorEvent, Explorer.Chain.PlatonAppchain.Commitment] do
    query =
      from(item in table,
        select: {item.block_number, item.hash},
        order_by: [desc: item.block_number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end


  defp get_block_check_interval(json_rpc_named_arguments) do
    {last_safe_block, _} = get_safe_block(json_rpc_named_arguments)

    first_block = max(last_safe_block - @block_check_interval_range_size, 1)

    with {:ok, first_block_timestamp} <-
           get_block_timestamp_by_number(first_block, json_rpc_named_arguments, 100_000_000),
         {:ok, last_safe_block_timestamp} <-
           get_block_timestamp_by_number(last_safe_block, json_rpc_named_arguments, 100_000_000) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (last_safe_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")
      {:ok, block_check_interval, last_safe_block}
    else
      {:error, error} ->
        {:error, "Failed to calculate block check interval due to #{inspect(error)}"}
    end
  end

  defp get_safe_block(json_rpc_named_arguments) do
    {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
    {latest_block, true}
#    case get_block_number_by_tag("safe", json_rpc_named_arguments) do
#      {:ok, safe_block} ->
#        {safe_block, false}
#
#      {:error, :not_found} ->
#        {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
#        {latest_block, true}
#    end
  end

  @spec repeated_request(list(), any(), list(), non_neg_integer()) :: {:ok, any()} | {:error, atom()}
  def repeated_request(req, error_message, json_rpc_named_arguments, retries) do
    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  @spec get_latest_block_number(list()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_latest_block_number(json_rpc_named_arguments) do
    get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
  end


  defp get_block_timestamp_by_number_inner(number, json_rpc_named_arguments) do
    result =
      %{id: 0, number: number}
      |> ByNumber.request(false, is_integer(number))
      |> json_rpc(json_rpc_named_arguments)

    with {:ok, block} <- result,
         false <- is_nil(block),
         timestamp <- Map.get(block, "timestamp"),
         false <- is_nil(timestamp) do
      {:ok, quantity_to_integer(timestamp)}
    else
      {:error, message} ->
        {:error, message}

      true ->
        {:error, "RPC returned nil."}
    end
  end

  defp get_block_miner_by_number_inner(number, json_rpc_named_arguments) do
    result =
      %{id: 0, number: number}
      |> ByNumber.request(false)
      |> json_rpc(json_rpc_named_arguments)

    with {:ok, block} <- result,
         false <- is_nil(block),
         miner <- Map.get(block, "miner"),
         false <- is_nil(miner),
         timestamp <- Map.get(block, "timestamp"),
         false <- is_nil(timestamp) do
      {:ok, miner, quantity_to_integer(timestamp)}
    else
      {:error, message} ->
        {:error, message}

      true ->
        {:error, "RPC returned nil."}
    end
  end

  def get_block_timestamp_by_number(number, json_rpc_named_arguments, retries) do
    func = &get_block_timestamp_by_number_inner/2
    args = [number, json_rpc_named_arguments]
    error_message = &"Cannot fetch block ##{number} or its timestamp. Error: #{inspect(&1)}"
    repeated_call(func, args, error_message, retries)
  end

  def get_block_miner_by_number(number, json_rpc_named_arguments, retries) do
    func = &get_block_miner_by_number_inner/2
    args = [number, json_rpc_named_arguments]
    error_message = &"Cannot fetch block ##{number} or its miner. Error: #{inspect(&1)}"
    repeated_call(func, args, error_message, retries)
  end

  @spec get_block_number_by_tag(binary(), list(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_block_number_by_tag(tag, json_rpc_named_arguments, retries \\ 3) do
    error_message = &"Cannot fetch #{tag} block number. Error: #{inspect(&1)}"
    repeated_call(&fetch_block_number_by_tag/2, [tag, json_rpc_named_arguments], error_message, retries)
  end

  defp repeated_call(func, args, error_message, retries_left) do
    case apply(func, args) do
      {:ok, _} = res ->
        res
      {:ok, _, _} = res ->
        res
      {:error, message} = err ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          Logger.error(error_message.(message))
          err
        else
          Logger.error("#{error_message.(message)} Retrying...")
          :timer.sleep(3000)
          repeated_call(func, args, error_message, retries_left)
        end
    end
  end

  @spec import_validators(list()) :: list()
  def import_validators(validators) do
    import_data = %{l2_validators: %{params: validators}, timeout: :infinity}
    {:ok, _} = Chain.import(import_data)
    validators
  end

  @spec log_validators(list(), binary(), integer(), integer(), integer(), binary()) :: any()
  def log_validators(validators, validatorType, periodType, period, block, layer) do
    periodName =
      if period_type()[:round] == periodType do
        "round"
      else
        "epoch"
      end
    Logger.info("#{length(validators)} validators (type:#{validatorType}} imported at block #{block} on #{layer}, period_type = #{periodName}, period = #{period}")
  end

  # todo: 考虑加入cache，因为同一个区块有多个事件需要获取所在区块的时间戳
  @spec get_timestamps_by_events(list(), list()) :: map()
  def get_timestamps_by_events(events, json_rpc_named_arguments) do
    events
    |> get_blocks_by_events(json_rpc_named_arguments, 100_000_000)
    |> Enum.reduce(%{}, fn block, acc ->
      block_number = quantity_to_integer(Map.get(block, "number"))
      timestamp = quantity_to_integer(Map.get(block, "timestamp"))
      miner = Map.get(block, "miner")
      #from = Map.get(block, "from")
      Map.put(acc, "#{block_number}_miner", miner) |> Map.put(block_number, timestamp)
    end)
  end

  defp get_blocks_by_events(events, json_rpc_named_arguments, retries) do
    request =
      events
      |> Enum.reduce(%{}, fn event, acc ->
        Map.put(acc, event["blockNumber"], 0)
      end)
      |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
      |> Stream.with_index()
      |> Enum.into(%{}, fn {params, id} -> {id, params} end)
      |> Blocks.requests(&ByNumber.request(&1, false, false))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case repeated_request(request, error_message, json_rpc_named_arguments, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end

  @spec init_l1(
          Explorer.Chain.PlatonAppchain.L1Event | Explorer.Chain.PlatonAppchain.L1Execute | Explorer.Chain.PlatonAppchain.Checkpoint,
          list(),
          pid(),
          binary(),
          binary(),
          binary(),
          binary()
        ) :: {:ok, map()} | :ignore
  def init_l1(table, env, pid, contract_address, contract_name, table_name, entity_name)
      when table in [Explorer.Chain.PlatonAppchain.L1Event, Explorer.Chain.PlatonAppchain.L1Execute, Explorer.Chain.PlatonAppchain.Checkpoint] do
    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         platon_appchain_l1_rpc = l1_rpc_url(),
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(platon_appchain_l1_rpc)},
         {:contract_is_valid, true} <- {:contract_is_valid, Helper.is_address_correct?(contract_address)},
         start_block_l1 = parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_transaction_hash} <- get_last_l1_item(table),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments = json_rpc_named_arguments(platon_appchain_l1_rpc),
         {:ok, last_l1_tx} <-
           get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments, 100_000_000),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)},
         {:ok, block_check_interval, last_safe_block} <-
           get_block_check_interval(json_rpc_named_arguments) do
      start_block = max(start_block_l1, last_l1_block_number)

      Process.send(pid, :continue, [])

      {:ok,
        %{
          contract_address: contract_address,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: last_safe_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        }}
    else
      {:start_block_l1_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        :ignore

      {:contract_is_valid, false} ->
        Logger.error("#{contract_name} contract address is invalid or not defined.")
        :ignore

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and #{table_name} table.")

        :ignore

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, last safe block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        :ignore

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Please, check #{table_name} table."
        )

        :ignore

      _ ->
        Logger.error("#{entity_name} L1 Start Block is invalid or zero.")
        :ignore
    end
  end

  @spec init_l2(
          Explorer.Chain.PlatonAppchain.L2Event | Explorer.Chain.PlatonAppchain.L2Execute | Explorer.Chain.PlatonAppchain.L2ValidatorEvent | Explorer.Chain.PlatonAppchain.Commitment,
          list(),
          pid(),
          binary(),
          binary(),
          binary(),
          binary(),
          list()
        ) :: {:ok, map()} | :ignore
  def init_l2(table, env, pid, contract_address, contract_name, table_name, entity_name, json_rpc_named_arguments)
      when table in [Explorer.Chain.PlatonAppchain.L2Event, Explorer.Chain.PlatonAppchain.L2Execute, Explorer.Chain.PlatonAppchain.L2ValidatorEvent, Explorer.Chain.PlatonAppchain.Commitment] do
    with {:start_block_l2_undefined, false} <- {:start_block_l2_undefined, is_nil(env[:start_block_l2])},
         {:contract_address_valid, true} <- {:contract_address_valid, Helper.is_address_correct?(contract_address)},
         start_block_l2 = parse_integer(env[:start_block_l2]),
         false <- is_nil(start_block_l2),
         true <- start_block_l2 > 0,
         {last_l2_block_number, last_l2_transaction_hash} <- get_last_l2_item(table),
         {safe_block, safe_block_is_latest} = get_safe_block(json_rpc_named_arguments),
         {:start_block_l2_valid, true} <-
           {:start_block_l2_valid,
             (start_block_l2 <= last_l2_block_number || last_l2_block_number == 0) && start_block_l2 <= safe_block},
         {:ok, last_l2_tx} <- get_transaction_by_hash(last_l2_transaction_hash, json_rpc_named_arguments, 100_000_000),
         {:l2_tx_not_found, false} <- {:l2_tx_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_tx)} do
      Process.send(pid, :continue, [])

      {:ok,
        %{
          start_block: max(start_block_l2, last_l2_block_number),
          start_block_l2: start_block_l2,
          safe_block: safe_block,
          safe_block_is_latest: safe_block_is_latest,
          contract_address: contract_address,
          json_rpc_named_arguments: json_rpc_named_arguments
        }}
    else
      {:start_block_l2_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        :ignore

      {:contract_address_valid, false} ->
        Logger.error("#{contract_name} contract address is invalid or not defined.")
        :ignore

      {:start_block_l2_valid, false} ->
        Logger.error("Invalid L2 Start Block value. Please, check the value and #{table_name} table.")

        :ignore

      {:error, error_data} ->
        Logger.error("Cannot get last L2 transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")

        :ignore

      {:l2_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Please, check #{table_name} table."
        )

        :ignore

      _ ->
        Logger.error("#{entity_name} L2 Start Block is invalid or zero.")
        :ignore
    end
  end

  @spec handle_continue_l1(map(), binary(), L1Event | L1Execute | Checkpoint, atom()) :: {:noreply, map()}
  def handle_continue_l1(
        %{
          contract_address: contract_address,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state,
        event_signature,
        calling_module,
        _fetcher_name
      )
      when calling_module in [L1Event, L1Execute, Checkpoint] do

    time_before = Timex.now()

    eth_get_logs_range_size =
      Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:platon_appchain_eth_get_logs_range_size]

    chunks_number = ceil((end_block - start_block + 1) / eth_get_logs_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    last_written_block =
      chunk_range
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = start_block + eth_get_logs_range_size * current_chunk
        chunk_end = min(chunk_start + eth_get_logs_range_size - 1, end_block)

        if chunk_end >= chunk_start do
          log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, "L1")

          {:ok, result} =
            get_logs(
              chunk_start,
              chunk_end,
              contract_address,
              event_signature,
              json_rpc_named_arguments,
              100_000_000
            )

          {events, event_name} =
            result
            |> calling_module.prepare_events(json_rpc_named_arguments)
            |> import_events(calling_module)

          log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(events)} #{event_name} event(s)",
            "L1"
          )
        end

        {:cont, chunk_end}

      end)

    new_start_block = last_written_block + 1
    {:ok, new_end_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    delay =
      if new_end_block == last_written_block do
        # there is no new block, so wait for some time to let the chain issue the new block
        max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  end

  defp log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, items_count, layer) do
    is_start = is_nil(items_count)

    {type, found} =
      if is_start do
        {"Start", ""}
      else
        {"Finish", " Found #{items_count}."}
      end

    target_range =
      if chunk_start != start_block or chunk_end != end_block do
        progress =
          if is_start do
            ""
          else
            percentage =
              (chunk_end - start_block + 1)
              |> Decimal.div(end_block - start_block + 1)
              |> Decimal.mult(100)
              |> Decimal.round(2)
              |> Decimal.to_string()

            " Progress: #{percentage}%"
          end

        " Target range: #{start_block}..#{end_block}.#{progress}"
      else
        ""
      end

    if chunk_start == chunk_end do
      Logger.info("#{type} handling #{layer} block ##{chunk_start}.#{found}#{target_range}")
    else
      Logger.info("#{type} handling #{layer} block range #{chunk_start}..#{chunk_end}.#{found}#{target_range}")
    end
  end

  defp import_events(events, calling_module) do
    {import_data, event_name} =
      cond do
        calling_module == L1Event ->
          {%{l1_events: %{params: events}, timeout: :infinity}, "StateSynced"}
        calling_module == L1Execute ->
          {%{l1_executes: %{params: events}, timeout: :infinity}, "ExitProcessed"}
        calling_module == Checkpoint ->
          {%{checkpoints: %{params: events}, timeout: :infinity}, "CheckpointSubmitted"}
      end

    {:ok, _} = Chain.import(import_data)

    {events, event_name}
  end


  @spec fill_block_range(integer(), integer(), L2Execute | L2Event | Commitment | L2ValidatorEvent, binary(), list(), boolean()) :: integer()
  def fill_block_range(
        l2_block_start,
        l2_block_end,
        calling_module,
        contract_address,
        json_rpc_named_arguments,
        scan_db
      )
      when calling_module in [L2Execute, L2Event, Commitment, L2ValidatorEvent] do
    eth_get_logs_range_size =
      Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:platon_appchain_eth_get_logs_range_size]

    chunks_number =
      if scan_db do
        1
      else
        ceil((l2_block_end - l2_block_start + 1) / eth_get_logs_range_size)
      end

    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    Enum.reduce(chunk_range, 0, fn current_chunk, count_acc ->
      chunk_start = l2_block_start + eth_get_logs_range_size * current_chunk

      chunk_end =
        if scan_db do
          l2_block_end
        else
          min(chunk_start + eth_get_logs_range_size - 1, l2_block_end)
        end

      log_blocks_chunk_handling(chunk_start, chunk_end, l2_block_start, l2_block_end, nil, "L2")

      count =
        calling_module.find_and_save_entities(
          scan_db,
          contract_address,
          chunk_start,
          chunk_end,
          json_rpc_named_arguments
        )
      event_name = cond do
        calling_module == L2Execute -> "StateSyncResult"
        calling_module == Commitment -> "NewCommitment"
        calling_module == L2Event -> "L2StateSynced"
        calling_module == L2ValidatorEvent -> "L2StakeEvent"
      end

      log_blocks_chunk_handling(
        chunk_start,
        chunk_end,
        l2_block_start,
        l2_block_end,
        "#{count} #{event_name} event(s)",
        "L2"
      )

      count_acc + count
    end)
  end

  @spec fill_block_range_no_event_id(integer(), integer(), {module(), module()}, binary(), list()) :: integer()
  def fill_block_range_no_event_id(start_block, end_block, {module, table}, contract_address, json_rpc_named_arguments) do
    fill_block_range(start_block, end_block, module, contract_address, json_rpc_named_arguments, true)

    {last_l2_block_number, _} = get_last_l2_item(table)

    fill_block_range(
      max(start_block, last_l2_block_number),
      end_block,
      module,
      contract_address,
      json_rpc_named_arguments,
      false
    )
  end

  @spec fill_block_range(integer(), integer(), {module(), module()}, binary(), list()) :: integer()
  def fill_block_range(start_block, end_block, {module, table}, contract_address, json_rpc_named_arguments) do
    fill_block_range(start_block, end_block, module, contract_address, json_rpc_named_arguments, true)

    fill_event_id_gaps(
      start_block,
      table,
      module,
      contract_address,
      json_rpc_named_arguments,
      false
    )

    {last_l2_block_number, _} = get_last_l2_item(table)

    fill_block_range(
      max(start_block, last_l2_block_number),
      end_block,
      module,
      contract_address,
      json_rpc_named_arguments,
      false
    )
  end

  @spec fill_event_id_gaps(integer(), module(), module(), binary(), list(), boolean()) :: no_return()
  def fill_event_id_gaps(
        start_block_l2,
        table,
        calling_module,
        contract_address,
        json_rpc_named_arguments,
        scan_db \\ true
      ) do
    id_min = Repo.aggregate(table, :min, :event_id)
    id_max = Repo.aggregate(table, :max, :event_id)

    with true <- !is_nil(id_min) and !is_nil(id_max),
         starts = event_id_gap_starts(id_max, table),
         ends = event_id_gap_ends(id_min, table),
         min_block_l2 = l2_block_number_by_event_id(id_min, table),
         {new_starts, new_ends} =
           if(start_block_l2 < min_block_l2,
             do: {[start_block_l2 | starts], [min_block_l2 | ends]},
             else: {starts, ends}
           ),
         true <- Enum.count(new_starts) == Enum.count(new_ends) do
      ranges = Enum.zip(new_starts, new_ends)

      invalid_range_exists = Enum.any?(ranges, fn {l2_block_start, l2_block_end} -> l2_block_start > l2_block_end end)

      ranges_final =
        with {:ranges_are_invalid, true} <- {:ranges_are_invalid, invalid_range_exists},
             {max_block_l2, _} = get_last_l2_item(table),
             {:start_block_l2_is_min, true} <- {:start_block_l2_is_min, start_block_l2 <= max_block_l2} do
          [{start_block_l2, max_block_l2}]
        else
          {:ranges_are_invalid, false} -> ranges
          {:start_block_l2_is_min, false} -> []
        end

      ranges_final
      |> Enum.each(fn {l2_block_start, l2_block_end} ->
        count =
          fill_block_range(
            l2_block_start,
            l2_block_end,
            calling_module,
            contract_address,
            json_rpc_named_arguments,
            scan_db
          )

        if count > 0 do
          log_fill_event_id_gaps(scan_db, l2_block_start, l2_block_end, table, count)
        end
      end)

      if scan_db do
        fill_event_id_gaps(start_block_l2, table, calling_module, contract_address, json_rpc_named_arguments, false)
      end
    end
  end

  defp event_id_gap_starts(id_max, table)
       when table in [Explorer.Chain.PlatonAppchain.L2Execute, Explorer.Chain.PlatonAppchain.L2Event] do
    query =
      if table == Explorer.Chain.PlatonAppchain.L2Execute do
        from(item in table,
          select: item.block_number,
          order_by: item.event_id,
          where:
            fragment(
              "NOT EXISTS (SELECT event_id FROM l2_executes WHERE event_id = (? + 1)) AND event_id != ?",
              item.event_id,
              ^id_max
            )
        )
      else
        from(item in table,
          select: item.block_number,
          order_by: item.event_id,
          where:
            fragment(
              "NOT EXISTS (SELECT event_id FROM l2_events WHERE event_id = (? + 1)) AND event_id != ?",
              item.event_id,
              ^id_max
            )
        )
      end

    Repo.all(query)
  end

  defp event_id_gap_ends(id_min, table)
       when table in [Explorer.Chain.PlatonAppchain.L2Execute, Explorer.Chain.PlatonAppchain.L2Event] do
    query =
      if table == Explorer.Chain.PlatonAppchain.L2Execute do
        from(item in table,
          select: item.block_number,
          order_by: item.event_id,
          where:
            fragment(
              "NOT EXISTS (SELECT event_id FROM l2_executes WHERE event_id = (? - 1)) AND event_id != ?",
              item.event_id,
              ^id_min
            )
        )
      else
        from(item in table,
          select: item.block_number,
          order_by: item.event_id,
          where:
            fragment(
              "NOT EXISTS (SELECT event_id FROM l2_events WHERE event_id = (? - 1)) AND event_id != ?",
              item.event_id,
              ^id_min
            )
        )
      end

    Repo.all(query)
  end

  defp l2_block_number_by_event_id(id, table) do
    Repo.one(from(item in table, select: item.block_number, where: item.event_id == ^id))
  end

  defp log_fill_event_id_gaps(scan_db, l2_block_start, l2_block_end, table, count) do
    find_place = if scan_db, do: "in DB", else: "through RPC"
    table_name = table.__schema__(:source)

    Logger.info(
      "Filled gaps between L2 blocks #{l2_block_start} and #{l2_block_end}. #{count} event(s) were found #{find_place} and written to #{table_name} table."
    )
  end
end
