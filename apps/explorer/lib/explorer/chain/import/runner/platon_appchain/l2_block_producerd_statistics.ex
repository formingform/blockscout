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

    # 需要更新出块率的验证人列表
    validator_hash_list =
      changes_list
      |> Enum.reduce([], fn block_produced_statistic, acc ->  [block_produced_statistic.validator_hash | acc] end)

    # 获取事务操作的超时时间，如果没有指定，则使用默认的超时时间
    transactions_timeout = options[Runner.PlatonAppchain.L2BlockProducedStatistics.option_key()][:timeout] || Runner.PlatonAppchain.L2BlockProducedStatistics.timeout()

    multi
    |> Multi.run(:insert_l2_block_produced_statistics, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l2_block_produced_statistics,
        :l2_block_produced_statistics
      )
    end)
    # 继续执行更新出块率的SQL
    |> Multi.run(:update_l2_validators_block_rate, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> update_l2_validators_block_rate(repo, validator_hash_list, %{
          timeout:
            options[Explorer.Chain.Import.Runner.PlatonAppchain.L2BlockProducedStatistics.option_key()][:timeout] ||
              Explorer.Chain.Import.Runner.PlatonAppchain.L2BlockProducedStatistics.timeout(),
          timestamps: timestamps
        }) end,
        :block_referencing,
        :l2_block_produced_statistics,
        :l2_block_produced_statistics
      )
    end)


    # todo: 继续执行更新出块率的SQL
    #update l2_validators dest
    #set block_rate = src.block_rate
    #from (
    #	SELECT validator_hash, round(round(sum(actual_blocks) / sum(should_blocks), 4) * 10000, 0) as block_rate
    #	from (
    #		select validator_hash, should_blocks, actual_blocks, round, ROW_NUMBER() over(partition by validator_hash order by round desc) as row_num
    #		from l2_block_produced_statistics
    #		where validator_hash in (E'\\x1dd26dfb60b996fd5d5152af723949971d9119ee', E'\\x343972bf63d1062761aaaa891d2750f03cb4b2f7')
    #	) sorted
    #	where sorted.row_num < 8
    #	group by validator_hash
    #) src
    #where dest.validator_hash = src.validator_hash

    # https://stackoverflow.com/questions/68880594/ecto-update-query-using-value-from-a-subquery
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

  defp update_l2_validators_block_rate(repo, validator_hash_list, %{timeout: timeout, timestamps: %{updated_at: updated_at}}) when is_list(validator_hash_list) do

    subquery_1 = from(s in Explorer.Chain.PlatonAppchain.L2BlockProducedStatistic, select: %{row_num: row_number() |> over(partition_by: s.validator_hash, order_by: [desc: s.round]), validator_hash: s.validator_hash, should_blocks: s.should_blocks, actual_blocks: s.actual_blocks})
    subquery_2 = from(s2 in subquery(subquery_1), select: %{validator_hash: s2.validator_hash, block_rate:  fragment("round(?, 4)", fragment("cast(? as numeric)", sum(s2.actual_blocks)) / sum(s2.should_blocks)) * 10000}, where: s2.row_num <= 7 and s2.validator_hash in ^validator_hash_list, group_by: s2.validator_hash)


    update_from_select = from(d in Explorer.Chain.PlatonAppchain.L2Validator,
      join: sub in subquery(subquery_2),
      where: d.validator_hash == sub.validator_hash,
      update: [set: [block_rate: sub.block_rate]]
    )
    repo.update_all(update_from_select, [])
  end
end
