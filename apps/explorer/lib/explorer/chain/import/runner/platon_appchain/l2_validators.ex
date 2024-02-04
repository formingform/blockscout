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
    ordered_changes_list = Enum.sort_by(changes_list, & &1.rank)

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
          stake_epoch: fragment("EXCLUDED.stake_epoch"),
          owner_hash: fragment("EXCLUDED.owner_hash"),
          commission_rate: fragment("EXCLUDED.commission_rate"),
          stake_amount: fragment("EXCLUDED.stake_amount"),
          locking_stake_amount: fragment("EXCLUDED.locking_stake_amount"),
          withdrawal_stake_amount: fragment("EXCLUDED.withdrawal_stake_amount"),
          delegate_amount: fragment("EXCLUDED.delegate_amount"),
          stake_reward: fragment("EXCLUDED.stake_reward"),
          delegate_reward: fragment("EXCLUDED.delegate_reward"),
          rank: fragment("EXCLUDED.rank"),
          name: fragment("EXCLUDED.rank"),
          detail: fragment("EXCLUDED.rank"),
          logo: fragment("EXCLUDED.rank"),
          website: fragment("EXCLUDED.rank"),
          expect_apr: fragment("EXCLUDED.expect_apr"),
          block_rate: fragment("EXCLUDED.block_rate"),
          auth_status: fragment("EXCLUDED.auth_status"),
          role: fragment("EXCLUDED.role"),
          status: fragment("EXCLUDED.status"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.stake_epoch,EXCLUDED.owner_hash,EXCLUDED.commission_rate,EXCLUDED.stake_amount,EXCLUDED.locking_stake_amount,EXCLUDED.withdrawal_stake_amount,
          EXCLUDED.delegate_amount,EXCLUDED.stake_reward,EXCLUDED.delegate_reward,EXCLUDED.rank,EXCLUDED.name,EXCLUDED.detail,EXCLUDED.logo,EXCLUDED.website,
          EXCLUDED.expect_apr,EXCLUDED.block_rate,EXCLUDED.auth_status,EXCLUDED.role,EXCLUDED.status) IS DISTINCT FROM (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", # 有冲突时只更新这些字段
          l.stake_epoch,
          l.owner_hash,
          l.commission_rate,
          l.stake_amount,
          l.locking_stake_amount,
          l.withdrawal_stake_amount,
          l.delegate_amount,
          l.stake_reward,
          l.delegate_reward,
          l.rank,
          l.name,
          l.detail,
          l.logo,
          l.website,
          l.expect_apr,
          l.block_rate,
          l.auth_status,
          l.role,
          l.status
        )
    )
  end
end
