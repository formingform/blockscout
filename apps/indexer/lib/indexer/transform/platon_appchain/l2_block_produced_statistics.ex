defmodule Indexer.Transform.PlatonAppchain.L2BlockProducedStatistics do
  @moduledoc """
  Helper functions for transforming data for Platon Appchain L2BlockProducedStatistics.
  """

  require Logger

  alias Indexer.Fetcher.PlatonAppchain.L2BlockProducedStatistic
  alias Indexer.Helper

  @doc """
  Returns a list of L2Events given a list of logs.
  """
  @spec parse(list()) :: list()
  def parse(blocks) do
    Logger.info(fn -> "L2BlockProducedStatistics parse blocks>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>: #{inspect(blocks)}" end ,
      logger: :platon_appchain
    )
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :platon_appchan_l2_block_produced_statistics)

    items =
      blocks
      |> Enum.map(fn block -> fetch_block_produced_statistic(block) end)
#    items =
#      with false <- is_nil(Application.get_env(:indexer, L2Event)[:start_block_l2]),
#           state_sender = Application.get_env(:indexer, L2Event)[:l2_state_sender],
#           true <- Helper.is_address_correct?(state_sender) do
#        state_sender = String.downcase(state_sender)
#        l2_state_synced_event_signature = L2Event.l2_state_synced_event_signature()
#
#        logs
#        |> Enum.filter(fn log ->
#          !is_nil(log.first_topic) && String.downcase(log.first_topic) == l2_state_synced_event_signature &&
#            String.downcase(Helper.address_hash_to_string(log.address_hash)) == state_sender
#        end)
#        |> Enum.map(fn log ->
#          Logger.info("L2 state synced event message found, id: #{log.second_topic}.")
#          json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
#          L2Event.event_to_l2_event(
#            log.second_topic,
#            log.data,
#            log.transaction_hash,
#            log.block_number,
#            json_rpc_named_arguments
#          )
#        end)
#      else
#        true ->
#          []
#
#        false ->
#          Logger.error("L2StateSender contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
#          []
#      end

    Logger.reset_metadata(prev_metadata)

    items
  end

  def fetch_block_produced_statistic(block) do
    Logger.info(fn -> "block>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>fetch_block_produced_statistic" end ,
      logger: :platon_appchain
    )
    if Map.has_key?(block, :round_validator) do
      round_validator_arr = Map.get(block, :round_validator)

      block_produced_statistics = Enum.map(round_validator_arr, fn address ->
        %{
          epoch: 1,
          validator_hash: address,
          should_blocks: 10,
          actual_blocks: 0,
          block_rate: 100
        }
      end)

    else
      []
    end
  end
end
