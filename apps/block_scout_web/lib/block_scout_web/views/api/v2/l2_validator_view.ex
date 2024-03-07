defmodule BlockScoutWeb.API.V2.L2ValidatorView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.L2ValidatorView
  alias BlockScoutWeb.API.V2.{ApiView, Helper}
  alias Explorer.Chain
  alias Explorer.Chain.ValidatorNode
  alias Explorer.Counters.BlockPriorityFeeCounter

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("l2Validators.json", %{validator: validators, next_page_params: next_page_params}) do
    IO.puts("l2Validators.json view======================================")
#    %{"items" => Enum.map(validators, &prepare_validator(&1, nil)), "next_page_params" => next_page_params}
    %{"items" => Enum.map(validators, &prepare_validator(&1, nil)), "next_page_params" => next_page_params}
  end


  def prepare_validator(validator, _conn, single_block? \\ false) do
    %{
      "rank" => validator.rank,
      "name" => validator.name,
      "detail" => validator.detail,
      "logo" => validator.logo,
      "website" => validator.website,
      "validator_hash" => validator.validator_hash,
      "owner_hash" => validator.owner_hash,
      "commission" => validator.commission_rate,
      "self_bonded" => validator.stake_amount,
      "unbondeding" => "unbondeding",
      "pending_withdrawal_bonded" => "pending_withdrawal_bonded待处理",
      "total_delegation" => validator.delegate_amount,
      "validator_reward" => validator.stake_reward,
      "delegator_reward" => validator.delegate_reward,
      "expect_apr" => validator.expect_apr,
      "block_rate" => validator.block_rate,
      "auth_status" => validator.auth_status,
      "status" => validator.status,
      "stake_epoch" => validator.stake_epoch,
    }
  end

  def render("his_validators.json", %{
    his_validators: his_validators,
    next_page_params: next_page_params
  }) do
    %{
      items:
        Enum.map(his_validators, fn his_validator ->
           %{
             "no" => his_validator.stake_epoch,
             "validators" => his_validator.validator_hash,
             "status" => his_validator.status,
             "exit_block" => his_validator.exit_block,
             "event" => his_validator.exit_desc
           }
        end),
      next_page_params: next_page_params
    }
  end

  # 参考 lib\block_scout_web\views\api\v2\address_view.ex
  def render("validator_details.json", %{
    validator_detail: validator_detail
  }) do
    %{
      "owner_address" => validator_detail.owner_hash,
      "commission" => validator_detail.commission_rate,
      "website" => validator_detail.website,
      "detail" => validator_detail.detail,
      "total_bonded" => "待统计",
      "self_stakes" => "待统计",
      "delegations" => validator_detail.delegate_amount,
      "blocks" => "待统计",
      "expect_apr" => validator_detail.expect_apr,
      "total_rewards" => "待统计",    # Decimal.add(validator_detail.stake_reward, validator_detail.delegate_reward),
      "validator_claimable_rewards" => "待统计"
    }
  end

  def render("stakings.json", %{
    stakings: stakings,
    next_page_params: next_page_params
  }) do
    %{
      items:
        Enum.map(stakings, fn staking ->
          %{
            "tx_hash" => staking.hash,
            "block_timestamp" => staking.block_timestamp,
            "block_number" => staking.block_number,
            "amount" => staking.amount
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("block_produced.json", %{
    block_produced: block_produced,
    next_page_params: next_page_params
  }) do
    %{
      items:
        Enum.map(block_produced, fn block ->
          %{
            "number" => block.number,
            "block_timestamp" => block.block_timestamp,
            "txn" => block.txn,
            "gas_used" => block.gas_used,
            "tx_fee_reward" =>"tx_fee_reward待处理",
            "block_reward" => "block_reward待处理",
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("validator_actions.json", %{
    validator_actions: validator_actions,
    next_page_params: next_page_params
  }) do
    %{
      items:
        Enum.map(validator_actions, fn action ->
          %{
            "tx_hash" => action.hash,
            "block_timestamp" => action.block_timestamp,
            "block_number" => action.block_number,
            "action_desc" => action.action_desc
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("delegators.json", %{
    delegators: delegators,
    next_page_params: next_page_params
  }) do
    %{
      items:
        Enum.map(delegators, fn delegator ->
         %{
           "delegator_address" => delegator.action_desc,
           "amount" => delegator.amount,
           "percentage" => "待处理"
         }
        end),
      next_page_params: next_page_params
    }
  end

end
