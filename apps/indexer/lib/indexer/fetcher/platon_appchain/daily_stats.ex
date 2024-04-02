defmodule Indexer.Fetcher.PlatonAppchain.DailyStats do
  @moduledoc """
  每日数据统计：
    目前为验证人相关信息统计
  """


  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Indexer.Helper
  alias Indexer.Fetcher.PlatonAppchain.Contracts.{L2StakeHandler,L2RewardManager}
  alias Indexer.Fetcher.PlatonAppchain
  alias Explorer.Chain.PlatonAppchain.DailyStatic

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
    Process.send(self(), :continue, [])
    {:ok,%{}}
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{} = state
      ) do
    # 获取当前日期时间
    current_datetime = Timex.now()
    # 获取昨天的日期时间
    yesterday_datetime = Timex.shift(Timex.now(), days: -1)
    # 昨天日期8位字符串
    static_date = Timex.format!(yesterday_datetime, "{YYYY}{0M}{0D}")

    records = DailyStatic.find_by_static_date(static_date)
    if records == 0 do
      DailyStatic.static_validator()
    end

    # 一天结束时间与第二天开始时间都是0点，这里获取第二天开始时间+10秒做为每天统计时间
    end_time = Timex.end_of_day(current_datetime)
    time_diff = Timex.diff(end_time, current_datetime)

    # 如果统计过，则到第二天开始时间+10秒再进行，否则过1分钟进行
    Process.send_after(self(), :continue, if records == 1 do time_diff+10000  else 60*1000 end)

    {:noreply,state}
  end
end