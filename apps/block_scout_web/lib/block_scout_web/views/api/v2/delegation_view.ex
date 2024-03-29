defmodule BlockScoutWeb.API.V2.DelegationView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Withdrawal
  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2Delegator
  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler

  @spec render(String.t(), map()) :: map()
  def render("delegations.json", %{delegations: delegations,delegator: delegator_address, next_page_params: next_page_params}) do
    %{"items" => Enum.map(delegations, &prepare_delegation(&1,delegator_address)), "next_page_params" => next_page_params}
  end

  def prepare_delegation(delegation,delegator_address) do
#    # 调底层合约查询数据（可以领取的数量）
#    validator_address = Explorer.Chain.Hash.to_string(delegation.validator)
#    withdraw_ableOf_delegate = L2StakeHandler.withdrawableOfDelegate(validator_address,delegator_address)
#
#    pending_withdrawals_of_delegate = L2StakeHandler.pendingWithdrawalsOfDelegate(validator_address,delegator_address)

    %{
      "validator" => delegation.validator,
      "name" => delegation.name,
      "logo" => delegation.logo,
      "status" => delegation.status,
      "delegation_amount" => delegation.delegation_amount,
      "delegation_percentage" => calc_delegation_percentage(delegation.delegation_amount,delegation.node_stake_amount,delegation.node_delegate_amount), # 有效委托百分比（？？）
      "invalid_delegation_amount" => "怎么取？",
      "unbonding" => delegation.locking_delegate_amount,
      "pending_withdrawal" => delegation.withdrawal_delegate_amount,
      "claimable_rewards" => delegation.pending_delegate_reward
    }
  end

  defp calc_delegation_percentage(delegation_amount,node_stake_amount,node_delegate_amount) do
    total_staking_amount = Decimal.add(Decimal.new(node_stake_amount.value), Decimal.new(node_delegate_amount.value))
    delegation_percentage =
      if total_staking_amount == 0 do
        0
      else
        dividend = Decimal.div(delegation_amount, total_staking_amount)
        multiplied = Decimal.mult(dividend, Decimal.new(100))
        Decimal.round(multiplied, 2)
      end
  end
end
