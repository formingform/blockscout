defmodule Indexer.Fetcher.PlatonAppchain.L2SpecialBlockHandler do
  @moduledoc """
  处理L2在特殊区块上的逻辑
  """

  require Logger

  alias Indexer.Fetcher.PlatonAppchain
  alias Indexer.Fetcher.PlatonAppchain.Contracts.{L2StakeHandler,L2RewardManager}


  @period_type [round: 1, epoch: 2]


  def inspect_block(block_number) do
    cond do
      PlatonAppchain.is_round_begin_block(block_number) == true ->
        epoch = PlatonAppchain.calculateL2Epoch(block_number)
        round = PlatonAppchain.calculateL2Round(block_number)
        block_producer_hash_list = L2StakeHandler.getValidatorAddrs(@period_type[:round], round)
#        l2_block_produced_statistics = get_init_L2BlockProducedStatistics(block_producer_hash_list, epoch, round)
#        %{init_statistics: l2_block_produced_statistics}
      PlatonAppchain.is_round_end_block(block_number) == true ->
        epoch = PlatonAppchain.calculateL2Epoch(block_number)
        round = PlatonAppchain.calculateL2Round(block_number)
        # todo：还需要和底层协商，开发并开放此接口。
        block_producer_hash_list = L2StakeHandler.getBlockProducedInfo(@period_type[:round], round)
#        l2_block_produced_statistics = get_updated_L2BlockProducedStatistics(block_producer_hash_list, epoch, round)
#        %{update_statistics: l2_block_produced_statistics}
      true -> %{}
    end
  end

  # 共识周期结束，调用底层rpc，得到此共识周期，每个验证人实际出块数，再加上配置的应该出块数，就可以算出每个验证人的出块率。
  # 问题是：如果一个验证人的出库数是0，底层会返回吗？如果不返回，那就麻烦了，还需要获取这个共识周期的验证人列表，以此列表为准，来准备出块统计数据。
  @spec l2_block_produced_statistics(list()) :: list()
  def l2_block_produced_statistics(blocks) when is_list(blocks) do
    Enum.reduce(blocks, [], fn block, acc ->
      acc ++ get_block_produced_info_if_round_end_block(block)
    end)
  end

  defp get_block_produced_info_if_round_end_block(block) when is_map(block) do
    if PlatonAppchain.is_round_end_block(block.number) == true do
      epoch = PlatonAppchain.calculateL2Epoch(block.number)
      round = PlatonAppchain.calculateL2Round(block.number)
      # todo：还需要和底层协商，开发并开放此接口。
      block_producer_hash_list = L2StakeHandler.getBlockProducedInfo(@period_type[:round], round)
      convert_to_L2BlockProducedStatistics(block_producer_hash_list, epoch, round)
      %{}
    else
      %{}
    end
  end

  defp convert_to_L2BlockProducedStatistics(block_produced_info_list, epoch, round) do
    block_produced_info_list
    |> Enum.map(fn info ->
      %{
        epoch: info.epoch,
        round: info.round,
        validator_hash: info.validator_hash,
        should_blocks: 10, #todo: 做成env的变量
        actual_blocks: info.actual_blocks,
      }
    end)
  end
end
