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
  import Indexer.Fetcher.PlatonAppchain, only: [fill_block_range: 5, get_block_number_by_tag: 3, decode_hex: 1]

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

  defp get_l2_biz_event_name(first_topic) do
    event_name =
    case first_topic do
      @l2_biz_event_ValidatorRegistered ->
        "ValidatorRegistered"
      @l2_biz_event_StakeAdded ->
        "StakeAdded"
      @l2_biz_event_DelegationAdded ->
        "DelegationAdded"
      @l2_biz_event_UnStaked ->
        "UnStaked"
      @l2_biz_event_UnDelegated ->
        "UnDelegated"
      @l2_biz_event_Slashed ->
        "Slashed"
      @l2_biz_event_UpdateValidatorStatus ->
        "UpdateValidatorStatus"
    end
    event_name
  end


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
  @spec event_to_l2_validator_events(non_neg_integer(), binary(), binary(), binary(), binary(), binary(), non_neg_integer(), list()) :: [map()]
  def event_to_l2_validator_events(log_index, first_topic, second_topic, third_topic, data, l2_transaction_hash, l2_block_number, json_rpc_named_arguments) do
    data_bytes =
      case data do
        %Explorer.Chain.Data{} ->
          %Explorer.Chain.Data{bytes: data_byte} = data
          data_byte
        _ ->
          Logger.debug(fn -> "convert event_to_l2_validator_events, data: #{inspect(data)}, amount: #{quantity_to_integer(data)}" end,logger: :platon_appchain)
          PlatonAppchain.decode_hex(data) #其它包里也有decode_hex，所以要PlatonAppchain.
      end

    Logger.debug(fn -> "convert L2 log to l2 validator event: #{get_l2_biz_event_name(first_topic)}" end,logger: :platon_appchain)

    {:ok, timestamp}  = PlatonAppchain.get_block_timestamp_by_number(l2_block_number, json_rpc_named_arguments, 100_000_000)
    block_number = quantity_to_integer(l2_block_number)

    #{logIndex, validator_hash, block_number, hash, action_type, action_desc, amount, block_timestamp} =
      case first_topic do
        @l2_biz_event_ValidatorRegistered ->
          [owner, commission_rate, _pubKey, _blsKey] = TypeDecoder.decode_raw(data_bytes, [:address, {:uint, 256}, :bytes, :bytes])
          Logger.debug(fn -> "convert ValidatorRegistered log.data: owner: #{owner},  commission_rate: #{commission_rate}" end,logger: :platon_appchain)
          # 增加L2_validator记录
          # second_topic，需要记录到topic的数据，如果长度>32字节，则取数据的hash，并把hash放入topic，如果数据长度<=32字节，则左补零后放入topic
          validator_hash = Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed)

          #L2ValidatorService.add_new_validator(validator_hash)
          [%{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:ValidatorRegistered],
            action_desc: "owner: 0x#{Base.encode16(owner)}, commission_rate: #{commission_rate}",
            amount: 0,
            block_timestamp: timestamp
          }]

        @l2_biz_event_StakeAdded ->
          [amount] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
          Logger.debug(fn -> "convert StakeAdded log.data: amount: #{amount}" end,logger: :platon_appchain)
          # 更新L2_validator记录，增加质押金额
          validator_hash =  Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed)
           #与l2_validator_events导入放在同一个事务中
#          L2ValidatorService.increase_stake(validator_hash, amount)
          [%{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:StakeAdded],
            action_desc: nil,
            amount: amount,
            block_timestamp: timestamp
          }]

        @l2_biz_event_DelegationAdded ->
          [amount] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
          Logger.debug(fn -> "convert DelegationAdded log.data: amount: #{amount}" end,logger: :platon_appchain)
          # 更新L2_validator记录，增加委托金额
          delegator_hash =  Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed)
          validator_hash =  Base.decode16!(String.slice(third_topic, -40..-1), case: :mixed)
          #与l2_validator_events导入放在同一个事务中
#          L2ValidatorService.increase_delegation(validator_hash, amount)
          [%{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:DelegationAdded],
            action_desc: "delegator: 0x#{Base.encode16(delegator_hash)}",
            amount: amount,
            block_timestamp: timestamp
          }]

        @l2_biz_event_UnStaked ->
          [amount] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
          validator_hash =  Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed)
          Logger.debug(fn -> "convert UnStaked log.data: amount: #{amount}" end,logger: :platon_appchain)

          #与l2_validator_events导入放在同一个事务中
          # 更新L2_validator记录，减少质押
#          L2ValidatorService.decrease_stake(validator_hash, amount)

          [%{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:UnStaked],
            action_desc: nil,
            amount: amount,
            block_timestamp: timestamp
          }]

        @l2_biz_event_UnDelegated ->
          [amount] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])
          Logger.debug(fn -> "convert UnDelegated log.data: amount: #{amount}" end,logger: :platon_appchain)
          delegator_hash =  Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed)
          validator_hash =  Base.decode16!(String.slice(third_topic, -40..-1), case: :mixed)
          #与l2_validator_events导入放在同一个事务中
          # 更新L2_validator记录，减少委托
#          L2ValidatorService.decrease_delegation(validator_hash, amount)

          [%{
            log_index: log_index,
            validator_hash: validator_hash,
            block_number: block_number,
            hash: l2_transaction_hash,
            action_type: PlatonAppchain.l2_validator_event_action_type()[:UnDelegated],
            action_desc: "delegator: 0x#{Base.encode16(delegator_hash)}",
            amount: amount,
            block_timestamp: timestamp
          }]

        @l2_biz_event_Slashed ->

         action_type = PlatonAppchain.l2_validator_event_action_type()[:Slashed]

         [validator_hashes, amounts] = TypeDecoder.decode_raw(data_bytes, [{:array, :address}, {:array, {:uint, 256}}])
         Logger.debug(fn -> "convert Slashed log.data: validator_hashes: #{validator_hashes}, amounts: #{amounts}" end,logger: :platon_appchain)

         if length(validator_hashes) != length(amounts) do
           Logger.error(fn -> "l2 validator slash event data error, validators not match to amounts" end , logger: :platon_appchain)
           []
         else
           validator_hashes
             |> Stream.with_index
             |> Enum.reduce([], fn({validator_hash, idx}, acc) ->
               event = %{
                 log_index: log_index,
                 validator_hash: validator_hash,
                 block_number: block_number,
                 hash: l2_transaction_hash,
                 action_type: action_type,
                 action_desc: nil,
                 amount: Enum.at(amounts, idx),
                 block_timestamp: timestamp
               }
               [event | acc] #后来的插入头部，效率高
             end)
           |> Enum.reverse  #反转list
        end
       @l2_biz_event_UpdateValidatorStatus->

         action_type = PlatonAppchain.l2_validator_event_action_type()[:UpdateValidatorStatus]

         [current_status] = TypeDecoder.decode_raw(data_bytes, [{:uint, 256}])

         Logger.debug(fn -> "convert UpdateValidatorStatus log.data: current_status: #{current_status}" end,logger: :platon_appchain)
         # 更新L2_validator记录，惩罚节点
         # L2ValidatorService.update_validator_status(second_topic, current_status, block_number)
         validator_hash =  Base.decode16!(String.slice(second_topic, -40..-1), case: :mixed)
         [%{
           log_index: log_index,
           validator_hash: validator_hash,
           block_number: block_number,
           hash: l2_transaction_hash,
           action_type: action_type,
           action_desc: nil,
           amount: current_status, # 在状态变更事件中，表示：状态
           block_timestamp: timestamp
         }]

        _ ->
         []
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
        |> Enum.reduce([], fn {index, first_topic, second_topic, third_topic, data, l2_transaction_hash, l2_block_number}, acc ->
          acc ++ event_to_l2_validator_events(index, first_topic, second_topic, third_topic, data, l2_transaction_hash, l2_block_number,json_rpc_named_arguments)
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

         Enum.reduce(result, [], fn event, acc ->
             acc ++ event_to_l2_validator_events(
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
