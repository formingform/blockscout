defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L2BlockProducedStatistics do

  require Ecto.Query
  require Logger

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Hash
  alias Explorer.Chain.PlatonAppchain.L2BlockProducedStatistic
  alias Explorer.Prometheus.Instrumenter
  alias Indexer.Fetcher.PlatonAppchain
  alias Explorer.Chain.Import.Runner

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [L2BlockProducedStatistic.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L2BlockProducedStatistic

  @impl Import.Runner
  def option_key, do: :l2_block_produced_statistics

  @spec imported_table_row() :: %{:value_description => binary(), :value_type => binary()}

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  @spec run(Multi.t(), list(), map()) :: Multi.t()
  def run(multi, changes_list, %{timestamps: timestamps} = options) when length(changes_list) > 0 do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    # 获取事务操作的超时时间，如果没有指定，则使用默认的超时时间
    transactions_timeout = options[Runner.PlatonAppchain.L2BlockProducedStatistics.option_key()][:timeout] || Runner.PlatonAppchain.L2BlockProducedStatistics.timeout()

    Multi.run(multi, :insert_l2_block_produced_statistics, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l2_block_produced_statistics,
        :l2_block_produced_statistics
      )
    end)
  end


  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L2BlockProducedStatistic.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # 按round排序
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.round})

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: [:validator_hash, :round],
      # on_conflict: :replace_all,
      on_conflict: on_conflict,
      for: L2BlockProducedStatistic,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      l in L2BlockProducedStatistic,
      update: [
        set: [
          # Don't update `validator_hash` `round` as it is a primary key and used for the conflict target
          shoud_blocks: fragment("EXCLUDED.should_blocks"),
          actual_blocks: fragment("EXCLUDED.actual_blocks"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.should_blocks, EXCLUDED.actual_blocks) IS DISTINCT FROM (?, ?)", # 有冲突时只更新这些字段
          l.should_blocks,
          l.actual_blocks
        )
    )
  end
end
