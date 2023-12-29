defmodule Indexer.Fetcher.PlatonAppchain do
  @moduledoc """
  Contains common functions for PlatonAppchain.* fetchers.
  """

  require Logger

  import Ecto.Query

  import EthereumJSONRPC,
         only: [fetch_block_number_by_tag: 2, json_rpc: 2, integer_to_quantity: 1, quantity_to_integer: 1, request: 1]

  import Explorer.Helper, only: [parse_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias Explorer.Chain.Events.Publisher
  alias Explorer.{Chain, Repo}
  alias Indexer.{BoundQueue, Helper}

  def calculateL2Round(current_block_number, round_size) do
    if rem(current_block_number,round_size)==0 do
      div(current_block_number, round_size)
    else
      div(current_block_number, round_size) + 1
    end
  end

  def calculateNextL2RoundBlockNumber(current_block_number, round_size) do
    next_round = calculateL2Round(current_block_number, round_size)
    next_round * round_size + 1
  end

  def calculateL2Epoch(current_block_number, epoch_size) do
    if rem(current_block_number,epoch_size)==0 do
      div(current_block_number, epoch_size)
    else
      div(current_block_number, epoch_size) + 1
    end
  end

  def calculateNextL2EpochBlockNumber(current_block_number, epoch_size) do
    next_epoch = calculateL2Epoch(current_block_number, epoch_size)
    next_epoch * epoch_size + 1
  end


  # 返回 JSON rpc 请求时的参数
  def json_rpc_named_arguments(rpc_url) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: rpc_url,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end


  def get_latest_block_number(json_rpc_named_arguments) do
    get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
  end


  @spec get_block_number_by_tag(binary(), list(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_block_number_by_tag(tag, json_rpc_named_arguments, retries \\ 3) do
    error_message = &"Cannot fetch #{tag} block number. Error: #{inspect(&1)}"
    repeated_call(&fetch_block_number_by_tag/2, [tag, json_rpc_named_arguments], error_message, retries)
  end

  defp repeated_call(func, args, error_message, retries_left) do
    case apply(func, args) do
      {:ok, _} = res ->
        res

      {:error, message} = err ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          Logger.error(error_message.(message))
          err
        else
          Logger.error("#{error_message.(message)} Retrying...")
          :timer.sleep(3000)
          repeated_call(func, args, error_message, retries_left)
        end
    end
  end
end
