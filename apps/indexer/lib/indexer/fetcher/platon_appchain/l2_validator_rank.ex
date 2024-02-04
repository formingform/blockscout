defmodule Indexer.Fetcher.PlatonAppchain.L2ValidatorRank do
  @moduledoc """
  更新方法：
    根据质押事件来维护l2_validator表
    根据epoch周期，来更新l2_validator表rank字段
  """


  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Indexer.Helper
  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler
  alias Indexer.Fetcher.PlatonAppchain
  alias Indexer.Fetcher.PlatonAppchain.L2ValidatorService

  @fetcher_name :platon_appchain_l2_validator_rank
  @default_update_interval :timer.seconds(3)
  @period_type [round: 1, epoch: 2]

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

  def init(_) do
    l2_epoch_size = PlatonAppchain.l2_epoch_size()
    l2_rpc_arguments = PlatonAppchain.l2_rpc_arguments()
    Process.send(self(), :continue, [])
    {:ok,
      %{
        l2_rpc_arguments: l2_rpc_arguments,
        l2_epoch_size: l2_epoch_size,
        next_epoch_block: 0
      }}
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          l2_rpc_arguments: l2_rpc_arguments,
          l2_epoch_size: l2_epoch_size,
          next_epoch_block: next_epoch_block
        } = state
      ) do

    {:ok, latest_block} = PlatonAppchain.get_latest_block_number(l2_rpc_arguments)
    epoch = PlatonAppchain.calculateL2Epoch(latest_block, l2_epoch_size)
    # 通过call不同合约的方法，获取validator的各种信息
    if next_epoch_block == 0 || latest_block >= next_epoch_block do
      #应用启动后第一次执行

      # 更新所有质押人
      all_candidates = L2StakeHandler.getAllValidators()

      #把列表中的序号，作为rank赋值给所有质押节点
      all_candidates
      |> Enum.with_index(1)
      |> Enum.map(fn {element, idx} ->  {element["validatorAddr"], idx} end)
#      all_candidates
#      |> Enum.with_index(1)
#      |> Enum.map(fn {element, idx} -> Map.put(element, :rank, idx) end)

      L2ValidatorService.update_rank(all_candidates)
    end

    # 计算下次获取round出块验证人的块高，并算出大概需要delay多久
    nextEpochBlockNumber = epoch * l2_epoch_size + 1
    delay = (nextEpochBlockNumber - latest_block) * 1000
    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | next_epoch_block: nextEpochBlockNumber}}
  end
end
