defmodule Explorer.Chain.Import.Runner.PlatonAppchain.Commitment do

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, Commitment}
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Chain.PlatonAppchain.Commitment

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Commitment.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Commitment

  @impl Import.Runner
  def option_key, do: :commitments

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

    Multi.run(multi, :insert_commitments, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :commitments,
        :commitments
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Commitment.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # 按start_id排序
    ordered_changes_list = Enum.sort_by(changes_list, & &1.start_id)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: Commitment,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )

  end

  defp default_on_conflict do
    from(
      l in Commitment,
      update: [
        set: [
          # Don't update `state_batch_hash` as it is a primary key and used for the conflict target
          start_end_Id: fragment("EXCLUDED.start_end_Id"),
          state_batch_hash: fragment("EXCLUDED.state_batch_hash"),
          state_root: fragment("EXCLUDED.state_root"),
          start_id: fragment("EXCLUDED.start_id"),
          end_id: fragment("EXCLUDED.end_id"),
          tx_number: fragment("EXCLUDED.tx_number"),
          from: fragment("EXCLUDED.from"),
          to: fragment("EXCLUDED.to"),
          block_number: fragment("EXCLUDED.block_number"),
          block_timestamp: fragment("EXCLUDED.block_timestamp"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.start_end_Id,EXCLUDED.state_batch_hash,EXCLUDED.state_root,EXCLUDED.start_id,EXCLUDED.end_id,EXCLUDED.tx_number,EXCLUDED.from,
          EXCLUDED.to,EXCLUDED.block_number,EXCLUDED.block_timestamp) IS DISTINCT FROM (?,?,?,?,?,?,?,?,?,?)", # 有冲突时只更新这些字段
          l.start_end_Id,
          l.state_batch_hash,
          l.state_root,
          l.start_id,
          l.end_id,
          l.tx_number,
          l.from,
          l.to,
          l.block_number,
          l.block_timestamp
        )
    )
  end
end
