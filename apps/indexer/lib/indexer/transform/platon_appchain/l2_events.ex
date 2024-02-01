defmodule Indexer.Transform.PlatonAppchain.L2Events do
  @moduledoc """
  Helper functions for transforming data for Platon Appchain L2Events.
  """

  require Logger

  alias Indexer.Fetcher.PlatonAppchain.L2Event
  alias Indexer.Helper

  @doc """
  Returns a list of L2Events given a list of logs.
  """
  @spec parse(list()) :: list()
  def parse(logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :platon_appchan_l2_events_realtime)
    IO.inspect("******************: #{Application.get_env(:indexer, L2Event)[:l2_state_sender]}")
    IO.inspect("******************: #{Application.get_env(:indexer, L2Event)[:start_block_l2]}")

    items =
      with false <- is_nil(Application.get_env(:indexer, L2Event)[:start_block_l2]),
           state_sender = Application.get_env(:indexer, L2Event)[:l2_state_sender],
           true <- Helper.is_address_correct?(state_sender) do
        state_sender = String.downcase(state_sender)
        l2_state_synced_event_signature = L2Event.l2_state_synced_event_signature()

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && String.downcase(log.first_topic) == l2_state_synced_event_signature &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == state_sender
        end)
        |> Enum.map(fn log ->
          Logger.info("L2 state synced event message found, id: #{log.second_topic}.")
          json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
          L2Event.event_to_l2_event(
            log.second_topic,
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
          Logger.error("L2StateSender contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
