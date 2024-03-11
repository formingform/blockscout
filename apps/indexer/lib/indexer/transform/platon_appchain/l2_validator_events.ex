defmodule Indexer.Transform.PlatonAppchain.L2ValidatorEvents do
  @moduledoc """
  Helper functions for transforming data for Platon Appchain l2 validator events.
  """

  require Logger

  alias Indexer.Fetcher.PlatonAppchain.L2ValidatorEvent
  alias Indexer.Helper

  @doc """
  Returns a list of l2 executes given a list of logs.
  """
  @spec parse(list(), list()) :: list()
  def parse(logs, json_rpc_named_arguments) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :platon_appchain_l2_validator_events_realtime)

    items =
      with false <-
             is_nil(Application.get_env(:indexer, L2ValidatorEvent)[:start_block_l2]),
           l2_stake_handler = Application.get_env(:indexer, L2ValidatorEvent)[:l2_stake_handler],
           true <- Helper.is_address_correct?(l2_stake_handler) do
        l2_stake_handler = String.downcase(l2_stake_handler)
        event_signatures = L2ValidatorEvent.event_signatures()

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && Enum.member?(event_signatures, String.downcase(log.first_topic)) &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == l2_stake_handler
        end)
        |> Enum.reduce([], fn log, acc ->
          Logger.info("L2 (Stake Event) message found, validator: #{log.second_topic}.")

          acc ++ L2ValidatorEvent.event_to_l2_validator_events(
            log.index,
            log.first_topic,
            log.second_topic,
            log.third_topic,
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
          Logger.error("L2 StakeHandler contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
