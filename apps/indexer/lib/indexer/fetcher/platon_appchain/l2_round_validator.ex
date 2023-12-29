defmodule Indexer.Fetcher.PlatonAppchain.RoundL2Validator do
  @moduledoc """
  Get new round validator.
  """

  use GenServer

  require Logger

  alias Explorer.Chain

  @default_update_interval :timer.seconds(3)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  def init(_) do
    l2_round_size = Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_round_size]
    l2_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_rpc]
    l2_rpc_arguments = PlatonAppchain.json_rpc_named_arguments(l2_rpc)
    l2_validator_contract_address = Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:l2_validator_contract_address]
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
      Logger.error("L2 validator contract address: #{contract_name} is invalid or not defined. PlatonAppchain is not started.")
      :ignore
    end

  end

  # todo: 配置一个 l2_round_size
  @spec handle_continue(map(), binary(), L2Validator, atom()) :: {:noreply, map()}
  def handle_continue(
        %{
          l2_validator_contract_address: l2_validator_contract_address,
          l2_json_rpc_named_arguments: l2_json_rpc_named_arguments,
          l2_round_size: l2_round_size,
          next_round_block: next_round_block
        } = state,
        calling_module,
        fetcher_name
      )
      when calling_module in [L2Validator] do

    {:ok, latest_block} = PlatonAppchain.get_latest_block_number(l2_json_rpc_named_arguments)
    round = PlatonAppchain.calculateL2Round(latest_block, l2_round_size)
    # 通过call不同合约的方法，获取validator的各种信息
    if next_round_block == 0 do
      #应用启动后第一次执行
      # 更新出块验证人列表(43)
    else
      if latest_block >= next_round_block do
        # 更新出块验证人列表(43)
      end
    end

    # 计算下次获取round出块验证人的块高，并算出大概需要delay多久
    nextRoundBlockNumber = round * l2_round_size + 1
    delay = (nextRoundBlockNumber - latest_block) * 1000
    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | next_round_block: nextRoundBlockNumber}}
  end
end
