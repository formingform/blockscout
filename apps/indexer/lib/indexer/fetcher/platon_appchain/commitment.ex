defmodule Indexer.Fetcher.PlatonAppchain.Commitment do
  @moduledoc """
  Fills Commitment DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Indexer.Fetcher.PlatonAppchain, only: [fill_block_range: 5, get_block_number_by_tag: 3]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.PlatonAppchain.Commitment
  alias Indexer.Fetcher.PlatonAppchain

  @fetcher_name :platon_appchain_Commitment

  # 32-byte signature of the event NewCommitment(uint256 indexed startId, uint256 indexed endId, bytes32 root)
  @new_commitment_event "0x11efd893530b26afc66d488ff54cb15df117cb6e0e4a08c6dcb166d766c3bf3b"

  # 32-byte representation of deposit signature, keccak256("NewCommitment")
  @new_commitment_signature "a22e3e55b690d7d609fdd9acbb8a48098de7fa7874cf95d975b1264b0c24d161"

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
      Commitment,
      env,
      self(),
      env[:state_receiver],
      "StateReceiver",
      "commitments",
      "Commitments",
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

    # todo 这里需要实现类似fill_event_id_gaps的函数
#    PlatonAppchain.fill_event_id_gaps(
#      start_block_l2,
#      Commitment,
#      __MODULE__,
#      contract_address,
#      json_rpc_named_arguments
#    )

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
    PlatonAppchain.fill_block_range_no_event_id(
      start_block,
      safe_block,
      {__MODULE__, Commitment},
      contract_address,
      json_rpc_named_arguments
    )

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      PlatonAppchain.fill_block_range_no_event_id(
        safe_block + 1,
        latest_block,
        {__MODULE__, Commitment},
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
    Repo.delete_all(from(de in Commitment, where: de.block_number >= ^starting_block))
  end

  @spec event_to_commitment(map(), binary(), binary()) :: map()
  def event_to_commitment(data, l2_transaction_hash, l2_block_number) do
    [data_bytes] = decode_data(data, [:bytes])

    sig = binary_part(data_bytes, 0, 32)

    {start_id, end_id, state_root, miner, l2_timestamp} =
      if Base.encode16(sig, case: :lower) === @new_commitment_signature do
        {:ok, miner, timestamps} = PlatonAppchain.get_block_miner_by_number(l2_block_number, json_rpc_named_arguments)
        [_sig, start_id, end_id, state_root] =
          TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, {:uint, 256}, {:uint, 256}, {:bytes, 32}])

        {start_id, end_id, state_root, miner, timestamps}
      else
        {nil, nil, nil, nil, nil}
      end

    %{
      start_end_Id: Integer.to_string(start_id) + "-" + Integer.to_string(end_id),
      state_batch_hash: event["transactionHash"],
      state_root: state_root,
      start_id: start_id,
      end_id: end_id,
      tx_number: start_id - end_id + 1,
      from: miner,
      to: event["address"],
      block_timestamp: l2_timestamp,
      block_number: l2_block_number,
    }
  end

  @spec find_and_save_entities(boolean(), binary(), non_neg_integer(), non_neg_integer(), list()) :: non_neg_integer()
  def find_and_save_entities(
        scan_db,
        state_receiver,
        block_start,
        block_end,
        json_rpc_named_arguments
      ) do
    commitments =
      if scan_db do
        query =
          from(log in Log,
            select: {log.data, log.transaction_hash, log.block_number},
            where:
              log.first_topic == @new_commitment_event and log.address_hash == ^state_receiver and
              log.block_number >= ^block_start and log.block_number <= ^block_end
          )

        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {data, l2_transaction_hash, l2_block_number} ->
          event_to_commitment(data, l2_transaction_hash, l2_block_number)
        end)
      else
        {:ok, result} =
          PlatonAppchain.get_logs(
            block_start,
            block_end,
            state_receiver,
            @new_commitment_event,
            json_rpc_named_arguments,
            100_000_000
          )

        Enum.map(result, fn event ->
          event_to_commitment(
            event["data"],
            event["transactionHash"],
            event["blockNumber"]
          )
        end)
      end

    {:ok, _} =
      Chain.import(%{
        commitments: %{params: commitments},
        timeout: :infinity
      })

    Enum.count(commitments)
  end

  @spec new_commitment_event_signature() :: binary()
  def new_commitment_event_signature do
    @new_commitment_event
  end
end
