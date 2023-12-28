defmodule Indexer.Fetcher.PlatonAppchain.L2Validator do
  @moduledoc """
  Get new validator.
  """

  use GenServer

  require Logger

  alias Explorer.Chain

  @default_update_interval :timer.seconds(3)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_update()
    {:ok, []}
  end

  def add_tokens(contract_address_hashes) do
    GenServer.cast(__MODULE__, {:add_tokens, contract_address_hashes})
  end

  def handle_cast({:add_tokens, contract_address_hashes}, state) do
    {:noreply, Enum.uniq(List.wrap(contract_address_hashes) ++ state)}
  end

  def handle_info(:update, contract_address_hashes) do

    param = [{3,"0x2905F311530Bf3A11aF0BeFc386E88e381d600c0"},{5,"0x0A023C9DaAd2250fFeb1CB33349627Bd017Df1D8"}]
    li = prepare_datas(param)
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
    update_interval = 3000
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
  def prepare_datas(param) do
    Enum.map(param, fn {index,hash_str} ->
      {:ok, address_hash} = Chain.string_to_address_hash(hash_str)
      %{
        rank: index,
        name: "王小二",
        detail: "我是王小",
        logo: "logo",
        website: "website",
        validator_hash: address_hash,
        owner_hash: address_hash,
        commission: 1,
        self_bonded: 2,
        unbondeding: 3,
        pending_withdrawal_bonded: 4,
        total_delegation: 5,
        validator_reward: 6,
        delegator_reward: 7,
        expect_apr: 8,
        block_rate: 9,
        auth_status: 10,
        status: 11,
        stake_epoch: 12,
        epoch: 13
      }
    end)
  end
end
