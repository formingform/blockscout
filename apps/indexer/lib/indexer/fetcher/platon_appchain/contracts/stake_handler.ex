defmodule Indexer.Fetcher.PlatonAppchain.Contracts.StakeHandler do
  alias Ethers
  use Ethers.Contract, abi_file: "config/abi/StakeHandler.json", default_address: Application.get_env(:indexer, Contracts)[:l2_stake_handler]

  def getValidators(start, size) do
    {nextStart, validators} = get_validators(start, size) |> Ethers.call()
    {nextStart, validators}
  end
end
