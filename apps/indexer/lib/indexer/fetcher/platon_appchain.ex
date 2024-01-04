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

  # @default_update_interval :timer.seconds(3)
  @period_type [round: 1, epoch: 2]
  @default_block_interval 1000 # 1 second
  # 0：201候选验证人；1：43 出块验证人； 2：备选验证人（质押人）
  @validator_status %{Active: 0, Verifying: 1, Candidate: 2}

  def l2_round_size() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_round_size]
  end

  def l2_epoch_size() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_epoch_size]
  end

  def l2_rpc_arguments() do
    json_rpc_named_arguments(l2_rpc_url())
  end

  def l2_rpc_url() do
    json_rpc_named_arguments(PlatonAppchain.json_rpc_named_arguments(l2_rpc))
  end

  def l2_validator_contract_address() do
    Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_validator_contract_address]
  end

  def default_block_interval() do
    @default_block_interval
  end

  def period_type() do
    @period_type
  end

  def validator_status() do
    @validator_status
  end

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
    epoch = calculateL2Epoch(current_block_number, epoch_size)
    epoch * epoch_size + 1
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


  @spec prepare_events(list(), list()) :: list()
  def convert_validator_info(json_validators) do
    Enum.map(json_validators, fn json_validator ->
      [data_bytes] = decode_data(event["data"], [:bytes])

      sig = binary_part(data_bytes, 0, 32)

      l1_block_number = quantity_to_integer(event["blockNumber"])

      {from, to, l1_timestamp} =
        if Base.encode16(sig, case: :lower) == @deposit_signature do
          timestamps = get_timestamps_by_events(events, json_rpc_named_arguments)

          [_sig, _root_token, sender, receiver, _amount] =
            TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, :address, :address, {:uint, 256}])

          {sender, receiver, Map.get(timestamps, l1_block_number)}
        else
          {nil, nil, nil}
        end

      %{
        msg_id: quantity_to_integer(Enum.at(event["topics"], 1)),
        from: from,
        to: to,
        l1_transaction_hash: event["transactionHash"],
        l1_timestamp: l1_timestamp,
        l1_block_number: l1_block_number
      }
    end)
  end

  @spec import_validators(list()) :: list()
  def import_validators(validators) do
    import_data = %{l2_validators: %{params: validators}, timeout: :infinity}
    {:ok, _} = Chain.import(import_data)
    validators
  end

  @spec log_validators(list(), binary(), integer(), integer(), integer(), binary())
  def log_validators(validators, validatorType, periodType, period, block, layer) do
    periodName =
      if period_type()[:round] == periodType do
        "round"
      else
        "epoch"
      end
    Logger.info("#{length(validators)} validators (type:#{validatorType}} imported at block #{block} on #{layer}, period_type = #{periodName}, period = #{period}")
  end

end
