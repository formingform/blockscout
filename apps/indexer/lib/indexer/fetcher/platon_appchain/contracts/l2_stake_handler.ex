defmodule Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler do
  @moduledoc """
  Stake handler contract interface encapsulation
  """
  alias Ethers
  require Logger
  use Ethers.Contract, abi_file: "config/abi/L2_StakeHandler.json", default_address:  System.get_env("INDEXER_PLATON_APPCHAIN_L2_STAKE_HANDLER_CONTRACT")

  @rpc_opts [url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"), http_headers: [{"Content-Type", "application/json"}]]
  @default_size 10


  defp convertValidatorToJSON(validator) do
    data = %{
      validator_hash: elem(validator, 0),
      owner_hash: elem(validator, 1),
      stake_amount: elem(validator, 2),
      delegate_amount: elem(validator, 3),
      commission_rate: elem(validator, 4),
      status: elem(validator, 5),
      stake_epoch: elem(validator, 6)
      #stakeIndex: elem(validator, 7),
      #pubKey: Base.encode16(elem(validator, 8)),
      #blsKey: Base.encode16(elem(validator, 9))
    }
    data
  end

  defp convertDelegationToJSON(delegation) do
    data = %{
      validator_hash: elem(delegation, 0),
      delegator_hash:  elem(delegation, 1),
      delegate_amount: elem(delegation, 2)
      #delegate_amount: elem(delegation, 3),
      #delegateEpoch: elem(delegation, 4),
    }
    data
  end

  @doc """
  Query the list of all validators, Support pagination to query the list of all validators

  ## Parameters
    * `start`(bytes) - represents the starting query ID. When passing empty bytes, it defaults to starting from the first Id
    * `size`(integer) - page size

  ## Returns
    * bytes of next start
    * ValidatorInfo array for query

  ## Examples
     {"7072696F7269747956616C696461746F7200000000000000000000000000FFFFFFFFFFFFFFFFFFC46535FF00000000000000010000000000000002",
  [
   %{
     "blsKey" => "828B858EAB99526F901CE610AE3D2D9B08F2302E56A29698776D2135E94FC074C575A53E27B8A68E9A7692F3BE65965A",
     "commissionRate" => 100,
     "delegateAmount" => 10000,
     "epoch" => 1,
     "owner" => "0x70d207c1322ccb9069d3790d6768866dabff1035",
     "pubKey" => "8D84E41F83E833F622C45766E7E425CF03A225867FACB05BAF90EAF29C1BF53680988DAB4E6F058759871C91B3E6FF888AABC41DAEC4B8E0877FC8FE8FEED27F",
     "stakeAmount" => 1000000000,
     "stakeIndex" => 1,
     "status" => 0,
     "validatorAddr" => "0x70d207c1322ccb9069d3790d6768866dabff1035"
   },
   %{
     "blsKey" => "B6F85C577FF890F9737595A9E326D5539CC1CC859C879017CF25ACCEF8A96518EC9747EF621625063DC17AE95300A74F",
     "commissionRate" => 100,
     "delegateAmount" => 0,
     "epoch" => 1,
     "owner" => "0x70d207c1322ccb9069d3790d6768866dabff1035",
     "pubKey" => "5C79BF8B836BDC85FE513A64A558291E96AC2405B6B95D5CA05BB20DB9C0A1A00E12D11DD540D8685267015CE71CEF43781A75157EC6F266CC88A8FB8B5C6C17",
     "stakeAmount" => 1000000000,
     "stakeIndex" => 0,
     "status" => 0,
     "validatorAddr" => "0x1dd26dfb60b996fd5d5152af723949971d9119ee"
   }
  ]}
  """
  def getValidators(start \\ <<>>, size \\ @default_size) do
    result = get_validators(start, size) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, data} = result
    Logger.debug(fn -> "getValidators: #{inspect(data)}" end , logger: :platon_appchain)
    [nextStart | validators] = data
    validatorsJson = List.first(validators) |> Enum.map(fn validator -> convertValidatorToJSON(validator) end)
    {Base.encode16(nextStart), validatorsJson}
  end

  @doc """
  Query the list of all validators, Support pagination to query the list of all validators

  ## Parameters
    * `all`(array of validator info) - Array to save all validator info
    * `start`(bytes) - Represents the starting query ID. When passing empty bytes, it defaults to starting from the first Id, default is <<>>
    * `size`(integer) - Use this paging value to continuously obtain the loop calling interface until all data is obtained. default is 10

  ## Returns
    * All Validator Info array for query
  """
  def getAllValidators(all \\ [], start \\ <<>>, size \\ @default_size) do
    if size == 0 do
      all
    else
      {nextStart, validators} = getValidators(start, size)
      all = all ++ validators
      getAllValidators(all, Base.decode16!(nextStart), length(validators))
    end
  end

  @doc """
  Query the list of validators by addrs。Support to query the list of validators by addr of validators

  ## Parameters
    * `validators`(address[]) - addr of validators

  ## Returns
    * ValidatorInfo array for query

  ## Examples
    [
  %{
    "blsKey" => "828B858EAB99526F901CE610AE3D2D9B08F2302E56A29698776D2135E94FC074C575A53E27B8A68E9A7692F3BE65965A",
    "commissionRate" => 100,
    "delegateAmount" => 10000,
    "epoch" => 1,
    "owner" => "0x70d207c1322ccb9069d3790d6768866dabff1035",
    "pubKey" => "8D84E41F83E833F622C45766E7E425CF03A225867FACB05BAF90EAF29C1BF53680988DAB4E6F058759871C91B3E6FF888AABC41DAEC4B8E0877FC8FE8FEED27F",
    "stakeAmount" => 1000000000,
    "stakeIndex" => 1,
    "status" => 0,
    "validatorAddr" => "0x70d207c1322ccb9069d3790d6768866dabff1035"
  }
  ]
  """
  def getValidatorsWithAddr(validator_addresses) do
    result = get_validators_with_addr(validator_addresses) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, validators} = result
    validatorsJson = validators |> Enum.map(fn validator -> convertValidatorToJSON(validator) end)
    validatorsJson
  end

  @doc """
        iex> getValidator("0x97ab3d4f7f5051f127b0e9f8d10772125d94d65b")
        %{commission_rate: 80,
          delegate_amount: 0,
          owner_hash: "0x97ab3d4f7f5051f127b0e9f8d10772125d94d65b",
          stake_amount: 1000000000,
          stake_epoch: 4,
          status: 0,
          validator_hash: "0x97ab3d4f7f5051f127b0e9f8d10772125d94d65b"
        }
  """
  @spec getValidator(binary()) :: map()
  def getValidator(validator_hex) do
    result = get_validators_with_addr([validator_hex]) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, validators} = result
    convertValidatorToJSON(List.first(validators))
  end


  @doc """
  Query the list of validators for a certain period。For the convenience of expanding the list of validators with multiple period properties

  ## Parameters
    * `periodType`(integer) - represents a period of a certain type
    * `period`(integer) - represents the number of intervals

  ## Returns
    * validator address array

  ## Examples
    ["0x1dd26dfb60b996fd5d5152af723949971d9119ee","0x70d207c1322ccb9069d3790d6768866dabff1035","0x343972bf63d1062761aaaa891d2750f03cb4b2f7"]
  """
  def getValidatorAddrs(periodType, period) do
    result = get_validator_addrs(periodType, period) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, addrs} = result
    addrs
  end

  @doc """
  Query the delegation information of the delegator on these validators based on the addr list of validators

  ## Parameters
    * `validators`(address[]) - addr of validators
    * `delegator`(address) - the delegator

  ## Returns
    * DelegationInfo array for query

  ## Examples
    [%{
      "amount" => 10000,
      "delegateEpoch" => 1395,
      "delegatorAddr:" => "0x62953f9213f899f2a51680c2fbb4282a2591bfc8",
      "stakeEpoch" => 1,
      "validatorAddr" => "0x70d207c1322ccb9069d3790d6768866dabff1035"
    }]
  """
  def getDelegationsWithValidator(validators, delegator) do
    result =  get_delegations_with_validator(validators, delegator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, delegations} = result
    delegationJson = delegations |> Enum.map(fn delegation -> convertDelegationToJSON(delegation) end)
    delegationJson
  end

  @doc """
  Query how much is yet to become withdrawable for account.

  ## Parameters
    * `validator`(address) - The validator to calculate amount for
    * `delegator`(address) - The delegator to calculate amount for

  ## Returns
    * Amount not yet withdrawable

  """
  def pendingWithdrawalsOfDelegate(validator, delegator) do
    result = pending_withdrawals_of_delegate(validator, delegator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, pendingWithdrawals} = result
    pendingWithdrawals
  end

  @doc """
  Query how much is yet to become withdrawable for account.

  ## Parameters
    * `validator`(address) - The validator to calculate amount for

  ## Returns
    * Amount not yet withdrawable
  """
  def pendingWithdrawalsOfStake(validator) do
    result = pending_withdrawals_of_stake(validator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, pendingWithdrawals} = result
    pendingWithdrawals
  end

  @doc """
  Query how much can be withdrawn for account in this epoch.

  ## Parameters
    * `validator`(address) - The validator to calculate amount for
    * `delegator`(address) - The delegator to calculate amount for

  ## Returns
    * Amount withdrawable
  """
  def withdrawableOfDelegate(validator, delegator) do
    result = withdrawable_of_delegate(validator, delegator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, withdrawable} = result
    withdrawable
  end

  @doc """
  Query how much can be withdrawn for account in this epoch.

  ## Parameters
    * `validator`(address) - The account to calculate amount for

  ## Returns
    * Amount withdrawable
  """
  def withdrawableOfStake(validator) do
    result = withdrawable_of_stake(validator) |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, withdrawable} = result
    withdrawable
  end
end
