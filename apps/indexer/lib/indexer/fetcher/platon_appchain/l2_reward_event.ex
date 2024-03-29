defmodule Indexer.Fetcher.PlatonAppchain.L2RewardEvent do
  @moduledoc """
  Fills platon appchain l2_delegator DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2]
  import Indexer.Fetcher.PlatonAppchain, only: [fill_block_range: 5, get_block_number_by_tag: 3]

  alias ABI.TypeDecoder
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.PlatonAppchain.L2Delegator
  alias Indexer.Fetcher.PlatonAppchain

  @fetcher_name :platon_appchain_l2_reward_event

  @l2_withdraw_validator_rewards_event "0xedaf3c471ebd67d60c29efe34b639ede7d6a1d92eaeb3f503e784971e67118a5"

  @l2_withdraw_delegator_rewards_event "7a8dc26796a1e50e6e190b70259f58f6a4edd5b22280ceecc82b687b8e982869"

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(args) do
    Logger.metadata(fetcher: @fetcher_name)

    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    env = Application.get_all_env(:indexer)[__MODULE__]

    PlatonAppchain.init_l2(
      L2Event,
      env,
      self(),
      env[:l2_reward_manager],
      "L2RewardManager",
      "l2_events",
      "L2Events",
      json_rpc_named_arguments
    )
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          start_block_l2: start_block_l2,
          contract_address: contract_address,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do

    Process.send(self(), :find_new_events, [])
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        :find_new_events,
        %{
          start_block: start_block,
          safe_block: safe_block,
          safe_block_is_latest: safe_block_is_latest,
          contract_address: contract_address,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    # find and fill all events between start_block and "safe" block
    # the "safe" block can be "latest" (when safe_block_is_latest == true)
    fill_block_range(
      start_block,
      safe_block,
      {__MODULE__, L2RewardEvent},
      contract_address,
      json_rpc_named_arguments
    )

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = PlatonAppchain.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      fill_block_range(
        safe_block + 1,
        latest_block,
        {__MODULE__, L2RewardEvent},
        contract_address,
        json_rpc_named_arguments
      )
    end

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @spec remove(non_neg_integer()) :: no_return()
  def remove(starting_block) do
    Repo.delete_all(from(w in L2Event, where: w.block_number >= ^starting_block))
  end

  @spec event_to_l2_reward_event( binary(), binary(), binary(), list()) :: map()
  def event_to_l2_reward_event(data, l2_transaction_hash, l2_block_number, json_rpc_named_arguments) do
    Logger.debug(fn -> "convert event to l2_event, log.data: #{inspect(data)}" end, logger: :platon_appchain)

    [data_bytes] = decode_data(data, [:bytes])

    Logger.debug(fn -> "decode data result: #{inspect(data_bytes)}" end, logger: :platon_appchain)

    sig = binary_part(data_bytes, 0, 32)

    {:ok, l2_block_timestamp} = PlatonAppchain.get_block_timestamp_by_number(l2_block_number, json_rpc_named_arguments, 100_000_000)
    case Base.encode16(sig, case: :lower) do
      @l2_withdraw_delegator_rewards_event ->
        # {WITHDRAW_DELEGATOR_REWARD_SIG, validator, amount, delegator}
        [_sig, validator, amount, delegator] = TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, {:uint, 256}, :address])
        Logger.debug(fn -> "withdraw delegator rewards event: validator-#{inspect(validator)}, delegator-#{inspect(delegator)}, amount-#{amount}" end, logger: :platon_appchain)
        L2Delegator.update_withdrawn_delegator_reward(delegator, validator, amount)
        %{
          "validator": validator,
          "amount": amount,
          "caller": delegator
        }

      @l2_withdraw_validator_rewards_event ->
        # {WITHDRAW_VALIDATOR_REWARD_SIG, validator, amount, caller}
        [_sig, validator, amount, caller] = TypeDecoder.decode_raw(data_bytes, [{:bytes, 32}, :address, {:uint, 256}, :address])
        Logger.debug(fn -> "withdraw validator rewards event: validator-#{inspect(validator)}, caller-#{inspect(caller)}, amount-#{amount}" end, logger: :platon_appchain)
        # todo 是否需要更新validator表对应的字段
        %{
          "validator": validator,
          "amount": amount,
          "caller": caller
        }
      _ ->
        %{}
    end
  end

  @spec find_and_save_entities(boolean(), binary(), non_neg_integer(), non_neg_integer(), list()) :: non_neg_integer()
  def find_and_save_entities(
        scan_db,
        l2_reward_manager,
        block_start,
        block_end,
        json_rpc_named_arguments
      ) do
    l2_reward_events =
      if scan_db do
        query =
          from(log in Log,
            select: {log.data, log.transaction_hash, log.block_number},
            where:
              log.first_topic == @l2_withdraw_validator_rewards_event or log.first_topic == @l2_withdraw_delegator_rewards_event and log.address_hash == ^l2_reward_manager and
              log.block_number >= ^block_start and log.block_number <= ^block_end
          )

        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {data, l2_transaction_hash, l2_block_number} ->
          event_to_l2_reward_event(data, l2_transaction_hash, l2_block_number, json_rpc_named_arguments)
        end)
      else
        {:ok, result} =
          PlatonAppchain.get_logs(
            block_start,
            block_end,
            l2_reward_manager,
            event_signatures(),
            json_rpc_named_arguments,
            100_000_000
          )
        Enum.map(result, fn event ->
          event_to_l2_reward_event(
            event["data"],
            event["transactionHash"],
            event["blockNumber"],  # 这里event["blockNumber"]获取的block_number是16进制的
            json_rpc_named_arguments
          )
        end)
      end
    # 过滤掉返回为空的events
    filtered_events = Enum.reject(l2_reward_events, &Enum.empty?/1)
    if Enum.count(filtered_events) > 0 do
      Logger.debug(fn -> "to import l2 reward events:(#{inspect(filtered_events)})" end , logger: :platon_appchain)
    end
    Enum.count(filtered_events)
  end
  @spec event_signatures() :: list()
  def event_signatures() do
    [ @l2_withdraw_delegator_rewards_event,
      @l2_withdraw_validator_rewards_event]
  end
end
