defmodule Indexer.Fetcher.PlatonAppchain.Contracts.L1StakeManager do
  alias Ethers
  use Ethers.Contract, abi_file: "config/abi/L1_StakeManager.json", default_address: Application.compile_env(:indexer, __MODULE__)[:l1_stake_manager]

  @rpc_opts [url: Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:platon_appchain_l1_rpc], http_headers: [{"Content-Type", "application/json"}]]

  @doc """
  Query the total amount stake for all child chains

  ## Returns
    * Total amount stake for all child chains
  """
  def totalStake() do
    result = total_stake() |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, data} = result
    data
  end

  @doc """
  Query the total amount delegation for all child chains

  ## Returns
    * Total amount delegation for all child chains
  """
  def totalDelegation() do
    result = total_delegation() |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, amount} = result
    amount
  end

  @doc """
  Query the min amount to delegate a validator

  ## Returns
    * The min amount to delegate a validator
  """
  def minDelegate() do
    result = min_delegate() |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, amount} = result
    amount
  end

  @doc """
  Query the min amount to stake a validator

  ## Returns
    * The min amount to stake a validator
  """
  def minStake() do
    result = min_stake() |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, amount} = result
    amount
  end

  @doc """
  Query the amount of stake a validator can withdraw

  ## Parameters
    * `validator`(address) - addr of validators

  ## Returns
    * Amount of stake a validator can withdraw
  """
  def withdrawableStake(validator) do
    result = withdrawable_stake(validator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, amount} = result
    amount
  end

  @doc """
  Query the amount of delegate a validator can withdraw

  ## Parameters
    * `validator`(address) - addr of validators

  ## Returns
    * Amount of delegate a validator can withdraw
  """
  def withdrawableDelegation(validator) do
    result = withdrawable_delegation(validator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, amount} = result
    amount
  end
end
