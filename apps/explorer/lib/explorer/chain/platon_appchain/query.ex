defmodule Explorer.Chain.PlatonAppchain.Query do
  @moduledoc "Contains read functions for Platon appchain modules."

  require Logger

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 3,
      subquery: 1,
      union: 2,
      where: 3
    ]

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.{PagingOptions, Repo}
  alias Explorer.Chain.PlatonAppchain.{L1Event, L1Execute, L2Event, L2Execute, Commitment, Checkpoint, L2Validator, L2ValidatorHistory}
  alias Explorer.Chain.{Block, Hash, Transaction}

  @spec deposits(list()) :: list()
  def deposits(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    l1_l2_subquery =
      from(
        l1e in L1Event,
        left_join: l2e in L2Execute,
        on: l1e.event_id == l2e.event_id,
        select: %{event_id: l1e.event_id,l1e_hash: l1e.hash,tx_type: l1e.tx_type,l1e_block_timestamp: l1e.block_timestamp,l2e_hash: l2e.hash,replay_status: l2e.replay_status}
      )

    base_query =
      from(
        c in Commitment,
        right_join: l12 in subquery(l1_l2_subquery),
        on: l12.event_id >= c.start_id and l12.event_id <= c.end_id,
        select: %{
          event_id: l12.event_id,
          l1_event_hash: l12.l1e_hash,
          tx_type: l12.tx_type,
          block_timestamp: l12.l1e_block_timestamp,
          l2_event_hash: l12.l2e_hash,
          replay_status: coalesce(l12.replay_status,0),
          start_id: coalesce(c.start_id,0),
          end_id: coalesce(c.end_id,0),
          commitment_hash: c.hash,
          state_root: c.state_root
        },
        where: not is_nil(l12.event_id),
        order_by: [desc: l12.event_id]
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
        on: l2e.event_id >= c.start_id and l2e.event_id <= c.end_id,
        group_by: c.hash,
        select: %{hash: c.hash, tx_number: coalesce(count(l2e.event_id),0)}
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
        order_by: [desc: c.block_number]
      )

    base_query
    |> page_deposits_or_withdrawals_batch(paging_options)
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
          event_id: l2e.event_id,
          from: l2e.from,
          l2_event_hash: l2e.hash,
          tx_type: l2e.tx_type,
          block_timestamp: l2e.block_timestamp,
          start_block_number: coalesce(c.start_block_number, 0),
          end_block_number: coalesce(c.end_block_number, 0),
          checkpoint_hash: l1e.checkpoint_hash,
          state_root: c.state_root,
          l1_exec_hash: l1e.hash,
          replay_status: coalesce(l1e.replay_status,0)
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

    base_query =
      from(
        c in Checkpoint,
        select: %{
          epoch: c.epoch,
          l1_state_batches_hash: c.hash,
          block_number: c.block_number,
          block_timestamp: c.block_timestamp,
          state_root: c.state_root,
          l2_txns: c.event_counts,
          from: c.from,
          tx_fee: c.tx_fee
        },
        order_by: [desc: c.block_timestamp]
      )

    base_query
    |> page_deposits_or_withdrawals_batch(paging_options)
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


  @spec withdrawals_batches_tx(list()) :: list()
  def withdrawals_batches_tx(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())
    %PagingOptions{key: {start_block_number, end_block_number}} = paging_options

    base_query =
      from(
        l2e in L2Event,
        inner_join: t in Transaction,
        on: l2e.hash == t.hash,
        select: %{
          hash: l2e.hash,
          type: t.type,
          block_number: l2e.block_number,
          input: t.input,
          from: l2e.from,
          to: l2e.to,
          value: t.value,
          fee: t.gas_price*t.gas_used
        },
        where: l2e.block_number >= ^start_block_number,
        where: l2e.block_number <= ^end_block_number,
        order_by: [desc: l2e.block_number]
      )

    base_query
#    |> page_deposits_or_withdrawals(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec withdrawals_batches_tx_count(list()) :: term() | nil
  def withdrawals_batches_tx_count(options \\ []) do
    query =
      from(
        l2e in L2Event,
        join: t in Transaction,
        on: l2e.hash == t.hash,
        where: not is_nil(l2e.block_number)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @spec delegations(Hash.Address.t(),list()) :: list()
  def delegations(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    # TODO 如果验证人移到历史表时，需要关联历史表查询
    base_query =
      from(
        l1e in L1Event,
        join: l2e in L2Execute,
        on: l1e.event_id == l2e.event_id,
        left_join: v in L2Validator,
        on: l1e.validator == v.validator_hash,
        where: l1e.tx_type == 4 and l2e.replay_status == 1 and l1e.from == ^address_hash,
        group_by: [l1e.validator,v.name,v.logo,v.status],
        select: %{
          validator: l1e.validator,
          name: v.name,
          logo: v.logo,
          status: v.status,
          delegation_amount:  coalesce(sum(l1e.amount),0)
        },
        order_by: [desc: l1e.validator]
      )

    base_query
    |> page_delegations(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec validators(Hash.Address.t(),list()) :: list()
  def validators(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    # TODO 如果验证人移到历史表时，需要关联历史表查询
    base_query =
      from(
        l1e in L1Event,
        join: l2e in L2Execute,
        on: l1e.event_id == l2e.event_id,
        left_join: v in L2Validator,
        on: l1e.validator == v.validator_hash,
        where: l1e.tx_type >= 2 and l1e.tx_type <= 3 and l2e.replay_status == 1 and l1e.from == ^address_hash,
        group_by: [l1e.validator,v.name,v.logo,v.status],
        select: %{
          validator: l1e.validator,
          name: v.name,
          logo: v.logo,
          status: v.status,
          stake_amount:  coalesce(sum(l1e.amount),0)
        },
        order_by: [desc: l1e.validator]
      )

    base_query
    |> page_delegations(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec get_platon_appchain_actions(Hash.Full.t()) :: L1Event.t() | L2Event.t()
  def get_platon_appchain_actions(tx_hash) do
    l2_execute_query =
      from(
        l2e in L2Execute,
        left_join: l1e in L1Event,
        on: l2e.event_id == l1e.event_id,
        where: l2e.hash == ^tx_hash,
        select: %{
          tx_type: l1e.tx_type,
          amount:  l1e.amount,
          from: l1e.from,
          to: l1e.to
        }
      )
    l2_query =
      from(
        l2e in L2Event,
        where: l2e.hash == ^tx_hash,
        select: %{
          tx_type: l2e.tx_type,
          amount:  l2e.amount,
          from: l2e.from,
          to: l2e.to
        }
      )
    executes = l2_execute_query |> Repo.one()
    if (executes != nil) do
      executes
    else
      events = l2_query |> Repo.one()
      if (events != nil) do
        events
      else
        nil
      end
    end
  end

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: nil}), do: query

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: {no}}) do
    from(item in query, where: item.event_id < ^no)
  end

  defp page_deposits_or_withdrawals_batch(query, %PagingOptions{key: nil}), do: query

  defp page_deposits_or_withdrawals_batch(query, %PagingOptions{key: {number}}) do
    from(item in query, where: item.block_number < ^number)
  end

  defp page_delegations(query, %PagingOptions{key: nil}), do: query

  defp page_delegations(query, %PagingOptions{key: {validator}}) do
    from(item in query, where: item.validator < ^validator)
  end
end
