defmodule Explorer.Chain.Import.Runner.PlatonAppchain.L2ValidatorEvents do

  require Ecto.Query
  require Logger

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Hash
  alias Explorer.Chain.PlatonAppchain.L2ValidatorEvent
  alias Indexer.Fetcher.PlatonAppchain.L2ValidatorService
  alias Explorer.Chain.PlatonAppchain.L2Validator
  alias Explorer.Prometheus.Instrumenter
  alias Indexer.Fetcher.PlatonAppchain
  alias Explorer.Chain.Import.Runner
  alias BlockScoutWeb.Endpoint

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
  def run(multi, changes_list, %{timestamps: timestamps} = options) when length(changes_list) > 0 do
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

    # 把 l2_validator_events 按 action_type 是否是新增验证人 分组
    # event_groups是个map，key: true / false value: [2_validator_event]
    registered_events_and_others = Enum.group_by(changes_list, fn(e) -> e[:action_type] == PlatonAppchain.l2_validator_event_action_type()[:ValidatorRegistered] end)

    multi
    |> Multi.run(:insert_l2_validator_events, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l2_validator_events,
        :l2_validator_events
      )
    end)
    |> Multi.run(:add_new_l2_validators, fn repo,
                                                  %{
                                                    true => registered_events
                                                  } = registered_events_and_others
                                                  when is_list(registered_events)  ->
      Instrumenter.block_import_stage_runner(
        fn -> register_validator(repo, registered_events, update_transactions_options) end,
        :l2_validators,
        :l2_validators,
        :register_l2_validators
      )
    end)
    |> Multi.run(:update_l2_validators, fn repo,
                                                  %{
                                                    false => updated_events
                                                  } = registered_events_and_others
                                                  when is_list(updated_events)  ->
      Instrumenter.block_import_stage_runner(
        fn -> update_validator(repo, updated_events, update_transactions_options) end,
        :l2_validators,
        :l2_validators,
        :update_l2_validators
      )
    end)
  end


  defp register_validator(repo, l2_new_validator_events, %{timeout: timeout, timestamps: timestamps})  do
    registered_validator_hash_list =
      l2_new_validator_events
    |> Enum.reduce([], fn validator_event, acc ->  [validator_event.validator_hash | acc] end)
    |> Enum.uniq() # 去重
    # 需要用upsert的模式（insert/update）新增表数据， l2_validators.status是个复合状态
    Enum.each(registered_validator_hash_list, fn validator_hash ->
      case L2ValidatorService.upsert_validator(repo, Hash.to_string(validator_hash)) do
        {:ok, _result} -> :ok
        {:error, _reason} -> throw({:error, "add new validator(s) failed"})
      end
    end)
    # 添加成功通过ws给前端发消息 begin
    Endpoint.broadcast("platon_appchain_l2_validator:all_validator", "all_validator", 1)
    # 添加成功通过ws给前端发消息 end
    {:ok, "add new validator(s) successfully"}
  end

  defp update_validator(repo, l2_validator_updated_events, %{timeout: timeout, timestamps: timestamps})  do
    updated_validator_hash_list =
      l2_validator_updated_events
      |> Enum.reduce([], fn validator_event, acc ->  [validator_event.validator_hash | acc] end)
      |> Enum.uniq() # 去重

    Enum.each(updated_validator_hash_list, fn validator_hash ->
      case L2ValidatorService.update_validator(repo, Hash.to_string(validator_hash)) do
        {:ok, _result} -> :ok
        {:error, _reason} -> throw({:error, "add new validator(s) failed"})
      end
    end)
    {:ok, "add new validator(s) successfully"}
  end



#  defp backup_exited_validator(repo, l2_validator_events, %{timeout: timeout, timestamps: timestamps}) do
#    validator_hash_list =
#      l2_validator_events
#      |> Enum.reduce([], fn validator_event, acc ->
#        case validator_event.action_type do
#          @l2_validator_event_action_type_UnStaked ->
#            [%{validator_hash: validator_event.validator_hash, status: 32, block_number: validator_event.block_number, exit_desc: "UnStaked"} | acc]
#          @l2_validator_event_action_type_Slashed  ->
#            [%{validator_hash: validator_event.validator_hash, status: 64, block_number: validator_event.block_number, exit_desc: "Slashed"} | acc]
#          _ -> acc
#        end
#      end)
#    if validator_hash_list == nil do
#      {:ok, "No validators exited and to backup to history"}
#    end
#
#    Enum.each(validator_hash_list, fn {validator_hash, status, block_number, exit_desc} ->
#      case L2ValidatorService.backup_exited_validator(repo, Hash.to_string(validator_hash), status, block_number, exit_desc) do
#        {:ok, _result} -> :ok
#        {:error, _reason} -> throw({:error, "Backup exited l2 validator failed"})
#      end
#    end)
#    {:ok, "Backup exited L2 validator successfully"}
#  end

#  defp delete_exited_validator(repo, l2_validator_events, %{timeout: timeout, timestamps: timestamps}) do
#    validator_hash_list =
#      l2_validator_events
#      |> Enum.reduce([], fn validator_event, acc ->
#        if validator_event.action_type == @l2_validator_event_action_type_UnStaked || validator_event.action_type == @l2_validator_event_action_type_Slashed do
#          [%{validator_hash: validator_event.validator_hash, block_number: validator_event.block_number} | acc]
#        end
#      end)
#      #|> Enum.reverse()
#      #|> Enum.uniq_by(fn {x, _} -> x end) # 去重
#    if validator_hash_list == nil do
#      {:ok, "No validators to delete"}
#    else
#      Enum.each(validator_hash_list, fn validator_hash ->
#        case L2ValidatorService.delete_exited_validator(repo, Hash.to_string(validator_hash)) do
#          {:ok, _result} -> :ok
#          {:error, _reason} -> throw({:error, "Delete existed L2 validator failed"})
#        end
#      end)
#      {:ok, "Delete existed L2 validator successfully"}
#    end
#  end



  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [L2ValidatorEvent.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
#    Logger.error(fn -> "run L2ValidatorEvents import==============#{inspect(changes_list)}========insert insert=================)" end)
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
          # Don't update `hash` `log_index` as it is a primary key and used for the conflict target
          block_number: fragment("EXCLUDED.block_number"),
          epoch: fragment("EXCLUDED.epoch"),
          validator_hash: fragment("EXCLUDED.validator_hash"),
          action_type: fragment("EXCLUDED.action_type"),
          action_desc: fragment("EXCLUDED.action_desc"),
          amount: fragment("EXCLUDED.amount"),
          block_timestamp: fragment("EXCLUDED.block_timestamp"),
          delegator_hash: fragment("EXCLUDED.delegator_hash"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.block_number,EXCLUDED.epoch,EXCLUDED.validator_hash,EXCLUDED.action_type,EXCLUDED.action_desc,EXCLUDED.amount,
          EXCLUDED.block_timestamp,EXCLUDED.delegator_hash) IS DISTINCT FROM (?,?,?,?,?,?,?,?)", # 有冲突时只更新这些字段
          l.block_number,
          l.epoch,
          l.validator_hash,
          l.action_type,
          l.action_desc,
          l.amount,
          l.block_timestamp,
          l.delegator_hash
        )
    )
  end
end
