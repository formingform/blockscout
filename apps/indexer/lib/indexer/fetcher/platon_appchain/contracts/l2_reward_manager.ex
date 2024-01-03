defmodule Indexer.Fetcher.PlatonAppchain.Contracts.L2RewardManager do
  @moduledoc """
  L2 reward manager contract interface encapsulation
  """
  alias Ethers
  use Ethers.Contract, abi_file: "config/abi/L2_RewardManager.json", default_address: Application.get_env(:indexer, Contracts)[:l2_reward_manager]

  @rpc_opts [url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"), http_headers: [{"Content-Type", "application/json"}]]

  @doc """
  Query the total reward (epoch reward and blocks reward) paid for the given epoch

  ## Parameters
    * `epochId`(integer) - epoch id

  ## Returns
    * the total reward (epoch reward and blocks reward) paid for the given epoch
  """
  def paidRewardPerEpoch(epochId) do
    result = paid_reward_per_epoch(epochId) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, paidReward} = result
    paidReward
  end

  @doc """
  Query the pending reward for the given account(validator)

  ## Parameters
    * `validator`(address) - addr of validator

  ## Returns
    * Pending reward for the given account(validator)
  """
  def pendingValidatorRewards(validator) do
    result = pending_validator_rewards(validator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, pendingRewards} = result
    pendingRewards
  end

  @doc """
  Query the pending reward of delegator for the given account(validator)

  ## Parameters
    * `validator`(address) - addr of validators
    * `delegator`(address) - addr of delegator

  ## Returns
    * Pending reward of delegator for the given account(validator)
  """
  def pendingDelegatorRewards(validator, delegator) do
    result = pending_delegator_rewards(validator, delegator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, pendingRewards} = result
    pendingRewards
  end
end
