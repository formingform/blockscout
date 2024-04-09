defmodule Indexer.Transform.Blocks.PlatonAppchain do
  @moduledoc """
  Handles block transforms for platon-appchain chain.
  """

  alias Indexer.Transform.PlatonAppchainBlocks

  @behaviour Blocks

  @impl Blocks
  def transform(%{number: 0} = block), do: block

  def transform(block) when is_map(block) do
    miner_address = PlatonAppchainBlocks.signer(block)
    %{block | miner_hash: miner_address}
  end
end
