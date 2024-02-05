defmodule Explorer.Chain.Import.Runner.PlatonAppchain.Checkpoints do

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.PlatonAppchain.Checkpoint
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Checkpoint.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Checkpoint

  @impl Import.Runner
  def option_key, do: :checkpoints

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

    Multi.run(multi, :insert_checkpoints, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :checkpoints,
        :checkpoints
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Checkpoint.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # 按epoch排序
    ordered_changes_list = Enum.sort_by(changes_list, & &1.epoch)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :epoch,
      on_conflict: on_conflict,
      for: Checkpoint,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )

  end

  defp default_on_conflict do
    from(
      l in Checkpoint,
      update: [
        set: [
          # Don't update `epoch` as it is a primary key and used for the conflict target
          start_block_number: fragment("EXCLUDED.start_block_number"),
          end_block_number: fragment("EXCLUDED.end_block_number"),
          event_root: fragment("EXCLUDED.event_root"),
          event_counts: fragment("EXCLUDED.event_counts"),
          block_number: fragment("EXCLUDED.block_number"),
          hash: fragment("EXCLUDED.hash"),
          block_timestamp: fragment("EXCLUDED.block_timestamp"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.start_block_number,EXCLUDED.end_block_number,EXCLUDED.event_root,EXCLUDED.event_counts,EXCLUDED.block_number,
          EXCLUDED.hash,EXCLUDED.block_timestamp) IS DISTINCT FROM (?,?,?,?,?,?,?)", # 有冲突时只更新这些字段
          l.start_block_number,
          l.end_block_number,
          l.event_root,
          l.event_counts,
          l.block_number,
          l.hash,
          l.block_timestamp
        )
    )
  end
end
