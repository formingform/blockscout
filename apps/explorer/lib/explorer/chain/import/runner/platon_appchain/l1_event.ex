defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L1Event do

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, L1Event}
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Chain.PlatonAppchain.L1Event

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [L1Event.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L1Event

  @impl Import.Runner
  def option_key, do: :l1_events

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

    Multi.run(multi, :insert_l1_events, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l1_events,
        :l1_events
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L1Event.t()]}
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
      for: L1Event,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )

  end

  defp default_on_conflict do
    from(
      l in L1Event,
      update: [
        set: [
          # Don't update `event_id` as it is a primary key and used for the conflict target
          event_id: fragment("EXCLUDED.event_id"),
          tx_type: fragment("EXCLUDED.tx_type"),
          amount: fragment("EXCLUDED.amount"),
          hash: fragment("EXCLUDED.hash"),
          from: fragment("EXCLUDED.from"),
          to: fragment("EXCLUDED.to"),
          block_number: fragment("EXCLUDED.block_number"),
          block_timestamp: fragment("EXCLUDED.block_timestamp"),
          validator: fragment("EXCLUDED.validator"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.event_id,EXCLUDED.tx_type,EXCLUDED.amount,EXCLUDED.hash,EXCLUDED.from,EXCLUDED.to,
          EXCLUDED.block_number,EXCLUDED.block_timestamp,EXCLUDED.validator) IS DISTINCT FROM (?,?,?,?,?,?,?,?,?)", # 有冲突时只更新这些字段
          l.event_id,
          l.tx_type,
          l.amount,
          l.hash,
          l.from,
          l.to,
          l.block_number,
          l.block_timestamp,
          l.validator
        )
    )
  end
end
