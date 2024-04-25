defmodule Indexer.Fetcher.PlatonAppchain.L2ValidatorService do
  @moduledoc """
  更新l2_validator表记录.
  """
  require Logger
  use Bitwise
  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler
  alias Explorer.Chain
  alias Explorer.Chain.PlatonAppchain.L2Validator
  alias Indexer.Fetcher.PlatonAppchain


  @spec upsert_validator(Repo.t(), binary()) :: {:ok, integer()} | {:error, reason :: String.t()}
  def upsert_validator(repo, validator_hex) do
    validatorMap = L2StakeHandler.getValidator(validator_hex)
    L2Validator.upsert_validator(repo, validatorMap)
  end

  @spec update_validator(Repo.t(), binary(), integer()) :: {:ok, integer()} | {:error, reason :: String.t()}
  def update_validator(repo, validator_hex, block_no) do
    validatorMap = L2StakeHandler.getValidator(validator_hex)
    exit_info =
      cond do
        PlatonAppchain.l2_validator_is_unstaked(validatorMap.status) ->  %{exit_block: block_no, exit_desc: "Unstaked"}
        PlatonAppchain.l2_validator_is_slashed(validatorMap.status) ->  %{exit_block: block_no, exit_desc: "Slashing"}
        PlatonAppchain.l2_validator_is_duplicated(validatorMap.status) ->  %{exit_block: block_no, exit_desc: "Duplicated"}
        PlatonAppchain.l2_validator_is_lowBlocks(validatorMap.status) ->  %{exit_block: block_no, exit_desc: "LowBlocks"}
        PlatonAppchain.l2_validator_is_lowThreshold(validatorMap.status) ->  %{exit_block: block_no, exit_desc: "LowThreshold"}
        true -> %{}
      end
    Map.merge(validatorMap, exit_info)
    L2Validator.update_validator(repo, validatorMap)
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
  def update_rank_and_amount(rank_tuple_list) do
     Logger.info(fn -> "update l2 validators rank: (#{inspect(rank_tuple_list)})" end,
       logger: :platon_appchain
     )
    L2Validator.update_rank_and_amount(rank_tuple_list)
  end

  def backup_exited_validator(repo, validator_hash, status, exit_number, exit_desc) do
    L2Validator.backup_exited_validator(repo, validator_hash, status, exit_number, exit_desc)
  end

  def delete_exited_validator(repo, validator_hash) do
    L2Validator.delete_exited_validator(repo, validator_hash)
  end
end

