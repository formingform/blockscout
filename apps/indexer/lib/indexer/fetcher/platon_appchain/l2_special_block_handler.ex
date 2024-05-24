defmodule Indexer.Fetcher.PlatonAppchain.L2SpecialBlockHandler do
  @moduledoc """
  处理L2在特殊区块上的逻辑
  """

  require Logger

  alias Indexer.Fetcher.PlatonAppchain
  alias Indexer.Fetcher.PlatonAppchain.Contracts.{L2StakeHandler,L2RewardManager}


  @period_type [round: 1, epoch: 2]



  # 共识周期结束，调用底层rpc，得到此共识周期，每个验证人实际出块数，再加上配置的应该出块数，就可以算出每个验证人的出块率。
  # 问题是：如果一个验证人的出库数是0，底层会返回吗？如果不返回，那就麻烦了，还需要获取这个共识周期的验证人列表，以此列表为准，来准备出块统计数据。
  @spec l2_block_produced_statistics(list()) :: list()
  def l2_block_produced_statistics(blocks) when is_list(blocks) do
    statis =
    Enum.reduce(blocks, [], fn block, acc ->
      acc ++ get_l2_block_produced_statistic_if_round_end_block(block)
    end)
    Logger.warn(fn -> "结束查询验证人出块情况: #{inspect(statis)}" end,
      logger: :platon_appchain
    )
    statis
  end


  @spec get_l2_block_produced_statistic_if_round_end_block(map()) :: list()
  defp get_l2_block_produced_statistic_if_round_end_block(block) when is_map(block) do
    round = PlatonAppchain.calculateL2Round(block.number)
    blocks_of_validator_list = L2StakeHandler.get_blocks_of_validators_from_chain(@period_type[:round], round)

    get_l2_block_produced_statistic(blocks_of_validator_list,  round)

#    if PlatonAppchain.is_round_end_block(block.number) == true do
#      #epoch = PlatonAppchain.calculateL2Epoch(block.number)
#      round = PlatonAppchain.calculateL2Round(block.number)
#      blocks_of_validator_list = L2StakeHandler.get_blocks_of_validators(@period_type[:round], round)
#
#      get_l2_block_produced_statistic(blocks_of_validator_list,  round)
#    else
#      []
#    end
  end

  # 返回list[map()]
  defp get_l2_block_produced_statistic(blocks_of_validator_list, round) do
    blocks_of_validator_list
    |> Enum.map(fn item ->
      %{
        round: round,
        validator_hash: item.validator_hash,
        should_blocks: 10, #todo: 做成env的变量
        actual_blocks: item.actual_blocks,
      }
    end)
  end
end
