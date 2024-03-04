defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L2ValidatorEvents do

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Hash
  alias Explorer.Chain.PlatonAppchain.L2ValidatorEvent
  alias Indexer.Fetcher.PlatonAppchain.L2ValidatorService
  alias Explorer.Chain.PlatonAppchain.L2Validator
  alias Explorer.Prometheus.Instrumenter
  alias Indexer.Fetcher.PlatonAppchain
  alias Explorer.Chain.Import.Runner

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @l2_validator_event_action_type_ValidatorRegistered 1
  @l2_validator_event_action_type_StakeAdded 2
  @l2_validator_event_action_type_DelegationAdded 3
  @l2_validator_event_action_type_UnStaked 4
  @l2_validator_event_action_type_UnDelegated 5
  @l2_validator_event_action_type_Slashed 6
  @l2_validator_event_action_type_StakeWithdrawalRegistered 7
  @l2_validator_event_action_type_StakeWithdrawal 8
  @l2_validator_event_action_type_DelegateWithdrawalRegistered 9
  @l2_validator_event_action_type_DelegateWithdrawal 10
  @l2_validator_event_action_type_UpdateValidatorStatus 11

  @type imported :: [L2ValidatorEvent.t()]

  @impl Import.Runner
  def ecto_schema_module, do: L2ValidatorEvent

  @impl Import.Runner
  def option_key, do: :l2_validator_events

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

    # 获取事务操作的超时时间，如果没有指定，则使用默认的超时时间
    transactions_timeout = options[Runner.PlatonAppchain.L2ValidatorEvents.option_key()][:timeout] || Runner.PlatonAppchain.L2ValidatorEvents.timeout()

    # 创建超时时间和时间戳信息的map
    update_transactions_options = %{timeout: transactions_timeout, timestamps: timestamps}

    multi
    |> Multi.run(:insert_l2_validator_events, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l2_validator_events,
        :l2_validator_events
      )
    end)
    |> Multi.run(:update_l2_validator_at_validator_events, fn repo,
                                                              %{
                                                                insert_l2_validator_events: l2_validator_events
                                                              }
                                                              when is_list(l2_validator_events)  ->
      Instrumenter.block_import_stage_runner(
        fn -> update_l2_validator(repo, l2_validator_events, update_transactions_options) end,
        :l2_validator_events,
        :l2_validator_events,
        :update_l2_validator_at_validator_events
      )
    end)
  end

  defp update_l2_validator(repo,l2_validator_events, %{timeout: timeout, timestamps: timestamps}) when length(l2_validator_events) > 0 do
    #Enum.map(l2_validator_events, fn validator ->
    Enum.each(l2_validator_events, fn validator_event ->
      %Explorer.Chain.PlatonAppchain.L2ValidatorEvent{validator_hash: validator_hash, action_type: action_type, amount: amount} = validator_event
#      query =
#        from(v in L2Validator,
#          where: v.validator_hash == ^validator_hash,
#          lock: "FOR NO KEY UPDATE"
#        )

      try do
        case action_type do
          @l2_validator_event_action_type_ValidatorRegistered ->
            {result, _} = L2ValidatorService.add_new_validator(repo, Hash.to_string(validator_hash))

          @l2_validator_event_action_type_StakeAdded ->
            {result, _} = repo.update_all(
              from(v in L2Validator, where: v.validator_hash == ^validator_hash),
              #query,
              [inc: [stake_amount: amount]],
              timeout: timeout
            )

          @l2_validator_event_action_type_DelegationAdded ->
            {result, _} = repo.update_all(
              from(v in L2Validator, where: v.validator_hash == ^validator_hash),
              #query,
              [inc: [delegate_amount: amount]],
              timeout: timeout
            )

          @l2_validator_event_action_type_UnStaked ->
            {result, _} = repo.update_all(
              from(v in L2Validator, where: v.validator_hash == ^validator_hash),
              #query,
              [inc: [stake_amount: 0-amount]],
              timeout: timeout
            )

          @l2_validator_event_action_type_UnDelegated ->
            {result, _} = repo.update_all(
              from(v in L2Validator, where: v.validator_hash == ^validator_hash),
              #query,
              [inc: [delegate_amount: 0-amount]],
              timeout: timeout
            )

          @l2_validator_event_action_type_Slashed ->
            {result, _} = repo.update_all(
              from(v in L2Validator, where: v.validator_hash == ^validator_hash),
              #query,
              [inc: [stake_amount: 0-amount]], # 惩罚金：
              timeout: timeout
            )

          @l2_validator_event_action_type_UpdateValidatorStatus ->
            {result, _} = repo.update_all(
              from(v in L2Validator, where: v.validator_hash == ^validator_hash, update: [set: [status: ^amount]]), # 在状态变更事件中，amount表示：状态
              timeout: timeout
            )

        end
      rescue
        postgrex_error in Postgrex.Error ->
          {:error, %{exception: postgrex_error, validator_hash: validator_hash}}
      end
    end)
    {:ok, "update_l2_validator process success"}
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L2ValidatorEvent.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # 按block_number排序
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.block_number, &1.hash, &1.log_index})

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: [:hash, :log_index, :validator_hash],
      on_conflict: on_conflict,
      for: L2ValidatorEvent,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )

  end

  defp default_on_conflict do
    from(
      l in L2ValidatorEvent,
      update: [
        set: [
          # Don't update `hash` `log_index` `validator_hash` as it is a primary key and used for the conflict target
          block_number: fragment("EXCLUDED.block_number"),
          action_type: fragment("EXCLUDED.action_type"),
          action_desc: fragment("EXCLUDED.action_desc"),
          amount: fragment("EXCLUDED.amount"),
          block_timestamp: fragment("EXCLUDED.block_timestamp"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.block_number,EXCLUDED.action_type,EXCLUDED.action_desc,EXCLUDED.amount,
          EXCLUDED.block_timestamp) IS DISTINCT FROM (?,?,?,?,?)", # 有冲突时只更新这些字段
          l.block_number,
          l.action_type,
          l.action_desc,
          l.amount,
          l.block_timestamp
        )
    )
  end
end
