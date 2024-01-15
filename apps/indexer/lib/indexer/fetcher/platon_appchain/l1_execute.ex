defmodule Indexer.Fetcher.PlatonAppchain.L1Execute do
  @moduledoc """
  Fills L1 Executes DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Indexer.Fetcher.PlatonAppchain, only: [fill_block_range: 5, get_block_number_by_tag: 3]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.PlatonAppchain.L2Event
  alias Explorer.Chain.PlatonAppchain.Checkpoint
  alias Explorer.Chain.PlatonAppchain.L1Execute
  alias Indexer.Fetcher.PlatonAppchain

  @fetcher_name :platon_appchain_l1_execute

  # 32-byte signature of the event ExitProcessed(uint256 indexed id, bool indexed success, bytes returnData)
  @exit_helper_event "0x8bbfa0c9bee3785c03700d2a909592286efb83fc7e7002be5764424b9842f7ec"

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

    PlatonAppchain.init_l1(
      L1Execute,
      env,
      self(),
      env[:exit_helper],
      "Exit Helper",
      "l1_executes",
      "L1Execute"
    )
  end

  @impl GenServer
  def handle_info(:continue, state) do
    PlatonAppchain.handle_continue(state, @checkpoint_submitted_event, __MODULE__, @fetcher_name)
  end


  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @spec get_state_batch_hash_by_event_id(non_neg_integer()) :: {non_neg_integer() | nil}
  def get_l2_block_number_by_event_id(event_id) do
    query =
      from(l2_event in L2Event,
        select: {l2_event.block_number},
        where: l2_event.event_Id <= ^event_id,
        limit: 1
      )
    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  @spec get_state_batch_hash_by_event_id(non_neg_integer()) :: {binary() | nil}
  def get_state_batch_hash_by_block_number(block_number) do
    query =
      from(checkpoint in Checkpoint,
        select: {checkpoint.l1_transaction_hash},
        where: checkpoint.start_block_number <= ^block_number and checkpoint.end_block_number >= ^event_id,
        limit: 1
      )
    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  @spec prepare_events(list(), list()) :: list()
  def prepare_events(events, json_rpc_named_arguments) do
    Enum.map(events, fn event ->
      event_id = quantity_to_integer(Enum.at(event["topics"], 1)) #l2上收集状态变更事件组成checkpoint的截至块高（L2上生成checkpoint的块高的前3个块高）。事实上，checkpoint收集的装备变更事件，是跨epoch的。
      status = Enum.at(event["topics"], 2)

      # 查询event_id所属的交易事件在l2的区块号
      { l2_blockNumber } = get_l2_block_number_by_event_id(event_id)
      # 根据区块号去查寻对应的checkpoint交易的交易hash
      { checkpoint_tx_hash } = get_state_batch_hash_by_block_number(l2_blockNumber)
      %{
        event_Id: event_id,
        hash: event["transactionHash"],
        state_batch_hash: checkpoint_tx_hash,
        status: Kernel.boolean(status)
      }
    end)
  end
end
