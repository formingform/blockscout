defmodule Indexer.Fetcher.PlatonAppchain.L2Event do
  @moduledoc """
  Fills platon appchain l2_event DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2]
  import Indexer.Fetcher.PlatonAppchain, only: [fill_block_range: 5, get_block_number_by_tag: 3]

  alias ABI.TypeDecoder
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.PlatonAppchain.L2Event
  alias Indexer.Fetcher.PlatonAppchain

  @fetcher_name :platon_appchain_l2_event

  # 32-byte signature of the event L2StateSynced(uint256 indexed id, address indexed sender, address indexed receiver, bytes data)
  @l2_state_synced_event "0xedaf3c471ebd67d60c29efe34b639ede7d6a1d92eaeb3f503e784971e67118a5"

  @withdraw_signature "7a8dc26796a1e50e6e190b70259f58f6a4edd5b22280ceecc82b687b8e982869"

  @stake_withdraw_signature "8ca9a95e41b5eece253c93f5b31eed1253aed6b145d8a6e14d913fdf8e732293"
  # 用户在L2上撤销委托后，将会锁定一段时间，同时有个业务事件，refer: @l2_biz_event_UnDelegated
  # 用户在L2提取委托金时，才会同步有个UNDELEGATE_SIG的L2StateSynced事件给L1。这个事件和前面的那个事件没有关系，甚至前面撤销委托100，这里提款80。
  @delegation_withdraw_signature "58e580ca1cdbe518f27d857873b615e807a3c395584a93d75e80c921c991e50f"

  @slash_signature "117f1d6f44fd34ccb7a58f1261fa59e5c4bf68e2712d65f246a8805167a93344"

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
  def init(args) do
    Logger.metadata(fetcher: @fetcher_name)

    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    env = Application.get_all_env(:indexer)[__MODULE__]

    PlatonAppchain.init_l2(
      L2Event,
      env,
      self(),
      env[:l2_state_sender],
      "L2StateSender",
      "l2_events",
      "L2Events",
      json_rpc_named_arguments
    )
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          start_block_l2: start_block_l2,
          contract_address: contract_address,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    PlatonAppchain.fill_event_id_gaps(
      start_block_l2,
      L2Event,
      __MODULE__,
      contract_address,
      json_rpc_named_arguments
    )

    Process.send(self(), :find_new_events, [])
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        :find_new_events,
        %{
          start_block: start_block,
          safe_block: safe_block,
          safe_block_is_latest: safe_block_is_latest,
          contract_address: contract_address,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    # find and fill all events between start_block and "safe" block
    # the "safe" block can be "latest" (when safe_block_is_latest == true)
    fill_block_range(
      start_block,
      safe_block,
      {__MODULE__, L2Event},
      contract_address,
      json_rpc_named_arguments
    )

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = PlatonAppchain.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      fill_block_range(
        safe_block + 1,
        latest_block,
        {__MODULE__, L2Event},
        contract_address,
        json_rpc_named_arguments
      )
    end

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @spec remove(non_neg_integer()) :: no_return()
  def remove(starting_block) do
    Repo.delete_all(from(w in L2Event, where: w.block_number >= ^starting_block))
  end

  @spec event_to_l2_event( binary(), binary(), binary(), binary(), list()) :: map()
  def event_to_l2_event(second_topic, data, l2_transaction_hash, l2_block_number, json_rpc_named_arguments) do
    Logger.debug(fn -> "convert event to l2_event, log.data: #{inspect(data)}" end, logger: :platon_appchain)


    data_bytes =
    case data do
      %Explorer.Chain.Data{} ->
        %Explorer.Chain.Data{bytes: data_byte} = data
        data_byte
      _ ->
        [data_byte] = decode_data(data, [:bytes])
        data_byte
    end

    Logger.debug(fn -> "decode data result: #{inspect(data_bytes)}" end, logger: :platon_appchain)

    eventID = quantity_to_integer(second_topic)
    Logger.debug(fn -> "parse second_topic to eventId: #{inspect(eventID)}" end, logger: :platon_appchain)

    sig = binary_part(data_bytes, 0, 32)
    Logger.debug(fn -> "method sig: #{inspect(sig)}" end, logger: :platon_appchain)

    {:ok, l2_block_timestamp} = PlatonAppchain.get_block_timestamp_by_number(l2_block_number, json_rpc_named_arguments, 100_000_000)

    {tx_type, from, to, amount} =
      case Base.encode16(sig, case: :lower) do
        @withdraw_signature ->
          # {WITHDRAW_SIG, withdrawer, recipient, amount}
          [_sig, withdrawer, recipient, amount] =
            TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, :address, {:uint, 256}])

        {PlatonAppchain.l2_events_tx_type()[:withdraw], withdrawer, recipient, amount}

        @stake_withdraw_signature ->
          # {UNSTAKE_SIG, validatorAddr, amount}
          [_sig, validatorAddr, amount] =
            TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, {:uint, 256}])

          {PlatonAppchain.l2_events_tx_type()[:stakeWithdraw], validatorAddr, "", amount}
        @delegation_withdraw_signature ->
          # {UNDELEGATE_SIG, validatorAddr, delegatorAddr, amount}
          [_sig, validatorAddr, delegatorAddr, amount] =
            TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, :address, {:uint, 256}])
          {PlatonAppchain.l2_events_tx_type()[:degationWithdraw], delegatorAddr, validatorAddr, amount}
        @slash_signature ->
          # SLASH_SIG, validators, c.stakeModule.GetSlashingPercentage(c.evm.StateDB), c.stakeModule.GetSlashIncentivePercentage(c.evm.StateDB)
          [_sig, validatorAddrList, slashingPercent, slashIncentivePercent] =
            TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, {:array, :address}, {:uint, 256}, {:uint, 256}])
           first = Enum.at(validatorAddrList, 0)
          {PlatonAppchain.l2_events_tx_type()[:slash], first, first, slashingPercent}
        _ ->
        {nil, nil, nil,  nil}
      end
    if is_nil(tx_type) do
      %{}
    else
      %{
        event_id: eventID,
        tx_type: tx_type,
        from: from,
        to: to,
        amount: amount,
        l2_transaction_hash: l2_transaction_hash,
        l2_block_number: quantity_to_integer(l2_block_number),
        block_timestamp: l2_block_timestamp,
      }
    end
  end

  @spec find_and_save_entities(boolean(), binary(), non_neg_integer(), non_neg_integer(), list()) :: non_neg_integer()
  def find_and_save_entities(
        scan_db,
        l2_state_sender, #发出L2StateSynced事件的合约地址
        block_start,
        block_end,
        json_rpc_named_arguments
      ) do
    l2_events =
      if scan_db do
        query =
          from(log in Log,
            select: {log.second_topic, log.data, log.transaction_hash, log.block_number},
            where:
              log.first_topic == @l2_state_synced_event and log.address_hash == ^l2_state_sender and
              log.block_number >= ^block_start and log.block_number <= ^block_end
          )

        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {second_topic, data, l2_transaction_hash, l2_block_number} ->
          event_to_l2_event(second_topic, data, l2_transaction_hash, l2_block_number, json_rpc_named_arguments)
        end)
      else
        {:ok, result} =
          PlatonAppchain.get_logs(
            block_start,
            block_end,
            l2_state_sender,
            @l2_state_synced_event,
            json_rpc_named_arguments,
            100_000_000
          )
        Enum.map(result, fn event ->
          event_to_l2_event(
            Enum.at(event["topics"], 1), #topics[0]是合约方法签名，[1]是第一个带indexed的合约参数，这里是event_id
            event["data"],
            event["transactionHash"],
            event["blockNumber"],  # 这里event["blockNumber"]获取的block_number是16进制的
            json_rpc_named_arguments
          )
        end)
      end
    # 过滤掉返回为空的events
    filtered_events = Enum.reject(l2_events, fn %{} -> true; _ -> false end)
    if Enum.count(filtered_events) > 0 do
      {:ok, _} =
        Chain.import(%{
          l2_events: %{params: filtered_events},
          timeout: :infinity
        })

      Enum.count(filtered_events)
    else
      0
    end
  end

  @spec l2_state_synced_event_signature() :: binary()
  def l2_state_synced_event_signature do
    @l2_state_synced_event
  end
end
