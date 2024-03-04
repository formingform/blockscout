defmodule Explorer.Chain.PlatonAppchain.Query do
  @moduledoc "Contains read functions for Platon appchain modules."

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2
    ]

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.{PagingOptions, Repo}
  alias Explorer.Chain.PlatonAppchain.{L1Event, L1Execute,L2Event,L2Execute, Commitment,Checkpoint}
  alias Explorer.Chain.{Block, Hash}

  @spec deposits(list()) :: list()
  def deposits(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        l1e in L1Event,
        left_join: l2e in L2Execute,
        on: l1e.event_id == l2e.event_id,
        left_join: c in Commitment,
        on: l2e.commitment_hash == c.hash,
        select: %{
          tx_number: c.tx_number,
          l1_txn_hash: l1e.hash,
          tx_type: l1e.tx_type,
          block_timestamp: l1e.block_timestamp,
          start_id: c.start_id,
          end_id: c.end_id,
          commitment_hash: l2e.commitment_hash,
          state_root: c.state_root,
          l2_event_hash: l2e.hash,
          replay_status: l2e.replay_status
        },
        where: not is_nil(l1e.from),
        order_by: [desc: l1e.event_id]
      )

    base_query
    |> page_deposits_or_withdrawals(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec deposits_count(list()) :: term() | nil
  def deposits_count(options \\ []) do
    query =
      from(
        l1e in L1Event,
        left_join: l2e in L2Execute,
        on: l1e.event_id == l2e.event_id,
        left_join: c in Commitment,
        on: l2e.commitment_hash == c.hash,
        where: not is_nil(l1e.from)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @spec deposits_batches(list()) :: list()
  def deposits_batches(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    count_subquery =
      from(
        c in Commitment,
        left_join: l2e in L2Execute,
        on: c.hash == l2e.commitment_hash,
        group_by: c.hash,
        select: %{hash: c.hash, tx_number: count(l2e.event_id)}
      )

    base_query =
      from(
        c in Commitment,
        join: d in subquery(count_subquery), on: c.hash == d.hash,
        select: %{
          start_id: c.start_id,
          end_id: c.end_id,
          state_batches_txn_hash: c.hash,
          block_number: c.block_number,
          block_timestamp: c.block_timestamp,
          state_root: c.state_root,
          from: c.from,
          tx_number: d.tx_number
        },
        order_by: [desc: c.block_timestamp]
      )

    base_query
    |> page_deposits_or_withdrawals(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec deposits_batches_count(list()) :: term() | nil
  def deposits_batches_count(options \\ []) do
    query =
      from(
        c in Commitment,
        where: not is_nil(c.block_number)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end


  @spec withdrawals(list()) :: list()
  def withdrawals(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        l2e in L2Event,
        left_join: l1e in L1Execute,
        on: l1e.event_id == l2e.event_id,
        left_join: c in Checkpoint,
        on: l1e.checkpoint_hash == c.hash,
        select: %{
          epoch: c.epoch,
          from: l2e.from,
          l2_event_hash: l2e.hash,
          tx_type: l2e.tx_type,
          block_timestamp: l2e.block_timestamp,
          start_block_number: coalesce(c.start_block_number, 0),
          end_block_number: coalesce(c.end_block_number, 0),
          checkpoint_hash: l1e.checkpoint_hash,
          state_root: c.state_root,
          l1_exec_hash: l1e.hash,
          replay_status: l1e.replay_status
        },
        where: not is_nil(l2e.from),
        order_by: [desc: l2e.event_id]
      )

    base_query
    |> page_deposits_or_withdrawals(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec withdrawals_count(list()) :: term() | nil
  def withdrawals_count(options \\ []) do
    query =
      from(
        l in L2Event,
        where: not is_nil(l.from)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @spec withdrawals_batches(list()) :: list()
  def withdrawals_batches(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    count_subquery =
      from(
        c in Checkpoint,
        left_join: l1e in L1Execute,
        on: c.hash == l1e.checkpoint_hash,
        group_by: c.hash,
        select: %{hash: c.hash, tx_number: count(l1e.event_id)}
      )

    base_query =
      from(
        c in Checkpoint,
        join: d in subquery(count_subquery), on: c.hash == d.hash,
        select: %{
          epoch: c.epoch,
          l1_state_batches_hash: c.hash,
          block_number: c.block_number,
          block_timestamp: c.block_timestamp,
          state_root: c.state_root,
          l2_txns: d.tx_number
        },
        order_by: [desc: c.block_timestamp]
      )


    base_query
    |> page_deposits_or_withdrawals(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec withdrawals_batches_count(list()) :: term() | nil
  def withdrawals_batches_count(options \\ []) do
    query =
      from(
        c in Checkpoint,
        where: not is_nil(c.block_timestamp)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

#  @spec deposit_by_transaction_hash(Hash.t()) :: Ecto.Schema.t() | term() | nil
#  def deposit_by_transaction_hash(hash) do
#    query =
#      from(
#        de in DepositExecute,
#        inner_join: d in Deposit,
#        on: d.msg_id == de.msg_id and not is_nil(d.from),
#        select: %{
#          msg_id: de.msg_id,
#          from: d.from,
#          to: d.to,
#          success: de.success,
#          l1_transaction_hash: d.l1_transaction_hash
#        },
#        where: de.l2_transaction_hash == ^hash
#      )
#
#    Repo.replica().one(query)
#  end

#  @spec withdrawal_by_transaction_hash(Hash.t()) :: Ecto.Schema.t() | term() | nil
#  def withdrawal_by_transaction_hash(hash) do
#    query =
#      from(
#        w in Withdrawal,
#        left_join: we in WithdrawalExit,
#        on: we.msg_id == w.msg_id,
#        select: %{
#          msg_id: w.msg_id,
#          from: w.from,
#          to: w.to,
#          success: we.success,
#          l1_transaction_hash: we.l1_transaction_hash
#        },
#        where: w.l2_transaction_hash == ^hash and not is_nil(w.from)
#      )
#
#    Repo.replica().one(query)
#  end

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: nil}), do: query

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: {block_number}}) do
    from(item in query, where: item.block_number < ^block_number)
  end
end
