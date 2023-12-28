defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L2Validators do

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, L2Validator}
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Chain.PlatonAppchain.L2Validator

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [L2Validator.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L2Validator

  @impl Import.Runner
  def option_key, do: :l2_validators

  @impl Import.Runner
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

    Multi.run(multi, :insert_l2_validators, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l2_validators,
        :l2_validators
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L2Validator.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # 按validator_hash排序
    ordered_changes_list = Enum.sort_by(changes_list, & &1.validator_hash)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :validator_hash,
      on_conflict: on_conflict,
      for: L2Validator,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )

  end

  defp default_on_conflict do
    from(
      l in L2Validator,
      update: [
        set: [
          # Don't update `msg_id` as it is a primary key and used for the conflict target
          rank: fragment("EXCLUDED.rank"),
          name: fragment("EXCLUDED.rank"),
          detail: fragment("EXCLUDED.rank"),
          logo: fragment("EXCLUDED.rank"),
          website: fragment("EXCLUDED.rank"),
          owner_hash: fragment("EXCLUDED.owner_hash"),
          commission: fragment("EXCLUDED.commission"),
          self_bonded: fragment("EXCLUDED.self_bonded"),
          unbondeding: fragment("EXCLUDED.unbondeding"),
          pending_withdrawal_bonded: fragment("EXCLUDED.pending_withdrawal_bonded"),
          total_delegation: fragment("EXCLUDED.total_delegation"),
          validator_reward: fragment("EXCLUDED.validator_reward"),
          delegator_reward: fragment("EXCLUDED.delegator_reward"),
          expect_apr: fragment("EXCLUDED.expect_apr"),
          block_rate: fragment("EXCLUDED.block_rate"),
          auth_status: fragment("EXCLUDED.auth_status"),
          status: fragment("EXCLUDED.status"),
          stake_epoch: fragment("EXCLUDED.stake_epoch"),
          epoch: fragment("EXCLUDED.epoch"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.rank,EXCLUDED.owner_hash,EXCLUDED.validator_hash,EXCLUDED.commission,EXCLUDED.self_bonded,EXCLUDED.unbondeding,
          EXCLUDED.pending_withdrawal_bonded,EXCLUDED.total_delegation,EXCLUDED.validator_reward,EXCLUDED.delegator_reward,EXCLUDED.auth_status,
          EXCLUDED.status,EXCLUDED.stake_epoch,EXCLUDED.epoch) IS DISTINCT FROM (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", # 有冲突时只更新这些字段
          l.rank,
          l.owner_hash,
          l.validator_hash,
          l.commission,
          l.self_bonded,
          l.unbondeding,
          l.pending_withdrawal_bonded,
          l.total_delegation,
          l.validator_reward,
          l.delegator_reward,
          l.auth_status,
          l.status,
          l.stake_epoch,
          l.epoch
        )
    )
  end
end
