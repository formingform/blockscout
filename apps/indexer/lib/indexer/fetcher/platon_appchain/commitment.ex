defmodule Indexer.Fetcher.PlatonAppchain.Commitment do
  @moduledoc """
  Fills Commitment DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Indexer.Fetcher.PlatonAppchain, only: [fill_block_range_no_event_id: 5, get_block_number_by_tag: 3]
  import Explorer.Helper, only: [decode_data: 2]

  alias ABI.TypeDecoder
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.PlatonAppchain.Commitment
  alias Explorer.Chain.PlatonAppchain.L2Execute
  alias Indexer.Fetcher.PlatonAppchain

  @fetcher_name :platon_appchain_Commitment

  # 32-byte signature of the event NewCommitment(uint256 indexed startId, uint256 indexed endId, bytes32 root)
  @new_commitment_event "0x11efd893530b26afc66d488ff54cb15df117cb6e0e4a08c6dcb166d766c3bf3b"

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
      env[:l2_state_receiver],
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
    PlatonAppchain.fill_event_id_gaps(
      start_block_l2,
      L2Execute,
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

  @spec event_to_commitment(binary(), binary(), binary(), binary(), non_neg_integer(), list()) :: map()
  def event_to_commitment(second_topic, third_topic, data, l2_transaction_hash, l2_block_number, json_rpc_named_arguments) do
    [data_bytes] = decode_data(data, [:bytes])

    startId = Integer.to_string(second_topic)
    endId = Integer.to_string(third_topic)

    {:ok, miner, blockTimestamp} = PlatonAppchain.get_block_miner_by_number(l2_block_number, json_rpc_named_arguments, 100_000_000)

    %{
      state_root: data_bytes,
      hash: l2_transaction_hash,
      start_Id: startId,
      end_id: endId,
      tx_number: startId - endId + 1,
      from: miner,
      block_number: l2_block_number,
      block_timestamp: blockTimestamp,
    }
  end


  @spec find_and_save_entities(boolean(), binary(), non_neg_integer(), non_neg_integer(), list()) :: non_neg_integer()
  def find_and_save_entities(
        scan_db,
        l2_state_receiver,
        block_start,
        block_end,
        json_rpc_named_arguments
      ) do
    commitments =
      if scan_db do
        query =
          from(log in Log,
            select: {log.data, log.address, log.transaction_hash, log.block_number},
            where:
              log.first_topic == @new_commitment_event and log.address_hash == ^l2_state_receiver and
              log.block_number >= ^block_start and log.block_number <= ^block_end
          )

        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {second_topic, third_topic, data, l2_transaction_hash, l2_block_number} ->
          event_to_commitment(second_topic, third_topic, data, l2_transaction_hash, l2_block_number, json_rpc_named_arguments)
        end)
      else
        {:ok, result} =
          PlatonAppchain.get_logs(
            block_start,
            block_end,
            l2_state_receiver,
            @new_commitment_event,
            json_rpc_named_arguments,
            100_000_000
          )

        Enum.map(result, fn event ->
          event_to_commitment(
            Enum.at(event["topics"], 1),
            Enum.at(event["topics"], 2),
            event["data"],
            event["transactionHash"],
            event["blockNumber"],
            json_rpc_named_arguments
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
