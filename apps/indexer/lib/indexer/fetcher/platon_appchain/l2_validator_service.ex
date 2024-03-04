defmodule Indexer.Fetcher.PlatonAppchain.L2ValidatorService do
  @moduledoc """
  更新l2_validator表记录.
  """
  require Logger

  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler
  alias Explorer.Chain
  alias Explorer.Chain.PlatonAppchain.L2Validator
  alias Indexer.Fetcher.PlatonAppchain

  #
  #    iex > add_new_validator("0x97ab3d4f7f5051f127b0e9f8d10772125d94d65b")
  #    {:ok, %Explorer.Chain.PlatonAppchain.L2Validator{...}}
  #
  @spec add_new_validator(Repo.t(), binary()) :: {:ok, L2Validator.t()} | {:error, reason :: String.t()}
  def add_new_validator(repo, validator_hex) do
    newValidatorMap = L2StakeHandler.getValidator(validator_hex)
    L2Validator.add_new_validator(repo, newValidatorMap)
  end

  @spec increase_stake(binary(), integer()) :: {:ok, L2Validator.t()} | {:error, reason :: String.t()}
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

  def update_validator_status(validator_hash, current_status, block_number) do
    cond do
      PlatonAppchain.l2_validator_is_slashed(current_status) ->
        L2Validator.update_status(validator_hash,  PlatonAppchain.l2_validator_status()[:Slashing])

      PlatonAppchain.l2_validator_is_duplicated(current_status) ->
        L2Validator.update_status(validator_hash,  PlatonAppchain.l2_validator_status()[:Duplicated])

      PlatonAppchain.l2_validator_is_unstaked(current_status) ->
        # 解质押，把节点信息从l2_validators表移动到l2_validator_historys表中，历史表中状态为：Unstaked
        L2Validator.unstake(validator_hash, block_number, "", PlatonAppchain.l2_validator_status()[:Unstaked])

      PlatonAppchain.l2_validator_is_lowBlocks(current_status) ->
        L2Validator.update_status(validator_hash,  PlatonAppchain.l2_validator_status()[:LowBlocks])

      PlatonAppchain.l2_validator_is_lowThreshold(current_status) ->
        L2Validator.update_status(validator_hash,  PlatonAppchain.l2_validator_status()[:LowThreshold])
     end
  end

  # [{validator_hash, rank},{...}]
  def update_rank(rank_tuple_list) do
     Logger.info(fn -> "update l2 validators rank: (#{inspect(rank_tuple_list)})" end,
       logger: :platon_appchain
     )
    L2Validator.update_rank(rank_tuple_list)
  end
end

