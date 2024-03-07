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
            "no" => commitments.tx_number,
            "l1_txn_hash" => commitments.l1_txn_hash,
            "tx_type" => commitments.tx_type,
            "block_timestamp" => commitments.block_timestamp,
            "state_batches_index" => Integer.to_string(commitments.start_id) <> "-"  <> Integer.to_string(commitments.end_id),
            "state_batches_txn_hash" => commitments.commitment_hash,
            "state_root" => commitments.state_root,
            "l2_event_hash" => commitments.l2_event_hash,
            "status" => commitments.replay_status
          }
        end),
      next_page_params: next_page_params
    }
  end

  @spec render(String.t(), map()) :: map()
  def render("platon_appchain_deposits_batches.json", %{
    commitments: commitments,
    next_page_params: next_page_params
  }) do
    %{
      items:
        Enum.map(commitments, fn commitments ->
           %{
             "index" =>  Integer.to_string(commitments.start_id) <> "-"  <> Integer.to_string(commitments.end_id),
             "l2_state_batches_hash" => commitments.state_batches_txn_hash,
             "l2_block" => commitments.block_number,
             "block_timestamp" => commitments.block_timestamp,
             "batch_root" => commitments.state_root,
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
            "l2_txn_hash" => withdrawal.l2_event_hash,
            "type" => withdrawal.tx_type,
            "block_timestamp" => withdrawal.block_timestamp,
            "state_batches_index" =>  Integer.to_string(withdrawal.start_block_number) <> "-"  <> Integer.to_string(withdrawal.end_block_number),
            "state_batches_txn_hash" => withdrawal.checkpoint_hash,
            "state_root" => withdrawal.state_root,
            "l1_txn_hash" => withdrawal.l1_exec_hash,
            "status" => withdrawal.replay_status
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("platon_appchain_withdrawals_batches.json", %{
    withdrawals: withdrawals,
    next_page_params: next_page_params
  }) do
    %{
      items:
        Enum.map(withdrawals, fn withdrawal ->
         %{
           "no" => withdrawal.epoch,
           "l1_state_batches_hash" => withdrawal.l1_state_batches_hash,
           "l1_block" => withdrawal.block_number,
           "block_timestamp" => withdrawal.block_timestamp,
           "batch_root" => withdrawal.state_root,
           "l2_txns" => withdrawal.l2_txns,
           "submitter" => "submitter怎么来的？？"
         }
        end),
      next_page_params: next_page_params
    }
  end


  def render("platon_appchain_withdrawals_batches_tx.json", %{
    withdrawals: withdrawals,
    next_page_params: next_page_params
  }) do
    %{
      items:
        Enum.map(withdrawals, fn withdrawal ->
          %{
            "txn_hash" => withdrawal.hash,
            "type" => withdrawal.type,
            "method" =>  withdrawal.input,# 待转换
            "block" => withdrawal.block_number,
            "from" => withdrawal.from,
            "to" => withdrawal.to,
            "value" => withdrawal.value,
            "fee" => withdrawal.fee
          }
        end),
      next_page_params: next_page_params
    }
  end

  def render("platon_appchain_items_count.json", %{count: count}) do
    count
  end
end
