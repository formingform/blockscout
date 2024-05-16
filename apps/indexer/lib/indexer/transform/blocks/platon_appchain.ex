defmodule Indexer.Transform.Blocks.PlatonAppchain do
  @moduledoc """
  Handles block transforms for platon-appchain chain.
  """

  require Logger

  alias Indexer.Transform.PlatonAppchainBlocks
  alias Indexer.Fetcher.PlatonAppchain
  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler

  @behaviour Blocks

  @impl Blocks
  def transform(%{number: 0} = block), do: block

  def transform(block) when is_map(block) do
    miner_address = PlatonAppchainBlocks.signer(block)
    %{block | miner_hash: miner_address, block_reward: PlatonAppchain.l2_block_reward()}
  end
end
