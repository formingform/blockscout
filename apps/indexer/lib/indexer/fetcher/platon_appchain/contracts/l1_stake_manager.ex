defmodule Indexer.Fetcher.PlatonAppchain.Contracts.L1StakeManager do
  alias Ethers
  use Ethers.Contract, abi_file: "config/abi/L1_StakeManager.json", default_address: Application.get_env(:indexer, Contracts)[:l1_stake_manager]

  @rpc_opts [url: Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:platon_appchain_l1_rpc], http_headers: [{"Content-Type", "application/json"}]]

  def totalStake() do
    result = StakeManager.total_stake() |> Ethers.call(rpc_opts: @rpc_opts)
    {:ok, data} = result
    data
  end
end
