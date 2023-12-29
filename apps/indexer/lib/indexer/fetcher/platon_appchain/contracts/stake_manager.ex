defmodule Indexer.Fetcher.PlatonAppchain.Contracts.StakeManager do
  alias Ethers
  use Ethers.Contract, abi_file: "config/abi/StakeManager.json", default_address: Application.get_env(:indexer, Contracts)[:l1_stake_manager]

  def totalStake() do
    result = StakeManager.total_stake() |> Ethers.call()
    {:ok, data} = result
    data
  end
end
