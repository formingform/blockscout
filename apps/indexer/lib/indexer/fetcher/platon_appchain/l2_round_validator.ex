defmodule Indexer.Fetcher.PlatonAppchain.L2RoundValidator do
  @moduledoc """
  Get new round validator.
  """

  use GenServer

  require Logger

  alias Explorer.Chain
  alias Indexer.Fetcher.PlatonAppchain

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  def init(_) do
    l2_round_size = PlatonAppchain.l2_round_size()
    l2_rpc_arguments = PlatonAppchain.l2_rpc_arguments()
    l2_validator_contract_address = PlatonAppchain.l2_validator_contract_address()
    if Helper.is_address_correct?(l2_validator_contract_address) do
      Process.send(self(), :continue, [])
      {:ok,
        %{
          l2_validator_contract_address: l2_validator_contract_address,
          l2_rpc_arguments: l2_rpc_arguments,
          l2_round_size: l2_round_size,
          next_round_block: 0
        }}
    else
      Logger.error("L2 validator contract address: #{l2_validator_contract_address} is invalid or not defined. PlatonAppchain is not started.")
      :ignore
    end
  end

  @spec handle_continue(map(), L2RoundValidator, atom()) :: {:noreply, map()}
  def handle_continue(
        %{
          l2_validator_contract_address: l2_validator_contract_address,
          l2_rpc_arguments: l2_rpc_arguments,
          l2_round_size: l2_round_size,
          next_round_block: next_round_block
        } = state,
        calling_module,
        fetcher_name
      )
      when calling_module in [L2RoundValidator] do

    {:ok, latest_block} = PlatonAppchain.get_latest_block_number(l2_rpc_arguments)
    round = PlatonAppchain.calculateL2Round(latest_block, l2_round_size)
    # 通过call不同合约的方法，获取validator的各种信息
    if next_round_block == 0 || latest_block >= next_round_block do
      #应用启动后第一次执行
      # 更新出块验证人列表(43)
      round_validator_addresses = L2StakeHandler.getValidatorAddrs(PlatonAppchain.period_type()[:round], round)
      round_validators = L2StakeHandler.getValidatorsWithAddr(round_validator_addresses)
      # 设置验证人类型
      round_validators = Enum.map(round_validators, fn(validator) ->  Map.put(validator, :status, PlatonAppchain.validator_status()[:Verifying]) end)
      PlatonAppchain.log_validators(round_validators, "Verifying", "round", round, latest_block, "L2")


    end

    # 计算下次获取round出块验证人的块高，并算出大概需要delay多久
    nextRoundBlockNumber = round * l2_round_size + 1
    delay = (nextRoundBlockNumber - latest_block) * PlatonAppchain.default_block_interval()
    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | next_round_block: nextRoundBlockNumber}}
  end
end
