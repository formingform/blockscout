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

end
