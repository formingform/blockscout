defmodule Indexer.Transform.PlatonAppchain.L2RewardEvent do
  @moduledoc """
  Helper functions for transforming data for Platon Appchain L2RewardEvent.
  """

  require Logger

  alias Indexer.Fetcher.PlatonAppchain.L2RewardEvent
  alias Indexer.Helper

  @doc """
  Returns a list of L2RewardEvent given a list of logs.
  """
  @spec parse(list()) :: list()
  def parse(logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :platon_appchan_l2_reward_events_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, L2Event)[:start_block_l2]),
           reward_manager = Application.get_env(:indexer, L2Event)[:l2_reward_manager],
           true <- Helper.is_address_correct?(reward_manager) do
        reward_manager = String.downcase(reward_manager)
        event_signatures = L2RewardEvent.event_signatures()

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && Enum.member?(event_signatures, String.downcase(log.first_topic)) &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == reward_manager
        end)
        |> Enum.map(fn log ->
          Logger.info("L2 reward manager event message found, id: #{log.second_topic}.")
          json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
          L2RewardEvent.event_to_l2_reward_event(
            log.data,
            log.transaction_hash,
            log.block_number,
            json_rpc_named_arguments
          )
        end)
      else
        true ->
          []

        false ->
          Logger.error("L2RewardManager contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
