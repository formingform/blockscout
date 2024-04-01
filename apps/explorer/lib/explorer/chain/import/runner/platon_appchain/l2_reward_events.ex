defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L2RewardEvents do

  require Ecto.Query
  require Logger

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Hash
  alias Explorer.Chain.PlatonAppchain.L2RewardEvent
  alias Explorer.Chain.PlatonAppchain.L2Delegator
  alias Explorer.Chain.PlatonAppchain.L2Validator
  alias Explorer.Prometheus.Instrumenter
  alias Indexer.Fetcher.PlatonAppchain
  alias Explorer.Chain.Import.Runner

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @l2_reward_event_action_type_withdraw_delegator_reward 1
  @l2_reward_event_action_type_withdraw_validator_reward 2

  @type imported :: [L2RewardEvent.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L2RewardEvent

  @impl Import.Runner
  def option_key, do: :l2_reward_events

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
    transactions_timeout = options[Runner.PlatonAppchain.L2RewardEvents.option_key()][:timeout] || Runner.PlatonAppchain.L2Delegators.timeout()

    # 创建超时时间和时间戳信息的map
    update_transactions_options = %{timeout: transactions_timeout, timestamps: timestamps}

    multi
    |> Multi.run(:insert_l2_reward_events, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l2_reward_events,
        :l2_reward_events
      )
    end)
    |> Multi.run(:update_l2_delegator_validator_events, fn repo,
                                                              %{
                                                                insert_l2_reward_events: l2_reward_events
                                                              }
                                                              when is_list(l2_reward_events)  ->
      Instrumenter.block_import_stage_runner(
        fn -> update_delegator_or_validator(repo, l2_reward_events, update_transactions_options) end,
        :l2_reward_events,
        :l2_reward_events,
        :update_l2_delegator_validator_events
      )
    end)
  end

  defp update_delegator_or_validator(repo, l2_reward_events, %{timeout: timeout, timestamps: timestamps}) do
      l2_reward_events
      |> Enum.reduce([], fn reward_event, acc ->
        case reward_event.action_type do
          @l2_reward_event_action_type_withdraw_delegator_reward ->
            L2Delegator.update_withdrawn_delegator_reward(reward_event.caller, reward_event.validator_hash, reward_event.amount)
          @l2_reward_event_action_type_withdraw_validator_reward  ->
            L2Validator.update_withdrawn_reward(reward_event.validator_hash, reward_event.amount)
          _ -> acc
        end
      end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L2RewardEvent.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # 按block_number排序
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.block_number, &1.hash, &1.log_index})

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: [:hash, :log_index],
      on_conflict: on_conflict,
      for: L2RewardEvent,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      l in L2RewardEvent,
      update: [
        set: [
          # Don't update `hash` `log_index` `validator_hash` as it is a primary key and used for the conflict target
          block_number: fragment("EXCLUDED.block_number"),
          action_type: fragment("EXCLUDED.action_type"),
          amount: fragment("EXCLUDED.amount"),
          block_timestamp: fragment("EXCLUDED.block_timestamp"),
          caller_hash: fragment("EXCLUDED.caller_hash"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.block_number,EXCLUDED.action_type,EXCLUDED.amount,
          EXCLUDED.block_timestamp,EXCLUDED.caller_hash) IS DISTINCT FROM (?,?,?,?,?)", # 有冲突时只更新这些字段
          l.block_number,
          l.action_type,
          l.amount,
          l.block_timestamp,
          l.caller_hash
        )
    )
  end
end
