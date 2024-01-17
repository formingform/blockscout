defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L1Execute do

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, L1Execute}
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Chain.PlatonAppchain.L1Execute

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [L1Execute.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L1Execute

  @impl Import.Runner
  def option_key, do: :l1_executes

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
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :insert_l1_executes, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l1_executes,
        :l1_executes
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L1Execute.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # 按event_id排序
    ordered_changes_list = Enum.sort_by(changes_list, & &1.event_id)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: L1Execute,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )

  end

  defp default_on_conflict do
    from(
      l in L1Execute,
      update: [
        set: [
          # Don't update `event_id` as it is a primary key and used for the conflict target
          event_id: fragment("EXCLUDED.event_id"),
          hash: fragment("EXCLUDED.hash"),
          block_number: fragment("EXCLUDED.block_number"),
          state_batch_hash:  fragment("EXCLUDED.state_batch_hash"),
          replay_status:  fragment("EXCLUDED.replay_status"),
          status:  fragment("EXCLUDED.status"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.event_id,EXCLUDED.hash,EXCLUDED.block_number,EXCLUDED.state_batch_hash,EXCLUDED.replay_status,
          EXCLUDED.status) IS DISTINCT FROM (?,?,?,?,?,?)", # 有冲突时只更新这些字段
          l.event_id,
          l.hash,
          l.block_number,
          l.state_batch_hash,
          l.replay_status,
          l.status
        )
    )
  end
end
