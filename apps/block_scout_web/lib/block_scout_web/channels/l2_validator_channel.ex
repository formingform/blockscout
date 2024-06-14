defmodule BlockScoutWeb.L2ValidatorChannel do
  @moduledoc """
  Establishes pub/sub channel for change validator.
  """
  use BlockScoutWeb, :channel

  intercept([
    "all_validator",
    "active_validator",
    "candidate_validator",
    "history_validator"
  ])

  def join("platon_appchain_l2_validator:all_validator", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("platon_appchain_l2_validator:active_validator", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("platon_appchain_l2_validator:candidate_validator", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("platon_appchain_l2_validator:history_validator", _params, socket) do
    {:ok, %{}, socket}
  end

  #    test begin
#  alias BlockScoutWeb.Endpoint
#  Endpoint.broadcast("platon_appchain:l1_to_l2_txn", "l1_to_l2_txn", %{
#    batch: 1
#  })
  #    test end
  def handle_out(
        "all_validator",
        validatorsCount,
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
#    result_validator = Enum.map(validators, fn validator -> convert_l2_validator(validator) end)
    push(socket, "all_validator", validatorsCount)
    {:noreply, socket}
  end

  def handle_out(
        "active_validator",
        activeValidatorsCount,
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
#    result_validator = Enum.map(validators, fn validator -> convert_l2_validator(validator) end)
    push(socket, "active_validator", activeValidatorsCount)
    {:noreply, socket}
  end

  def handle_out(
        "candidate_validator",
        validatorsCount,
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
#    result_validator = Enum.map(validators, fn validator -> convert_l2_validator(validator) end)
    push(socket, "candidate_validator", validatorsCount)
    {:noreply, socket}
  end

  def handle_out(
        "history_validator",
        historyValidatorsCount,
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
#    result_history_validator = Enum.with_index(historyValidators) |> Enum.map(fn {validator, index} -> {convert_l2_history_validator(validator) |> Map.put("index", index + 1)} end)
#    push(socket, "history_validator", result_history_validator)
    push(socket, "history_validator", historyValidatorsCount)
    {:noreply, socket}
  end

  defp convert_l2_validator(validator) do
    %{
      "rank" => validator.rank,
      "validators" => validator.validator_hash,
      "status" => validator.status, # 0: 正常 1：无效 2：低出块 4: 低阈值 8: 双签 32：解质押 64:惩罚
      "stake_epoch" => validator.stake_epoch,
      "owner_hash" => validator.owner_hash,
      "commission" => validator.commission_rate,
      "stake_amount" => validator.stake_amount, # 有效质押金额
      "locking_stake_amount" => validator.locking_stake_amount, # 锁定的质押金额（解除的部分质押，需要锁定一段时间）
      "withdrawal_stake_amount" => validator.withdrawal_stake_amount, # 可提取的质押金额
      "delegate_amount" => validator.delegate_amount, # 有效委托金额
      "stake_reward" => validator.stake_reward,
      "delegate_reward" => validator.delegate_reward,
      "name" => validator.name,
      "detail" => validator.detail,
      "logo" => validator.logo,
      "website" => validator.website,
      "expect_apr" => validator.expect_apr,
      "block_rate" => validator.block_rate,
      "auth_status" => validator.auth_status, #  是否验证 0-未验证，1-已验证
      "role" => validator.role, # 0-candidate(质押节点) 1-active(共识节点候选人) 2-verifying(共识节点)
      "block_rate" => validator.block_rate,
      "total_bonded_amount" => "总质押金额",
      "total_bonded_percent" => "总质押占所有质押比",
    }
  end

  defp convert_l2_history_validator(validator) do
    %{
      "no" => validator.stake_epoch,
      "validators" => validator.validator_hash,
      "status" => validator.status, # 0: 正常 1：无效 2：低出块 4: 低阈值 8: 双签 32：解质押 64:惩罚
      "exit_block" => validator.exit_block,
      "exit_timestamp" => validator.timestamp,
      "event" => validator.exit_desc,
    }
  end

end
