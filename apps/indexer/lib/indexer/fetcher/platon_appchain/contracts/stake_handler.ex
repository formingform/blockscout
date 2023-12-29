defmodule Indexer.Fetcher.PlatonAppchain.Contracts.StakeHandler do
  alias Ethers
  use Ethers.Contract, abi_file: "config/abi/StakeHandler.json", default_address: Application.get_env(:indexer, Contracts)[:l2_stake_handler]

  def convertValidatorToJSON(validator) do
    data = %{
      "validatorAddr" => elem(validator, 0),
      "owner" => elem(validator, 1),
      "stakeAmount" => elem(validator, 2),
      "delegateAmount"=> elem(validator, 3),
      "commissionRate"=> elem(validator, 4),
      "status"=> elem(validator, 5),
      "epoch"=> elem(validator, 6),
      "stakeIndex"=> elem(validator, 7),
      "pubKey"=> Base.encode16(elem(validator, 8)),
      "blsKey"=> Base.encode16(elem(validator, 9))
    }
    data
  end

  def getValidators(start, size) do
    result = get_validators(start, size) |> Ethers.call()
    {:ok, data} = result
    [nextStart | validators] = data
    validatorsJson = List.first(validators) |> Enum.map(fn validator -> convertValidatorToJSON(validator) end)
    {Base.encode16(nextStart), validatorsJson}
  end
end
