defmodule Indexer.Fetcher.PlatonAppchain.L2Validator do

  @moduledoc """
  Periodically updates tokens total_supply
  """

  use GenServer

  require Logger

  alias EthereumJSONRPC
  alias Indexer.Fetcher.PlatonAppchain

  import Explorer.Helper, only: [parse_integer: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Token
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Token.MetadataRetriever
  alias Timex.Duration


  @default_update_interval :timer.seconds(10)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do

    platon_appchain_l2_rpc = Application.get_all_env(:indexer)[Indexer.Fetcher.PlatonAppchain][:platon_appchain_l2_rpc]
    l2_json_rpc_named_arguments = PlatonAppchain.json_rpc_named_arguments(platon_appchain_l2_rpc)

    l2_validator_contract_address = Application.get_all_env(:indexer)[__MODULE__][:l2_validator_contract_address]
    if Helper.is_address_correct?(l2_validator_contract_address) do
      Process.send(self(), :continue, [])

      {:ok,
        %{
          l2_validator_contract_address: l2_validator_contract_address,
          l2_json_rpc_named_arguments: l2_json_rpc_named_arguments
        }}

    else
      Logger.error("L2 validator contract address: #{contract_name} is invalid or not defined. PlatonAppchain is not started.")
      :ignore
    end

  end


  @spec handle_continue(map(), binary(), L2Validator, atom()) :: {:noreply, map()}
  def handle_continue(
        %{
          l2_validator_contract_address: l2_validator_contract_address,
          l2_json_rpc_named_arguments: l2_json_rpc_named_arguments
        } = state,
        calling_module,
        fetcher_name
      )
      when calling_module in [L2Validator] do

    # 通过call不同合约的方法，获取validator的各种信息


    {:ok, latest_block} = PlatonAppchain.get_latest_block_number(l2_json_rpc_named_arguments)
    # 计算下次获取round出块验证人的块高，并算出大概需要delay多久
    # 计算下次获取epoch候选出块验证人的块高，并算出大概需要delay多久

    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  end

  def add_tokens(contract_address_hashes) do
    GenServer.cast(__MODULE__, {:add_tokens, contract_address_hashes})
  end

  def handle_cast({:add_tokens, contract_address_hashes}, state) do
    {:noreply, Enum.uniq(List.wrap(contract_address_hashes) ++ state)}
  end

  def handle_info(:update, contract_address_hashes) do

    size = [1, 2]
    li = prepare_datas(size)
    {import_data, event_name} =  {%{l2_validators: %{params: li}, timeout: :infinity}, "StateSynced"}

    case Chain.import(import_data) do
      {:ok, _} ->
        Logger.debug(fn -> "fetching l2_validator insert" end)
      {:error, reason} ->
        IO.puts("fail==========================")
        IO.puts("fail begin==========================")
        #        Logger.error(
        #          fn ->
        #            ["failed to fetch internal transactions for blocks: ", Exception.format(:error, reason)]
        #          end,
        #          error_count: 1
        #        )
        IO.inspect("error message #{inspect reason}")
        IO.puts("fail end==========================")
        IO.puts("fail==========================")
    end

    schedule_next_update()

    {:noreply, []}
  end

  defp schedule_next_update do
    IO.puts("==============validator====================")
    # 每3秒执行一次
    update_interval = 8000
    Process.send_after(self(), :update, update_interval)
  end

  defp update_token(nil), do: :ok

  defp update_token(address_hash_string) do
    {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)

    token = Repo.get_by(Token, contract_address_hash: address_hash)

    if token && !token.skip_metadata do
      token_params = MetadataRetriever.get_total_supply_of(address_hash_string)

      if token_params !== %{} do
        {:ok, _} = Chain.update_token(token, token_params)
      end
    end

    :ok
  end


  @spec prepare_datas(any()) :: list()
  def prepare_datas(size) do
    Enum.map(size, fn s ->
      %{
        rank: 1,
        name: "王小二",
        logo: "to"
      }
    end)
  end
end
