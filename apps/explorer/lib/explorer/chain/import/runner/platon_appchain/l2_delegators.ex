defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L2Delegators do

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.PlatonAppchain.L2Delegator
  alias Explorer.Prometheus.Instrumenter


  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [L2Delegator.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L2Delegator

  @impl Import.Runner
  def option_key, do: :l2_delegators

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

    Multi.run(multi, :insert_l2_delegators, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l2_delegators,
        :l2_delegators
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L2Delegator.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # 按delegator_hash排序
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.delegator_hash, &1.validator_hash})

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: [:delegator_hash, :validator_hash],
      on_conflict: on_conflict,
      for: L2Delegator,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )

  end

  defp default_on_conflict do
    from(
      l in L2Delegator,
      update: [
        set: [
          # Don't update `delegator_hash` as it is a primary key and used for the conflict target
          delegate_amount: fragment("EXCLUDED.delegate_amount"),
          locking_delegate_amount: fragment("EXCLUDED.locking_delegate_amount"),
          withdrawal_delegate_amount: fragment("EXCLUDED.withdrawal_delegate_amount"),
          withdrawn_delegate_reward: fragment("EXCLUDED.withdrawn_delegate_reward"),
          pending_delegate_reward: fragment("EXCLUDED.pending_delegate_reward"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.delegate_amount,EXCLUDED.locking_delegate_amount,EXCLUDED.withdrawal_delegate_amount,
          EXCLUDED.withdrawn_delegate_reward,EXCLUDED.pending_delegate_reward) IS DISTINCT FROM (?,?,?,?,?)", # 有冲突时只更新这些字段
          l.delegate_amount,
          l.locking_delegate_amount,
          l.withdrawal_delegate_amount,
          l.withdrawn_delegate_reward,
          l.pending_delegate_reward
        )
    )
  end
end
