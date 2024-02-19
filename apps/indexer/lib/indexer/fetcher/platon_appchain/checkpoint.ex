defmodule Indexer.Fetcher.PlatonAppchain.Checkpoint do
  @moduledoc """
  Fills Checkpoints DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias Explorer.{Repo}
  alias Explorer.Chain.PlatonAppchain.Checkpoint
  alias Explorer.Chain.PlatonAppchain.L2Event
  alias Indexer.Fetcher.PlatonAppchain


  @fetcher_name :platon_appchain_checkpoint

  # 32-byte signature of the event CheckpointSubmitted(uint64 indexed epoch, uint64 indexed blockNumber, bytes32 eventRoot)
  @checkpoint_submitted_event "0xb7e745a1c3956b81d881d026fdca913d29ad8b421b53a5700f3d2adcbde28c68"

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
      Checkpoint,
      env,
      self(),
      env[:checkpoint_manager],
      "Checkpoint Manager",
      "checkpoints",
      "Checkpoints"
    )
  end

  @impl GenServer
  def handle_info(:continue, state) do
    PlatonAppchain.handle_continue_l1(state, @checkpoint_submitted_event, __MODULE__, @fetcher_name)
  end


  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @spec prepare_events(list(), list()) :: list()
  def prepare_events(events, json_rpc_named_arguments) do
    Enum.map(events, fn event ->
      end_block_number = quantity_to_integer(Enum.at(event["topics"], 2)) #l2上收集状态变更事件组成checkpoint的截至块高（L2上生成checkpoint的块高的前3个块高）。事实上，checkpoint收集的装备变更事件，是跨epoch的。
      round_size = quantity_to_integer(PlatonAppchain.l2_round_size())
      start_block_number = cond do
        end_block_number > round_size ->
          end_block_number - round_size + 1
        true ->
          1
      end

      l1_block_number = quantity_to_integer(event["blockNumber"])
      timestamps = PlatonAppchain.get_timestamps_by_events(events, json_rpc_named_arguments)
      #l2上的epoch，一个epoch长度的块高生成一个checkpoint
      %{epoch: quantity_to_integer(Enum.at(event["topics"], 1)),
        start_block_number: start_block_number,
        end_block_number: end_block_number,
        state_root: event["data"],
        event_counts: get_event_counts(start_block_number, end_block_number),
        block_number: l1_block_number,
        hash: event["transactionHash"],
        block_timestamp: Map.get(timestamps, l1_block_number)
      }
    end)
  end

  # 统计在区块间, l2发生的包括在checkpoint的事件数量（需要同步到L1的事件）
  defp get_event_counts(start_block_number, end_block_number) do
    from(l2_events in L2Event,
      select: fragment("count(*)"),
      where:
        l2_events.block_number >= ^start_block_number and l2_events.block_number <= ^end_block_number)
    |> Repo.one(timeout: :infinity)
  end
end
