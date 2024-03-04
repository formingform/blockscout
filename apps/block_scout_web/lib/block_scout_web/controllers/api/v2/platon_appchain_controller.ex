defmodule BlockScoutWeb.API.V2.PlatonAppchainController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain.PlatonAppchain.Query

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @spec deposits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits(conn, params) do
    {commitments, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Query.deposits()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, commitments, params)

    conn
    |> put_status(200)
    |> render(:platon_appchain_deposits, %{
      commitments: commitments,
      next_page_params: next_page_params
    })
  end

  @spec deposits_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits_count(conn, _params) do
    count = Query.deposits_count(api?: true)

    conn
    |> put_status(200)
    |> render(:platon_appchain_items_count, %{count: count})
  end

  @spec withdrawals(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals(conn, params) do
    {withdrawals, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Reader.withdrawals()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, withdrawals, params)

    conn
    |> put_status(200)
    |> render(:polygon_edge_withdrawals, %{
      withdrawals: withdrawals,
      next_page_params: next_page_params
    })
  end

  @spec withdrawals_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals_count(conn, _params) do
    count = Reader.withdrawals_count(api?: true)

    conn
    |> put_status(200)
    |> render(:polygon_edge_items_count, %{count: count})
  end
end
