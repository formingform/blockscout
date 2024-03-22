defmodule BlockScoutWeb.API.V2.PlatonAppchainValidatorView do
  use BlockScoutWeb, :view

  # l2_validators 是从个struct list，是通过ecto查询得到的数据库记录对象
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
      "role" => validator.role # 0-candidate(质押节点) 1-active(共识节点候选人) 2-verifying(共识节点)
    }
  end

  defp convert_l2_history_validator(validator) do
    %{
      "no" => validator.stake_epoch,
      "validators" => validator.validator_hash,
      "status" => validator.status, # 0: 正常 1：无效 2：低出块 4: 低阈值 8: 双签 32：解质押 64:惩罚
      "exit_block" => validator.exit_block,
      "event" => validator.exit_desc
    }
  end

  @spec render(String.t(), map()) :: map()
  def render("platon_appchain_validators.json", %{validators: validators}) do
    %{items: Enum.map(validators, fn validator -> convert_l2_validator(validator) end)}
  end

  @spec render(String.t(), map()) :: map()
  def render("platon_appchain_history_validators.json", %{validators: validators, next_page_params: next_page_params}) do
    items = Enum.with_index(validators) |> Enum.map(fn {validator, index} -> {convert_l2_history_validator(validator) |> Map.put("index", index + 1)} end)
    %{items: items, next_page_params: next_page_params}
  end

  @spec render(String.t(), map()) :: map()
  def render("platon_appchain_validator_details.json", %{validator: validator}) do
    %{items: convert_l2_validator(validator)}
  end


end
