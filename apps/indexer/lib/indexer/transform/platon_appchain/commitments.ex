defmodule Indexer.Transform.PlatonAppchain.Commitments do
  @moduledoc """
  Helper functions for transforming data for Platon Appchain L2 Commitments.
  """

  require Logger

  alias Indexer.Fetcher.PlatonAppchain.Commitment
  alias Indexer.Helper

  @doc """
  Returns a list of L2 Commitments given a list of logs.
  """
  @spec parse(list(), list()) :: list()
  def   parse(logs, json_rpc_named_arguments) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :platon_appchan_l2_commitments_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, Commitment)[:start_block_l2]),
           l2_state_receiver = Application.get_env(:indexer, Commitment)[:l2_state_receiver],
           true <- Helper.is_address_correct?(l2_state_receiver) do
        l2_state_receiver = String.downcase(l2_state_receiver)
        event_signature = Commitment.new_commitment_event_signature()

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && String.downcase(log.first_topic) == event_signature &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == l2_state_receiver
        end)
        |> Enum.map(fn log ->
          Logger.info("L2 New commitment event message found, root: #{log.data}.")
          Commitment.event_to_commitment(
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
          Logger.error("L2StateSender contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
