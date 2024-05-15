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
    %{block | miner_hash: miner_address}

#    # 如果当前区块是共识轮的第一个区块，则调function getValidatorAddrs(uint8 periodType, uint256 period) external view returns (address[] memory); 获取当前轮的理论验证人
#    # 如果想取共识周期的验证人列表periodType要怎么传值?????
#    l2_round_size = PlatonAppchain.l2_round_size()
#
#    if rem(block.number,l2_round_size) == 1 do
#      Logger.info(fn -> "is round start block<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>: #{inspect(block.number)}" end ,
#        logger: :platon_appchain
#      )
#      periodType = 1
#      current_round = div(block.number, l2_round_size) + 1
#      current_validator_arr = L2StakeHandler.getValidatorAddrs(periodType,current_round)
#      Logger.info(fn -> "current_validator_arr<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>: #{inspect(current_validator_arr)}" end ,
#        logger: :platon_appchain
#      )
#      new_block = Map.put_new(block, :round_validator, current_validator_arr)
#
#      Logger.info(fn -> "block>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>: #{inspect(new_block)}" end ,
#        logger: :platon_appchain
#      )
#      new_block
#    else
#      block
#    end

  end
end
