defmodule Indexer.Fetcher.PlatonAppchain.L2EpochValidator do
  @moduledoc """
  Get new epoch validator.
  """

  use GenServer

  require Logger

  alias Explorer.Chain
  alias Indexer.Fetcher.PlatonAppchain.Contracts.L2StakeHandler
  alias Indexer.Fetcher.PlatonAppchain

  @default_update_interval :timer.seconds(3)
  @period_type [round: 1, epoch: 2]

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    l2_epoch_size = PlatonAppchain.l2_epoch_size()
    l2_rpc_arguments = PlatonAppchain.l2_rpc_arguments()
    l2_validator_contract_address = PlatonAppchain.l2_validator_contract_address()
    if Helper.is_address_correct?(l2_validator_contract_address) do
      Process.send(self(), :continue, [])
      {:ok,
        %{
          l2_validator_contract_address: l2_validator_contract_address,
          l2_rpc_arguments: l2_rpc_arguments,
          l2_epoch_size: l2_epoch_size,
          next_epoch_block: 0
        }}
    else
      Logger.error("L2 validator contract address: #{l2_validator_contract_address} is invalid or not defined. PlatonAppchain is not started.")
      :ignore
    end
  end

  @spec handle_continue(map(), L2EpochValidator, atom()) :: {:noreply, map()}
  def handle_continue(
        %{
          l2_validator_contract_address: l2_validator_contract_address,
          l2_rpc_arguments: l2_rpc_arguments,
          l2_epoch_size: l2_epoch_size,
          next_epoch_block: next_epoch_block
        } = state,
        calling_module,
        fetcher_name
      )
      when calling_module in [L2EpochValidator] do

    {:ok, latest_block} = PlatonAppchain.get_latest_block_number(l2_rpc_arguments)
    epoch = PlatonAppchain.calculateL2Epoch(latest_block, l2_epoch_size)
    # 通过call不同合约的方法，获取validator的各种信息
    if next_epoch_block == 0 || latest_block >= next_epoch_block do
      #应用启动后第一次执行
      # 更新出块验证人候选人列表(201)
      epoch_validator_addresses = L2StakeHandler.getValidatorAddrs(@period_type[:epoch], epoch)

      epoch_validators = L2StakeHandler.getValidatorsWithAddr(epoch_validator_addresses)
      # 设置验证人类型
      epoch_validators = Enum.map(epoch_validators, fn(validator) ->  Map.put(validator, :status, PlatonAppchain.validator_status()[:Active]) end)

      PlatonAppchain.log_validators(epoch_validators, "Active", "epoch", epoch, latest_block, "L2")

      # 更新所有质押人
      all_candidates = L2StakeHandler.getAllValidators()
      # 设置验证人类型
      all_candidates = Enum.map(all_candidates, fn(candidate) ->  Map.put(candidate, :stats, PlatonAppchain.validator_status()[:Candidate]) end)

      PlatonAppchain.log_validators(all_candidates, "Candidate", "epoch", epoch, latest_block, "L2")
    end

    # 计算下次获取round出块验证人的块高，并算出大概需要delay多久
    nextEpochBlockNumber = epoch * l2_epoch_size + 1
    delay = (nextEpochBlockNumber - latest_block) * 1000
    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | next_epoch_block: nextEpochBlockNumber}}
  end
end
