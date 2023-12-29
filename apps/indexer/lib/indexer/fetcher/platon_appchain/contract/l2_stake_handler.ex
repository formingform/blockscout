defmodule Indexer.Fetcher.PlatonAppchain.Contract.L2StakeHandler do
  use Ethers.Contract,
      abi_file: "priv/contract_abi/platon_appchain/l2_contracts/StakeHandler.json",
      default_address: "0x1000000000000000000000000000000000000005"

  # You can also add more code here in this module if you wish
end
