defmodule Indexer.Fetcher.PlatonAppchain.L1Event do
  @moduledoc """
  Fills platon appchain l1_events DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2]

  alias ABI.TypeDecoder
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.PlatonAppchain.L1Event
  alias Indexer.Fetcher.PlatonAppchain

  @fetcher_name :platon_appchain_l1_event

  # 32-byte signature of the event StateSynced(uint256 indexed id, address indexed sender, address indexed receiver, bytes data)
  @state_synced_event "0xd1d7f6609674cc5871fdb4b0bcd4f0a214118411de9e38983866514f22659165"

  # 32-byte representation of deposit signature, keccak256("DEPOSIT")
  @deposit_signature "87a7811f4bfedea3d341ad165680ae306b01aaeacc205d227629cf157dd9f821"
  @stake_signature "1bcc0f4c3fad314e585165815f94ecca9b96690a26d6417d7876448a9a867a69"
  @add_stake_signature "7f629647b0cf8231fa5380e25f7c9bf0685fecbdc41360b93da5b447cef9ee73"
  @delegate_signature "c7ddcf4441a1bb01353b38db832023115117943d28ad05b882de4ad99e94b8fc"

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

    env = Application.get_all_env(:indexer)[__MODULE__]

    #Subscriber.to(:platonappchain_reorg_block, :realtime)

    PlatonAppchain.init_l1(
      L1Event,
      env,
      self(),
      env[:state_sender],
      "State Sender",
      "l1_events",
      "L1 Events"
    )
  end

  @impl GenServer
  def handle_info(:continue, state) do
    #handle_continue_l1最终会给本进程发送一个:continue消息，实现循环监听L1
    PlatonAppchain.handle_continue_l1(state, @state_synced_event, __MODULE__, @fetcher_name)
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @spec prepare_events(list(), list()) :: list()
  def prepare_events(events, json_rpc_named_arguments) do
    Enum.map(events, fn event ->
      [data_bytes] = decode_data(event["data"], [:bytes])

      sig = binary_part(data_bytes, 0, 32)

      l1_block_number = quantity_to_integer(event["blockNumber"])

      {tx_type, from, to, amount, validator, l1_timestamp} =
        case Base.encode16(sig, case: :lower) do
          @deposit_signature ->
            timestamps = PlatonAppchain.get_timestamps_by_events(events, json_rpc_named_arguments)
            [_sig, sender, receiver, amount] =
              TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, :address, {:uint, 256}])

            {PlatonAppchain.l1_events_tx_type()[:deposit], sender, receiver, amount, nil, Map.get(timestamps, l1_block_number)}
          @stake_signature ->
            timestamps = PlatonAppchain.get_timestamps_by_events(events, json_rpc_named_arguments)
            [_sig, validator, owner, amount, _commissionRate, _blsKey, _pubKey] =
              TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, :address, {:uint, 256}, {:uint, 256}, :bytes, :bytes])
            # todo 需要确认from地址
            {PlatonAppchain.l1_events_tx_type()[:stake], validator, validator, amount, validator, Map.get(timestamps, l1_block_number)}
          @add_stake_signature ->
            timestamps = PlatonAppchain.get_timestamps_by_events(events, json_rpc_named_arguments)
            [_sig, validator, amount] =
              TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, {:uint, 256}])
            # todo 需要确认from地址
            {PlatonAppchain.l1_events_tx_type()[:addStake], validator, validator, amount, validator, Map.get(timestamps, l1_block_number)}
          @delegate_signature ->
            timestamps = PlatonAppchain.get_timestamps_by_events(events, json_rpc_named_arguments)
            [_sig, validator, delegator, amount] =
              TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, :address, {:uint, 256}])

            {PlatonAppchain.l1_events_tx_type()[:delegate], delegator, validator, amount, validator, Map.get(timestamps, l1_block_number)}
          _ ->
            {nil, nil, nil, nil, nil, nil}
        end

      %{
        event_id: quantity_to_integer(Enum.at(event["topics"], 1)),
        tx_type: tx_type,
        amount: amount,
        from: from,
        to: to,
        hash: event["transactionHash"],
        block_timestamp: l1_timestamp,
        block_number: l1_block_number,
        validator: validator
      }
    end)
  end
end
