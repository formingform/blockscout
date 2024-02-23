defmodule Indexer.Fetcher.PlatonAppchain.L2ValidatorEvent do
  @moduledoc """
  监听L2上的业务日志，记录到L2_validator_event
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1, integer_to_quantity: 1]
  import Explorer.Helper, only: [decode_data: 2]
  import Indexer.Fetcher.PlatonAppchain, only: [fill_block_range: 5, get_block_number_by_tag: 3]

  alias ABI.TypeDecoder
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Log
  alias Explorer.Chain.PlatonAppchain.L2ValidatorEvent
  alias Indexer.Fetcher.PlatonAppchain
  alias Indexer.Fetcher.PlatonAppchain.L2ValidatorService

  @fetcher_name :platon_appchain_l2_validator_event

  # refer to: \PlatONnetwork\AppChain-SDK\x\staking\contracts\sol\IStakeHandler.sol

  # 32-byte signature of the event ValidatorRegistered(address indexed validator, address owner, uint256 commissionRate, bytes pubKey, bytes blsKey)
  @l2_biz_event_ValidatorRegistered "0x187ca16644688a051ac4943c9c5856f212b6e653b4e2c02b5ce0fb79907cc1ec"
  @l2_biz_event_StakeAdded "0x7c717985ac273e663b7f3050f5b15a4388ff6ed952338954f650e2093e13937f"
  @l2_biz_event_DelegationAdded "0x52467f14b857734001c77e6f125dac41b45798837c9fc9adfe3a5b394c77a0e9"
  @l2_biz_event_UnStaked "0x79d3df6837cc49ff0e09fd3258e6e45594e0703445bb06825e9d75156eaee8f0"
  @l2_biz_event_UnDelegated "0x33f37c4c8173c3f236d2b74f93b425280ea2f7f2924a98ec73744fbc04f9ee35"
  @l2_biz_event_Slashed "0xd2f2b50d0c108d01a95cfb6ee87668e30a20c08be7facf9f28146548f82a8ab7"
  @l2_biz_event_UpdateValidatorStatus "0x85ff997a3e90354ca8883205ac49293eed56e342aa01c0223bd70027118943c2"


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
      L2ValidatorEvent,
      env,
      self(),
      env[:l2_stake_handler],
      "L2StakeHandler",
      "l2_validator_events",
      "L2ValidatorEvents",
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
    PlatonAppchain.fill_block_range_no_event_id(
      start_block,
      safe_block,
      {__MODULE__, L2ValidatorEvent},
      contract_address,
      json_rpc_named_arguments
    )

    if not safe_block_is_latest do
      # find and fill all events between "safe" and "latest" block (excluding "safe")
      {:ok, latest_block} = PlatonAppchain.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      PlatonAppchain.fill_block_range_no_event_id(
        safe_block + 1,
        latest_block,
        {__MODULE__, L2ValidatorEvent},
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

  #todo: 这个在有分叉的时候，需要删除短枝上的数据
  @spec remove(non_neg_integer()) :: no_return()
  def remove(starting_block) do
    Repo.delete_all(from(w in L2ValidatorEvent, where: w.block_number >= ^starting_block))
  end

  # 返回一个map的list(处理slash需要返回一个list)
  # 返回一个map
  @spec event_to_l2_validator_event(non_neg_integer(), binary(), binary(), binary(), binary(), binary(), non_neg_integer(), list()) :: map()
  def event_to_l2_validator_event(log_index, first_topic, second_topic, third_topic, data, l2_transaction_hash, l2_block_number, json_rpc_named_arguments) do
    Logger.debug(fn -> "convert event to l2_validator_event, log.data: #{inspect(data)}" end, logger: :platon_appchain)
    Logger.debug(fn -> "convert event to l2_validator_event, log.index: #{inspect(log_index)}" end, logger: :platon_appchain)
    data_bytes =
      case data do
        %Explorer.Chain.Data{} ->
          %Explorer.Chain.Data{bytes: data_byte} = data
          data_byte
        _ ->
          decode_data(data, [:bytes])
      end


    {:ok, timestamp}  = PlatonAppchain.get_block_timestamp_by_number(l2_block_number, json_rpc_named_arguments, 100_000_000)
    block_number = quantity_to_integer(l2_block_number)

    #{logIndex, validator_hash, block_number, transaction_hash, action_type, action_desc, amount, block_timestamp} =
      case first_topic do
        @l2_biz_event_ValidatorRegistered ->
          Logger.error(fn -> "l2_validator_events  ==============1 l2_validator_events process l2_biz_event_ValidatorRegistered==========================)" end)
          [owner, commission_rate, _pubKey, _blsKey] = TypeDecoder.decode_raw(data_bytes, [:address, {:uint, 256}, {:bytes, 64},  {:bytes, 48}])
          # 增加L2_validator记录
          validator_hash = %Explorer.Chain.Hash{bytes: Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed), byte_count: 20}


          # 溢出异常
          # validator_hash = integer_to_quantity(quantity_to_integer(second_topic))
          L2ValidatorService.add_new_validator(validator_hash)
          %{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            transaction_hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:ValidatorRegistered],
            action_desc: "owner: #{owner}, commission_rate: #{commission_rate}",
            amount: 0,
            block_timestamp: timestamp
          }

        @l2_biz_event_StakeAdded ->
          Logger.error(fn -> "l2_validator_events  ==============2 l2_validator_events process l2_biz_event_StakeAdded==========================)" end)
          [amount] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
          # 更新L2_validator记录，增加质押金额
          validator_hash = %Explorer.Chain.Hash{bytes: Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed), byte_count: 20}

          # 溢出异常
          # validator_hash = integer_to_quantity(quantity_to_integer(second_topic))
          L2ValidatorService.increase_stake(validator_hash, amount)
          %{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:StakeAdded],
            action_desc: nil,
            amount: amount,
            block_timestamp: Timex.from_unix(timestamp)
          }

        @l2_biz_event_DelegationAdded ->
          Logger.error(fn -> "l2_validator_events  ==============3 l2_validator_events process l2_biz_event_DelegationAdded==========================)" end)

          [amount] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
          # 更新L2_validator记录，增加委托金额

          delegator_hash = %Explorer.Chain.Hash{bytes: Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed), byte_count: 20}
          validator_hash = %Explorer.Chain.Hash{bytes: Base.decode16!(String.slice(third_topic, -40..-1), case: :mixed), byte_count: 20}

          L2ValidatorService.increase_delegation(validator_hash, amount)
          %{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:DelegationAdded],
            action_desc: "delegator: #{delegator_hash}",
            amount: 0,
            block_timestamp: timestamp
          }

        @l2_biz_event_UnStaked ->

          [amount] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
          validator_hash = %Explorer.Chain.Hash{bytes: Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed), byte_count: 20}

          # 更新L2_validator记录，减少质押
          L2ValidatorService.decrease_stake(validator_hash, amount)

          %{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            transaction_hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:UnStaked],
            action_desc: nil,
            amount: amount,
            block_timestamp: timestamp
          }

        @l2_biz_event_UnDelegated ->

          [amount] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
          delegator_hash = %Explorer.Chain.Hash{bytes: Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed), byte_count: 20}
          validator_hash = %Explorer.Chain.Hash{bytes: Base.decode16!(String.slice(third_topic, -40..-1), case: :mixed), byte_count: 20}


          # 更新L2_validator记录，减少委托
          L2ValidatorService.decrease_delegation(validator_hash, amount)

          %{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            transaction_hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:UnDelegated],
            action_desc: "delegator: #{delegator_hash}",
            amount: amount,
            block_timestamp: timestamp
          }

        @l2_biz_event_Slashed ->

         action_type = PlatonAppchain.l2_validator_event_action_type()[:Slashed]

         [validators, amounts] = TypeDecoder.decode_raw(data_bytes, [{:array, :address}, {:array, {:uint, 256}}])
         firstValidator = Enum.at(validators, 0)
         firstAmount = Enum.at(amounts, 0)
          %{
            log_index: log_index,
            validator_hash: firstValidator,
            block_number: block_number,
            transaction_hash: l2_transaction_hash,
            action_type: action_type,
            action_desc: nil,
            amount: firstAmount,
            block_timestamp: timestamp
         }
#         #把两个列表，变成一个元组的列表
#         zipped = Enum.zip(validators, amounts)
#
#         # 更新L2_validator记录，惩罚节点
#         L2ValidatorService.slash(zipped)
#
#         Enum.map(zipped, fn {validator, amount} ->
#           %{
#              log_index: log_index,
#              validator_hash: validator,
#              block_number: block_number,
#              transaction_hash: l2_transaction_hash,
#              action_type: action_type,
#              action_desc: nil,
#              amount: amount,
#              block_timestamp: timestamp
#           }
#         end)

       @l2_biz_event_UpdateValidatorStatus->
         [current_status] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
         # 更新L2_validator记录，惩罚节点
         L2ValidatorService.update_validator_status(second_topic, current_status, block_number)
         %{}
        _ ->
         %{}
      end
  end

  @spec find_and_save_entities(boolean(), binary(), non_neg_integer(), non_neg_integer(), list()) :: non_neg_integer()
  def find_and_save_entities(
        scan_db,
        l2_stake_handler,
        block_start,
        block_end,
        json_rpc_named_arguments
      ) do

#      Logger.info("to get l2 validator events, scan_db: #{scan_db}",
#        logger: :platon_appchain
#      )

    l2_validator_events =
      if scan_db do
        query =
          from(log in Log,
            select: {log.index, log.first_topic, log.second_topic, log.third_topic, log.data, log.transaction_hash, log.block_number},
            where:
              (log.first_topic == @l2_biz_event_ValidatorRegistered or log.first_topic == @l2_biz_event_StakeAdded or log.first_topic == @l2_biz_event_DelegationAdded or log.first_topic == @l2_biz_event_UnStaked or log.first_topic == @l2_biz_event_UnDelegated or log.first_topic == @l2_biz_event_Slashed)
              and log.address_hash == ^l2_stake_handler and
              log.block_number >= ^block_start and log.block_number <= ^block_end
          )
        query
        |> Repo.all(timeout: :infinity)
        |> Enum.map(fn {index, first_topic, second_topic, third_topic, data, l2_transaction_hash, l2_block_number} ->

          event_to_l2_validator_event(index, first_topic, second_topic, third_topic, data, l2_transaction_hash, l2_block_number,json_rpc_named_arguments)
        end)
      else
        {:ok, result} = PlatonAppchain.get_logs_by_topics(
            block_start,
            block_end,
            l2_stake_handler,
            event_signatures(),
            json_rpc_named_arguments,
            100_000_000
          )

         Enum.map(result, fn event ->
            event_to_l2_validator_event(
              event["logIndex"],
              Enum.at(event["topics"], 0),
              Enum.at(event["topics"], 1),
              Enum.at(event["topics"], 2),
              event["data"],
              event["transactionHash"],
              event["blockNumber"],
              json_rpc_named_arguments
            )
          end)
      end

#      Logger.info("to import l2 validator events, count:::::",
#        logger: :platon_appchain
#      )

    # 过滤掉返回为空的events
    filtered_events = Enum.reject(l2_validator_events, &Enum.empty?/1)

    Logger.error(fn -> "l2_validator_events  ==============begin import to l2_validator_events==========================)" end)
    Logger.error(fn -> "begin import to l2_validator_events, log.data: #{inspect(filtered_events)}" end, logger: :platon_appchain)

    if Enum.count(filtered_events)> 0 do
      {:ok, _} =
        Chain.import(%{
          l2_validator_events: %{params: filtered_events},
          timeout: :infinity
        })
#      case Chain.import(%{
#          l2_validator_events: %{params: l2_validator_events},
#          timeout: :infinity
#        }) do
#          {:ok, _} ->
#            Logger.debug("success to import l2 validator events",
#              logger: :platon_appchain
#            )
#          {:error, reason} ->
#            Logger.error(fn -> "failed to import l2 validator events with reason (#{inspect(reason)}). Restarting" end ,
#              logger: :platon_appchain
#            )
#        end
      end

    Enum.count(l2_validator_events)
  end

  @spec event_signatures() :: list()
  def event_signatures() do
    [ @l2_biz_event_ValidatorRegistered,
      @l2_biz_event_StakeAdded,
      @l2_biz_event_DelegationAdded,
      @l2_biz_event_UnStaked,
      @l2_biz_event_UnDelegated,
      @l2_biz_event_Slashed,
      @l2_biz_event_UpdateValidatorStatus]
  end
end
