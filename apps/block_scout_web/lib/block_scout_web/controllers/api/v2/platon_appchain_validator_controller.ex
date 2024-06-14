defmodule BlockScoutWeb.API.V2.PlatonAppchainValidatorController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
         only: [
           next_page_params: 3,
           paging_options: 1,
           split_list_by_page: 1
         ]

  require Logger

  alias Explorer.Chain.PlatonAppchain.{L2Validator, DailyStatic}
  alias Explorer.Chain.{Wei}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  # TODO 统计数据如何取
  def stats(conn, _params) do

   %{validator_count: validator_count} = L2Validator.validators_size()
   total_bonded = L2Validator.get_total_bonded()

   daily_static =  DailyStatic.find_yesterday_data()

   reward_pool = DailyStatic.get_reward_pool()
   if !is_nil(daily_static) do
     json(
       conn,
       %{
         "validators" => validator_count,
         "validators_24_hours" => validator_count - daily_static.total_validator_size,
         "total_bonded" => total_bonded,
         "total_bonded_24_hours" => Decimal.sub(total_bonded, Decimal.new(daily_static.total_bonded.value)),
         "reward_pool" => reward_pool,
         "block_reward" => "待提供数据",
         "epoch_staking_reward" => "待提供数据"
       }
     )
   else
     json(
       conn,
       %{
         "validators" => validator_count,
         "validators_24_hours" => validator_count,
         "total_bonded" => total_bonded,
         "total_bonded_24_hours" => total_bonded,
         "reward_pool" => reward_pool,
         "block_reward" => "待提供数据",
         "epoch_staking_reward" => "待提供数据"
       }
     )
   end
  end

  @spec list_all_validators(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_all_validators(conn, params) do
    q = Map.get(params, "q")
    validators =
    []
    |> Keyword.put(:role, "all")
    |> Keyword.put(:api?, true)
    |> Keyword.put(:q, q)
    |> L2Validator.list_validators_by_role()

    conn
    |> put_status(200)
    |> render(:platon_appchain_validators, %{
      validators: validators
    })
  end

  @spec list_active_validators(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_active_validators(conn, params) do
    validators =
    []
    |> Keyword.put(:role, "active")
    |> Keyword.put(:api?, true)
    |> L2Validator.list_validators_by_role()

    conn
    |> put_status(200)
    |> render(:platon_appchain_validators, %{
      validators: validators
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/validators` endpoint.
  """
  @spec list_candidate_validators(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_candidate_validators(conn, params) do
    validators =
      []
      |> Keyword.put(:role, "candidate")
      |> Keyword.put(:api?, true)
      |> L2Validator.list_validators_by_role()

    conn
    |> put_status(200)
    |> render(:platon_appchain_validators, %{
      validators: validators
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/validators/history` endpoint.
  """
  @spec list_history_validators(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_history_validators(conn, params) do
    {validators, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> L2Validator.list_history_validators()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, validators, params)

    conn
    |> put_status(200)
    |> render(:platon_appchain_history_validators, %{
      validators: validators,
      next_page_params: next_page_params
    })
  end


  @doc """
    Function to handle GET requests to `/api/v2/validators/:validator_hash_param` endpoint.
  """
  @spec validator_details(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def validator_details(conn, %{"validator_hash_param" => validator_hash_string} = params) do
    validator =
      params
      |> Keyword.put(:api?, true)
      |> L2Validator.find_by_validator_hash()

    conn
    |> put_status(200)
    |> render(:platon_appchain_validator_details, %{validator: validator})
  end

end
