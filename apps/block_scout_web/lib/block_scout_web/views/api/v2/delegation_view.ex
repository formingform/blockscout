defmodule BlockScoutWeb.API.V2.DelegationView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Withdrawal
  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler

  @spec render(String.t(), map()) :: map()
  def render("delegations.json", %{delegations: delegations,delegator: delegator_address, next_page_params: next_page_params}) do
    %{"items" => Enum.map(delegations, &prepare_delegation(&1,delegator_address)), "next_page_params" => next_page_params}
  end

  def prepare_delegation(delegation,delegator_address) do
    # 调底层合约查询数据
    validator_address = Explorer.Chain.Hash.to_string(delegation.validator)
    withdrawableOfDelegate = L2StakeHandler.withdrawableOfDelegate(validator_address,delegator_address)


    %{
      "validator" => delegation.validator,
      "name" => delegation.name,
      "logo" => delegation.logo,
      "status" => delegation.status,
      "delegation_amount" => delegation.delegation_amount, # 有效委托
#      "invalid_delegation_amount" => delegation.invalid_delegation_amount
#      "unbonding" => delegation.unbonding,
#      "pending_withdrawal" => delegation.pending_withdrawal,
      "claimable_rewards" => withdrawableOfDelegate
    }
  end
end
