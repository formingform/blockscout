defmodule BlockScoutWeb.API.V2.ValidatorView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Withdrawal

  @spec render(String.t(), map()) :: map()
  def render("validators.json", %{validators: validators, next_page_params: next_page_params}) do
    %{"items" => Enum.map(validators, &prepare_validator(&1)), "next_page_params" => next_page_params}
  end

  def prepare_validator(validator) do
    %{
      "validator" => validator.validator,
      "name" => validator.name,
      "logo" => validator.logo,
      "status" => validator.status,
      "amount" => validator.stake_amount,
#      "delegation_amount" => validator.delegation_amount,
#      "invalid_delegation_amount" => delegation.invalid_delegation_amount
#      "unbonding" => delegation.unbonding,
#      "pending_withdrawal" => delegation.pending_withdrawal,
#      "claimable_rewards" => delegation.claimable_rewards
    }
  end
end
