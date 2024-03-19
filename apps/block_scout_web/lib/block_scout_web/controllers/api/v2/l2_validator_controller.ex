defmodule BlockScoutWeb.API.V2.L2ValidatorController do
  use BlockScoutWeb, :controller

  require Logger

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      paging_options_validator_event: 2,
      put_key_value_to_paging_options: 3,
      split_list_by_page: 1,
      parse_block_hash_or_number_param: 1
    ]

  import BlockScoutWeb.PagingHelper, only: [delete_parameters_from_next_page_params: 1, select_validator_status: 1]

  alias Explorer.{Chain}
  alias Explorer.Chain.PlatonAppchain.Validator

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)


  def validators(conn, params) do
    full_options = select_validator_status(params)

    l2_validators_plus_one =
      full_options
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(@api_true)
      |> Chain.list_l2Validators()

    {validators, next_page} = split_list_by_page(l2_validators_plus_one)

    # 组装下个分页信息
    next_page_params = next_page |> next_page_params(validators, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:l2Validators, %{validator: validators, next_page_params: next_page_params})
  end

  def his_validators(conn, params) do
    {his_validators, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Validator.his_validators()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, his_validators, params)

    conn
    |> put_status(200)
    |> render(:his_validators, %{
      his_validators: his_validators,
      next_page_params: next_page_params
    })
  end


  def validator_details(conn, %{"validator_hash_param" => address_hash_string} = params) do
    with {:format, {:ok, validator_hash_address}} <- {:format, Chain.string_to_address_hash(address_hash_string)} do
     validator_detail =  Validator.get_validator_details(validator_hash_address)

      conn
      |> put_status(200)
      |> render(:validator_details, %{validator_detail: validator_detail})
    end
  end

  def staking(conn, %{"validator_hash" => validator_hash_string, "block_number" => block_number} = params) do
    %{"validator_hash" => address_hash, "block_number" => block_number} = params
    with {:format, {:ok, validator_hash}} <- {:format, Chain.string_to_address_hash(validator_hash_string)} do

      {stakings, next_page} =
        paging_options_validator_event(validator_hash,block_number)
      |> Keyword.put(:api?, true)
      |> Validator.get_stakings()
      |> split_list_by_page()

      next_page_params = next_page_params(next_page, stakings, params)

      conn
      |> put_status(200)
      |> render(:stakings, %{stakings: stakings, next_page_params: next_page_params})
    end
  end

  def staking(conn, %{"validator_hash" => validator_hash_string} = params) do
    %{"validator_hash" => address_hash} = params
    with {:format, {:ok, validator_hash}} <- {:format, Chain.string_to_address_hash(validator_hash_string)} do

      {stakings, next_page} =
        paging_options_validator_event(validator_hash,0)
        |> Keyword.put(:api?, true)
        |> Validator.get_stakings()
        |> split_list_by_page()

      next_page_params = next_page_params(next_page, stakings, params)

      conn
      |> put_status(200)
      |> render(:stakings, %{stakings: stakings, next_page_params: next_page_params})
    end
  end

  def blocks_produced(conn, %{"validator_hash" => validator_hash_string, "block_number" => block_number} = params) do
    %{"validator_hash" => address_hash, "block_number" => block_number} = params
    with {:format, {:ok, validator_hash}} <- {:format, Chain.string_to_address_hash(validator_hash_string)} do

      {block_produceds, next_page} =
        paging_options_validator_event(validator_hash,block_number)
        |> Keyword.put(:api?, true)
        |> Validator.get_blocks_produced()
        |> split_list_by_page()

      next_page_params = next_page_params(next_page, block_produceds, params)

      conn
      |> put_status(200)
      |> render(:block_produced, %{block_produced: block_produceds, next_page_params: next_page_params})
    end
  end

  def blocks_produced(conn, %{"validator_hash" => validator_hash_string} = params) do
    %{"validator_hash" => address_hash} = params
    with {:format, {:ok, validator_hash}} <- {:format, Chain.string_to_address_hash(validator_hash_string)} do

      {block_produceds, next_page} =
        paging_options_validator_event(validator_hash,0)
        |> Keyword.put(:api?, true)
        |> Validator.get_blocks_produced()
        |> split_list_by_page()

      next_page_params = next_page_params(next_page, block_produceds, params)

      conn
      |> put_status(200)
      |> render(:block_produced, %{block_produced: block_produceds, next_page_params: next_page_params})
    end
  end

  def validator_action(conn, %{"validator_hash" => validator_hash_string, "block_number" => block_number} = params) do
    %{"validator_hash" => address_hash, "block_number" => block_number} = params
    with {:format, {:ok, validator_hash}} <- {:format, Chain.string_to_address_hash(validator_hash_string)} do

      {validator_actions, next_page} =
        paging_options_validator_event(validator_hash,block_number)
        |> Keyword.put(:api?, true)
        |> Validator.get_validator_action()
        |> split_list_by_page()

      next_page_params = next_page_params(next_page, validator_actions, params)

      conn
      |> put_status(200)
      |> render(:validator_actions, %{validator_actions: validator_actions, next_page_params: next_page_params})
    end
  end

  def validator_action(conn, %{"validator_hash" => validator_hash_string} = params) do
    %{"validator_hash" => address_hash} = params
    with {:format, {:ok, validator_hash}} <- {:format, Chain.string_to_address_hash(validator_hash_string)} do

      {validator_actions, next_page} =
        paging_options_validator_event(validator_hash,0)
        |> Keyword.put(:api?, true)
        |> Validator.get_validator_action()
        |> split_list_by_page()

      next_page_params = next_page_params(next_page, validator_actions, params)

      conn
      |> put_status(200)
      |> render(:validator_actions, %{validator_actions: validator_actions, next_page_params: next_page_params})
    end
  end

  def delegator(conn, %{"validator_hash" => validator_hash_string, "block_number" => block_number} = params) do
    %{"validator_hash" => address_hash, "block_number" => block_number} = params
    with {:format, {:ok, validator_hash}} <- {:format, Chain.string_to_address_hash(validator_hash_string)} do

      {delegators, next_page} =
        paging_options_validator_event(validator_hash,block_number)
        |> Keyword.put(:api?, true)
        |> Validator.get_delegator()
        |> split_list_by_page()

      next_page_params = next_page_params(next_page, delegators, params)

      conn
      |> put_status(200)
      |> render(:delegators, %{delegators: delegators, next_page_params: next_page_params})
    end
  end

  def delegator(conn, %{"validator_hash" => validator_hash_string} = params) do
    %{"validator_hash" => address_hash} = params
    with {:format, {:ok, validator_hash}} <- {:format, Chain.string_to_address_hash(validator_hash_string)} do

      {delegators, next_page} =
        paging_options_validator_event(validator_hash,0)
        |> Keyword.put(:api?, true)
        |> Validator.get_delegator()
        |> split_list_by_page()

      next_page_params = next_page_params(next_page, delegators, params)

      conn
      |> put_status(200)
      |> render(:delegators, %{delegators: delegators, next_page_params: next_page_params})
    end
  end
end
