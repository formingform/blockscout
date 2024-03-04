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
            "start_id" => commitments.start_id,
            "end_id" => commitments.end_id,
            "l2_state_batches_hash" => commitments.hash,
            "l2_block" => commitments.block_number,
            "block_timestamp" => commitments.block_timestamp,
            "state_root" => commitments.state_root,
            "l1_txns" => commitments.tx_number,
            "submitter" => commitments.from
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("platon_appchain_withdrawals.json", %{
        withdrawals: withdrawals,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(withdrawals, fn withdrawal ->
          %{
            "no" => withdrawal.epoch,
            "from" => withdrawal.from,
            "l2_event_hash" => withdrawal.l2_event_hash,
            "type" => withdrawal.tx_type,
            "start_block_number" => withdrawal.start_block_number,
            "end_block_number" => withdrawal.end_block_number,
            "checkpoint_hash" => withdrawal.checkpoint_hash,
            "state_root" => withdrawal.state_root,
            "l1_exec_hash" => withdrawal.l1_exec_hash,
            "replay_status" => withdrawal.replay_status
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("platon_appchain_items_count.json", %{count: count}) do
    count
  end
end
