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

    param = [{31,"0xa904bD454A2cc9bC4BE98f1A045bED80A1961DbD"},{52,"0x7921067C779562d46634C124aF0F6AD19E5895C6"},
      {13,"0x4ea29e80381542E1c9Ce63a7CC2C45B2FECc30E8"},{15,"0xC9Fa2a6EdDf33520E8d02002df120a1C9c9318F3"},
      {23,"0xDB0eCbE91f2739a10DAd39e5b53b3174C6C0Eeb2"},{35,"0xa9f7f793A8A5485E1fc50E266fB0bc65C12Db8ee"},
      {33,"0x13943B955A42f55c0576c08a14734641249a943F"},{45,"0x5e2284d43588744EB7e58092F4CC7F86a7B7DCdc"},
      {53,"0x63Eaf0e0780295d180f7e08a3ecA80C9201C098D"},{56,"0xBc0455fa1d36694701a17fc094c0CBA074893Aa0"},
      {73,"0x9f289ea5612Af9fB69D1816ba20a2d72A1153668"},{65,"0x19CeE362fd3566C720ebC1b2B1B4E64C9231Ed2A"}]
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
