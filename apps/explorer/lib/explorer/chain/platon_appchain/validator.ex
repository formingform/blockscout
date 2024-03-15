defmodule Explorer.Chain.PlatonAppchain.Validator do
  @moduledoc "Contains read functions for Platon appchain about validator modules."

  import Ecto.Query, only: [from: 2, where: 3, or_where: 3, union: 2, subquery: 1, order_by: 3, limit: 2]

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.{PagingOptions, Repo}
  alias Explorer.Chain.PlatonAppchain.{L2Validator,L2ValidatorHistory,L2ValidatorEvent}
  alias Explorer.Chain.{Block,Address, Hash}

  @typedoc """
   * `:optional` - the association is optional and only needs to be loaded if available
   * `:required` - the association is required and MUST be loaded.  If it is not available, then the parent struct
     SHOULD NOT be returned.
  """
  @type necessity :: :optional | :required

  @typedoc """
  The name of an association on the `t:Ecto.Schema.t/0`
  """
  @type association :: atom()

  @type necessity_by_association :: %{association => necessity}
  @typep necessity_by_association_option :: {:necessity_by_association, necessity_by_association}
  @type paging_options :: {:paging_options, PagingOptions.t()}
  @type api? :: {:api?, true | false}

  @spec his_validators(list()) :: list()
  def his_validators(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        h in L2ValidatorHistory,
        select: %{
          stake_epoch: h.stake_epoch,
          validator_hash: h.validator_hash,
          exit_block: h.exit_block,
          exit_desc: h.exit_desc,
          status: h.status
        }
      )

    base_query
    |> page_validator_events(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec get_validator_details(Hash.Address.t()) :: L2Validator.t() |nil
  def get_validator_details(%Hash{byte_count: unquote(Hash.Address.byte_count())} = validator_hash_address) do

    query =
      from(
        v in L2Validator,
        where: v.validator_hash == ^validator_hash_address,
        limit: 1,
        select: v
      )

    Repo.replica().one(query)
  end

  @spec get_stakings([]) :: [L2ValidatorEvent.t()]
  def get_stakings(options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        l in L2ValidatorEvent,
        select: %{
          hash: l.hash,
          block_timestamp: l.block_timestamp,
          block_number: l.block_number,
          amount: l.amount
        },
        order_by: [desc: l.block_number]
      )

    base_query
    |> page_validator_events(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec get_blocks_produced([]) :: [Block.t()]
  def get_blocks_produced(options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        b in Block,
        select: %{
          number: b.number,
          block_timestamp: b.timestamp,
          txn: b.size,
          gas_used: b.gas_used,
        },
        order_by: [desc: b.number]
      )

    base_query
    |> page_validator_events_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end


  @spec get_validator_action([]) :: [L2ValidatorEvent.t()]
  def get_validator_action(options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        l in L2ValidatorEvent,
        select: %{
          hash: l.hash,
          block_timestamp: l.block_timestamp,
          block_number: l.block_number,
          action_desc: l.action_desc
        },
        order_by: [desc: l.block_number]
      )

    base_query
    |> page_validator_events(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec get_delegator([]) :: [L2ValidatorEvent.t()]
  def get_delegator(options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        l in L2ValidatorEvent,
        select: %{
          amount: l.amount,
          action_desc: l.action_desc
        },
        order_by: [desc: l.block_number]
      )

    base_query
    |> page_validator_events(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  defp page_validator_events(query, %PagingOptions{key: nil}), do: query

  defp page_validator_events(query, %PagingOptions{key: {validator_hash}}) do
    from(item in query, where: item.validator_hash == ^validator_hash)
  end

  defp page_validator_events(query, %PagingOptions{key: {validator_hash,block_number}}) do
    from(item in query,
      where:
        item.validator_hash == ^validator_hash and item.block_number < ^block_number
    )
  end

  defp page_validator_event_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_validator_events_blocks(query, %PagingOptions{key: {validator_hash}}) do
    from(item in query, where: item.miner_hash == ^validator_hash)
  end

  defp page_validator_events_blocks(query, %PagingOptions{key: {validator_hash,block_number}}) do
    from(item in query,
      where:
        item.miner_hash == ^validator_hash and item.number < ^block_number
    )
  end
end
