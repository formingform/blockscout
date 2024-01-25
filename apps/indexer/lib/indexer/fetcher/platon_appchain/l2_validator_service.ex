defmodule Indexer.Fetcher.PlatonAppchain.L2ValidatorService do
  @moduledoc """
  更新l2_validator表记录.
  """
  require Logger

  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler
  alias Explorer.Chain
  alias Explorer.Chain.PlatonAppchain.L2Validator
  alias Indexer.Fetcher.PlatonAppchain

  """
        validator_hash: elem(validator, 0),
        owner_hash: elem(validator, 1),
        stake_amount: elem(validator, 2),
        delegate_amount: elem(validator, 3),
        commission_rate: elem(validator, 4),
        status: elem(validator, 5),
        stake_epoch: elem(validator, 6)
  """
  def add_new_validator(validator_hash) do
    newValidatorMap = L2StakeHandler.getValidator(validator_hash)
    L2Validator.add_new_validator(newValidatorMap)
  end

  def increase_stake(validator_hash, increment) do
    L2Validator.update_stake_amount(validator_hash, increment)
  end

  def decrease_stake(validator_hash, decrement) do
    L2Validator.update_stake_amount(validator_hash, 0-decrement)
  end


  def increase_delegation(validator_hash, increment) do
    L2Validator.update_delegate_amount(validator_hash, increment)
  end
  def decrease_delegation(validator_hash, decrement) do
    L2Validator.update_delegate_amount(validator_hash, 0-decrement)
  end

  # [{validator_hash, amount},{...}]
  def slash(slash_tuple_list) do
    L2Validator.slash(slash_tuple_list)
  end

  def update_validator_status(validator_hash, current_status) do
    extracted_status = cond current_status do
      PlatonAppchain.l2_validator_is_slashed(current_status) ->
        PlatonAppchain.l2_validator_status()[:Slashing]
      PlatonAppchain.l2_validator_is_duplicated(current_status) ->
        PlatonAppchain.l2_validator_status()[:Duplicated]
      PlatonAppchain.l2_validator_is_unstaked(current_status) ->
        PlatonAppchain.l2_validator_status()[:Unstaked]
      PlatonAppchain.l2_validator_is_lowBlocks(current_status) ->
        PlatonAppchain.l2_validator_status()[:LowBlocks]
      latonAppchain.l2_validator_is_lowThreshold(current_status) ->
        PlatonAppchain.l2_validator_status()[:LowThreshold]
     end
    L2Validator.update_status(validator_hash, extracted_status)
  end

  # [{validator_hash, rank},{...}]
  def update_rank(rank_tuple_list) do
    L2Validator.update_rank(rank_tuple_list)
  end

end

