defmodule Indexer.Fetcher.PlatonAppchain.L2DelegatorService do
  @moduledoc """
  处理l2_delegator相关业务.
  """
  require Logger
  use Bitwise
  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler
  alias Explorer.Chain
  alias Explorer.Chain.PlatonAppchain.L2Delegator
  alias Indexer.Fetcher.PlatonAppchain
  alias Indexer.Fetcher.PlatonAppchain.L2ValidatorEvent

  #       l2_validator_event: %{
  #            log_index: log_index,
  #            validator_hash: validator_hash,
  #            delegator_hash: delegator_hash,
  #            block_number: block_number,
  #            hash: l2_transaction_hash,
  #            action_type: PlatonAppchain.l2_validator_event_action_type()[:UnDelegated],
  #            action_desc: "delegator: 0x#{Base.encode16(delegator_hash)}",
  #            amount: amount,
  #            block_timestamp: timestamp
  #          }

  # 判断出哪些委托人的信息需要修改，条件：
  # 1. 在 block_range 中的 l2_validator_events事件中，是否有委托相关事件
  # 2. 查询 l2_validator_events中，是否有撤销委托的事件，并且锁定结束的epoch在 block_range 中
  # 2. 如果以上两个条件有委托相关事件，则用end of block_range作为参数，eth_call调用相应rpc接口，查询委托人详情
  @spec refreshed_delegators(list(), Range.t()) :: list()
  def refreshed_delegators(l2_validator_events, block_first..block_last) do
    l2_delegator_events =
      if Enum.empty?(l2_validator_events) == false do
        []
      else
        l2_validator_events
        |> Enum.filter(fn event -> event.action_type == PlatonAppchain.l2_validator_event_action_type()[:AddDelegated]
                                   || event.action_type == PlatonAppchain.l2_validator_event_action_type()[:UnDelegated]
                                   || event.action_type == PlatonAppchain.l2_validator_event_action_type()[:DelegateWithdrawalRegistered]
                                   || event.action_type == PlatonAppchain.l2_validator_event_action_type()[:DelegateWithdrawal] end)
      end


    first_epoch = PlatonAppchain.calculateL2Epoch(block_first)

    # block_last 如果不是刚好last_epoch的结束块高，则需要-1
    last_epoch =
      if PlatonAppchain.is_epoch_end_block(block_last) do
        PlatonAppchain.calculateL2Epoch(block_last)
      else
        PlatonAppchain.calculateL2Epoch(block_last) -1
      end

    #当前同步的first_epoch..last_epoch的区块，能解锁irst_epoch-6..last_epoch-6期间锁定的撤销委托
    epochs_for_locking_undelegation = PlatonAppchain.l2_epochs_for_locking_undelegation(block_last)
    total_delegator_events =
    if last_epoch > epochs_for_locking_undelegation do
      undelegate_last_epoch = last_epoch - epochs_for_locking_undelegation
      undelegate_first_epoch =
      if first_epoch > epochs_for_locking_undelegation do
        first_epoch - epochs_for_locking_undelegation
      else
        1
      end
      l2_delegator_events ++ L2ValidatorEvent.get_undelegate_events_by_epoch_range(undelegate_first_epoch, undelegate_last_epoch)
    else
      []
    end


    #找出经过去重的需要更新的委托人:验证人数据对
    unique_delegator_validator =
    if Enum.empty?(total_delegator_events) == true do
      []
    else
      # 过滤唯一的delegator_hash, validator_hash数据对，结果如下所示：
      #    [
      #      %{validator_hash: "0x01", delegator_hash: "0x0101"},
      #      %{validator_hash: "0x01", delegator_hash: "0x0202"},
      #      %{validator_hash: "0x02", delegator_hash: "0x0202"},
      #    ]
      Enum.reduce(total_delegator_events, MapSet.new(), fn event, acc -> MapSet.put(acc, %{validator_hash: event.validator_hash, delegator_hash: event.delegator_hash}) end)
    end

    if Enum.empty?(unique_delegator_validator) == false do
      L2Delegator.update_delegations(L2StakeHandler.getDelegateDetails(unique_delegator_validator))
    end
  end
end
