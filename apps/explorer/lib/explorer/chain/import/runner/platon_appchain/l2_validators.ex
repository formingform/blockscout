defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L2Validators do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.PlatonAppchain.L2Validator.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.PlatonAppchain.L2Validator
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [L2Validator.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L2Validator

  @impl Import.Runner
  def option_key, do: :platon_appchain_l2_validators

  @impl Import.Runner
  @spec imported_table_row() :: %{:value_description => binary(), :value_type => binary()}
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

    Multi.run(multi, :insert_platon_appchain_l2_validators, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :platon_appchain_l2_validators,
        :platon_appchain_l2_validators
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

    # 可以不排序
    ordered_changes_list = Enum.sort_by(changes_list, & &1.rank)

    {:ok, inserted} =
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

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      d in L2Validator,
      update: [
        set: [
          # Don't update `msg_id` as it is a primary key and used for the conflict target
          rank: fragment("EXCLUDED.rank"),
          owner_hash: fragment("EXCLUDED.owner_hash"),
          total_bonded: fragment("EXCLUDED.total_bonded"),
          total_delegation: fragment("EXCLUDED.total_delegation"),
          self_stakes: fragment("EXCLUDED.self_stakes"),
          freezing_stakes: fragment("EXCLUDED.freezing_stakes"),
          pending_withdrawal_stakes: fragment("EXCLUDED.pending_withdrawal_stakes"),
          commission_rate: fragment("EXCLUDED.commission_rate"),
          status: fragment("EXCLUDED.status"),
          stake_epoch: fragment("EXCLUDED.stake_epoch"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", d.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", d.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.rank, EXCLUDED.owner_hash, EXCLUDED.total_bonded, EXCLUDED.total_delegation, EXCLUDED.self_stakes, EXCLUDED.freezing_stakes, EXCLUDED.pending_withdrawal_stakes, EXCLUDED.commission_rate, EXCLUDED.status, EXCLUDED.stake_epoch ) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          d.rank,
          d.owner_hash,
          d.total_bonded,
          d.total_delegation,
          d.self_stakes,
          d.freezing_stakes,
          d.pending_withdrawal_stakes,
          d.commission_rate,
          d.status,
          d.stake_epoch
        )
    )
  end
end
