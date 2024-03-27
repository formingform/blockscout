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

    # 把changes_list中的l2_validator_events分类
    updated_validator_hashes = filter_updated_validator_hashes(changes_list)
    existed_validator_infos = filter_existed_validator_infos(changes_list)

    delegator_hashes = filter_existed_validator_infos(changes_list)

    # 把l2_validator_events 插入表
    multi
    |> Multi.run(:insert_l2_validator_events, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :l2_validator_events,
        :l2_validator_events
      )
    end)

    # 修改l2_validator表
    multi
    |> Multi.run(:upsert_l2_validator_at_validator_events, fn repo, updated_validator_hashes when is_list(updated_validator_hashes)  ->
      Instrumenter.block_import_stage_runner(
        fn -> upsert_validator(repo, updated_validator_hashes, update_transactions_options) end,
        :l2_validator_events,
        :l2_validator_events,
        :upsert_l2_validator_at_validator_events
      )
    end)

    # 备份退出的验证人
    multi
    |> Multi.run(:backup_l2_validator_at_validator_events, fn repo, existed_validator_infos when is_list(existed_validator_infos)  ->
      Instrumenter.block_import_stage_runner(
        fn -> backup_exited_validator(repo, existed_validator_infos, update_transactions_options) end,
        :l2_validator_events,
        :l2_validator_events,
        :backup_exited_l2_validator_at_validator_events
      )
    end)

    # 删除退出的验证人
    multi
    |> Multi.run(:delete_l2_validator_at_validator_events, fn repo, existed_validator_infos when is_list(existed_validator_infos)   ->
      Instrumenter.block_import_stage_runner(
        fn -> delete_exited_validator(repo, existed_validator_infos, update_transactions_options) end,
        :l2_validator_events,
        :l2_validator_events,
        :delete_l2_validator_at_validator_events
      )
    end)
  end

  # 根据事件过滤出需要更新的验证人[validator_hash]
  defp filter_updated_validator_hashes(l2_validator_events) do
      l2_validator_events
      |> Enum.reduce([], fn validator_event, acc ->  [validator_event.validator_hash | acc] end)
      |> Enum.uniq() # 去重
   end

  # 根据事件过滤出因为退出需要备份到历史表的验证人，并组成备份信息[%{validator_hash, status, block_number, exit_desc}]
  defp filter_existed_validator_infos(l2_validator_events) do
      l2_validator_events
      |> Enum.reduce([], fn validator_event, acc ->
        case validator_event.action_type do
          @l2_validator_event_action_type_UnStaked ->
            [%{validator_hash: validator_event.validator_hash, status: 32, block_number: validator_event.block_number, exit_desc: "UnStaked"} | acc]
          @l2_validator_event_action_type_Slashed  ->
            [%{validator_hash: validator_event.validator_hash, status: 64, block_number: validator_event.block_number, exit_desc: "Slashed"} | acc]
          _ -> acc
        end
      end)
  end

  defp upsert_validator(repo, updated_validator_hashes, %{timeout: timeout, timestamps: timestamps}) do
    {:ok, "No L2 validator to update"}
  end

  # 跟新验证人信息，需要根据validator_hash去链上查询validator的信息，用upsert的模式（insert/update）更新表数据，l2_validators.status是个复合状态
  defp upsert_validator(repo, updated_validator_hashes, %{timeout: timeout, timestamps: timestamps}) when length(updated_validator_hashes) > 0 do
    Enum.each(updated_validator_hashes, fn validator_hash ->
      case L2ValidatorService.upsert_validator(repo, Hash.to_string(validator_hash)) do
        {:ok, _result} -> :ok
        {:error, _reason} -> throw({:error, "Update L2 validator failed"})
      end
    end)
    {:ok, "Update L2 validator successfully"}
  end

  defp backup_exited_validator(repo, existed_validator_infos, %{timeout: timeout, timestamps: timestamps}) do
    {:ok, "No validator to backup"}
  end
  # 把验证人备份到l2_validator_historys表，实际上insert into select from的过程
  defp backup_exited_validator(repo, existed_validator_infos, %{timeout: timeout, timestamps: timestamps}) when length(existed_validator_infos) > 0 do
    Enum.each(existed_validator_infos, fn {validator_hash, status, block_number, exit_desc} ->
      case L2ValidatorService.backup_exited_validator(repo, Hash.to_string(validator_hash), status, block_number, exit_desc) do
        {:ok, _result} -> :ok
        {:error, _reason} -> throw({:error, "Backup exited l2 validator failed"})
      end
    end)
    {:ok, "Backup exited L2 validator successfully"}
  end

  defp delete_exited_validator(repo, existed_validator_infos, %{timeout: timeout, timestamps: timestamps}) do
    {:ok, "No validator to delete"}
  end
  # 删除验证人，把验证人从l2_validators表里删除
  defp delete_exited_validator(repo, existed_validator_infos, %{timeout: timeout, timestamps: timestamps}) when length(existed_validator_infos) > 0 do
    Enum.each(existed_validator_infos, fn {validator_hash, _status, _block_number, _exit_desc} ->
      case L2ValidatorService.delete_exited_validator(repo, Hash.to_string(validator_hash)) do
        {:ok, _result} -> :ok
        {:error, _reason} -> throw({:error, "Delete existed L2 validator failed"})
      end
    end)
    {:ok, "Delete existed L2 validator successfully"}
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
          delegator_hash: fragment("EXCLUDED.delegator_hash"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", l.inserted_at), # LEAST返回给定的最小值 EXCLUDED.inserted_at 表示已存在的值
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", l.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.block_number,EXCLUDED.action_type,EXCLUDED.action_desc,EXCLUDED.amount,
          EXCLUDED.block_timestamp,EXCLUDED.delegator_hash) IS DISTINCT FROM (?,?,?,?,?,?)", # 有冲突时只更新这些字段
          l.block_number,
          l.action_type,
          l.action_desc,
          l.amount,
          l.block_timestamp,
          l.delegator_hash
        )
    )
  end
end
