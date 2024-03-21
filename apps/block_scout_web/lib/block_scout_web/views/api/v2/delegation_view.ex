defmodule BlockScoutWeb.API.V2.DelegationView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Withdrawal

  @spec render(String.t(), map()) :: map()
  def render("delegations.json", %{delegations: delegations, next_page_params: next_page_params}) do
    %{"items" => Enum.map(delegations, &prepare_delegation(&1)), "next_page_params" => next_page_params}
  end

  def prepare_delegation(delegation) do
    %{
      "validator" => delegation.validator,
      "name" => delegation.name,
      "logo" => delegation.logo,
      "status" => delegation.status,
      "delegation_amount" => delegation.delegation_amount, # 有效委托
#      "invalid_delegation_amount" => delegation.invalid_delegation_amount
#      "unbonding" => delegation.unbonding,
#      "pending_withdrawal" => delegation.pending_withdrawal,
#      "claimable_rewards" => delegation.claimable_rewards
    }
  end
end
