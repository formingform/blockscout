defmodule Explorer.Prometheus.Instrumenter do
  @moduledoc """
  Blocks fetch and import metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @histogram [
    name: :block_import_stage_runner_duration_microseconds,
    labels: [:stage, :runner, :step],
    buckets: [1000, 5000, 10000, 100_000],
    duration_unit: :microseconds,
    help: "Block import stage, runner and step in runner processing time"
  ]

  def block_import_stage_runner(function, stage, runner, step) do
    # 记录执行特定阶段、执行器和步骤的处理时间
    {time, result} = :timer.tc(function)
    # 记录直方图中？
    Histogram.observe([name: :block_import_stage_runner_duration_microseconds, labels: [stage, runner, step]], time)

    result
  end
end
