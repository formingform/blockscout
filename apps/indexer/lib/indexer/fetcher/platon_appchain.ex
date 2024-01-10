defmodule Indexer.Fetcher.PlatonAppchain do
  @moduledoc """
  Contains common functions for PlatonAppchain.* fetchers.
  """

  require Logger

  import Ecto.Query

  import EthereumJSONRPC,
         only: [fetch_block_number_by_tag: 2, json_rpc: 2, integer_to_quantity: 1, quantity_to_integer: 1, request: 1]

  import Explorer.Helper, only: [parse_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias Explorer.Chain.Events.Publisher
  alias Explorer.{Chain, Repo}
  alias Indexer.{BoundQueue, Helper}

  # 周期类型：roung: 共识周期; epoch：结算周期
  @period_type [round: 1, epoch: 2]

  # 缺省的出块间隔时间，毫秒
  @default_block_interval 1000

  # 0：201候选验证人；1：43 出块验证人； 2：备选验证人（质押人）
  @validator_status %{Active: 0, Verifying: 1, Candidate: 2}

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
     Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_rpc_url]
  end

  def l1_rpc_url() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l1_rpc_url]
  end

  def l2_validator_contract_address() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_validator_contract_address]
  end

  def l1_validator_contract_address() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_validator_contract_address]
  end

  def default_block_interval() do
    @default_block_interval
  end

  def period_type() do
    @period_type
  end

  def validator_status() do
    @validator_status
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

  @spec get_block_number_by_tag(list()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_latest_block_number(json_rpc_named_arguments) do
    get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
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
      {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
      Map.put(acc, block_number, timestamp)
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

    case PlatonAppchain.repeated_request(request, error_message, json_rpc_named_arguments, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end

  @spec init_l1(
          Explorer.Chain.PlatonAppchain.L1Event | Explorer.Chain.PlatonAppchain.L2Event,
          list(),
          pid(),
          binary(),
          binary(),
          binary(),
          binary()
        ) :: {:ok, map()} | :ignore
  def init_l1(table, env, pid, contract_address, contract_name, table_name, entity_name)
      when table in [Explorer.Chain.PlatonAppchain.L1Event, Explorer.Chain.PlatonAppchain.L2Event] do
    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         l1_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonEdge][:polygon_edge_l1_rpc],
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(polygon_edge_l1_rpc)},
         {:contract_is_valid, true} <- {:contract_is_valid, Helper.is_address_correct?(contract_address)},
         start_block_l1 = parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_transaction_hash} <- get_last_l1_item(table),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments = json_rpc_named_arguments(polygon_edge_l1_rpc),
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
          Explorer.Chain.PolygonEdge.DepositExecute | Explorer.Chain.PolygonEdge.Withdrawal,
          list(),
          pid(),
          binary(),
          binary(),
          binary(),
          binary(),
          list()
        ) :: {:ok, map()} | :ignore
  def init_l2(table, env, pid, contract_address, contract_name, table_name, entity_name, json_rpc_named_arguments)
      when table in [Explorer.Chain.PolygonEdge.DepositExecute, Explorer.Chain.PolygonEdge.Withdrawal] do
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

  @spec handle_continue(map(), binary(), Deposit | WithdrawalExit, atom()) :: {:noreply, map()}
  def handle_continue(
        %{
          contract_address: contract_address,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state,
        event_signature,
        calling_module,
        fetcher_name
      )
      when calling_module in [Deposit, WithdrawalExit] do
    time_before = Timex.now()

    eth_get_logs_range_size =
      Application.get_all_env(:indexer)[Indexer.Fetcher.PolygonEdge][:polygon_edge_eth_get_logs_range_size]

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
      if calling_module == Deposit do
        {%{polygon_edge_deposits: %{params: events}, timeout: :infinity}, "StateSynced"}
      else
        {%{polygon_edge_withdrawal_exits: %{params: events}, timeout: :infinity}, "ExitProcessed"}
      end

    {:ok, _} = Chain.import(import_data)

    {events, event_name}
  end
end
