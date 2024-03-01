defmodule BlockScoutWeb.API.V2.PlatonAppchainView do
  use BlockScoutWeb, :view

  @spec render(String.t(), map()) :: map()
  def render("platon_appchain_deposits.json", %{
        commitments: commitments,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(commitments, fn commitments ->
          %{
            "index" => "index需要到l1_evnet中取",
            "l2_state_batches_hash" => commitments.hash,
            "l2_block" => commitments.block_number,
            "block_timestamp" => commitments.block_timestamp,
            "state_root" => commitments.state_root,
            "l1_txns" => "对应l1上交易数量（到其它表表）",
            "submitter" => commitments.from
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("polygon_edge_withdrawals.json", %{
        withdrawals: withdrawals,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(withdrawals, fn withdrawal ->
          %{
            "msg_id" => withdrawal.msg_id,
            "from" => withdrawal.from,
            "to" => withdrawal.to,
            "l2_transaction_hash" => withdrawal.l2_transaction_hash,
            "l2_timestamp" => withdrawal.l2_timestamp,
            "success" => withdrawal.success,
            "l1_transaction_hash" => withdrawal.l1_transaction_hash
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("platon_appchain_items_count.json", %{count: count}) do
    count
  end
end
