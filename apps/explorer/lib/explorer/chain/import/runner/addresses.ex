defmodule Explorer.Chain.Import.Runner.Addresses do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Address, Hash, Import, Transaction}
  alias Explorer.Chain.Import.Runner
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  #该模块必须提供 Import.Runner 协议中定义的函数的实现。
  @behaviour Import.Runner

  # 定义了一个 map 结构，包含两个属性初始值为false
  @row_defaults %{
    decompiled: false,
    verified: false
  }

  # milliseconds
  @timeout 60_000

  # 定义类型别名,为地址列表
  @type imported :: [Address.t()]

  # ecto_schema_module 是要实现的函数名称，并返回Address（Ecto Schema）模块
  @impl Import.Runner
  def ecto_schema_module, do: Address

  # 实现 Import.Runner 协议中的函数。可能是返回一个键，用于从导入选项中获取特定的导入设置
  @impl Import.Runner
  def option_key, do: :addresses

  # 返回一个描述导入数据表行的 map 结构
  # value_type，对应的值是一个字符串，描述了导入数据表行的值的类型。 通过 ecto_schema_module() 函数获取。该模块的 .t/0 函数表示这些模块的零参数版本。（是一条记录类型）
  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  # 数据导入操作
  # multi: 表示用于执行并发操作的 Ecto.Multi 实例。
  # changes_list: 表示要处理的更改列表，其中每个更改都是一个 Map，包含了要插入数据库的数据。
  # options 中提取timestamps 跟踪数据库操作的时间？
  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    # 构建用于插入操作的选项 Map
    insert_options =
      options
      |> Map.get(option_key(), %{}) # 取option_key() 函数返回的键对应的值，就是（：addresses）,取不到就是空map
      |> Map.take(~w(on_conflict timeout)a) # 只保留 on_conflict 和 timeout 这两个键对应的值，其他键值对被移除
      |> Map.put_new(:timeout, @timeout) # 超时时间设置为默认值 @timeout(put_new在不存在时插入)
      |> Map.put(:timestamps, timestamps)

    # 获取事务操作的超时时间，如果没有指定，则使用默认的超时时间
    transactions_timeout = options[Runner.Transactions.option_key()][:timeout] || Runner.Transactions.timeout()

    # 创建超时时间和时间戳信息的map
    update_transactions_options = %{timeout: transactions_timeout, timestamps: timestamps}

    # 对于 change 中不存在但是在 @row_defaults 中存在的键，将其添加到 change 中，并设置其默认值。这个操作确保了每个 change 都包含了 @row_defaults 中定义的键值对，以及默认值
    changes_list_with_defaults =
      Enum.map(changes_list, fn change ->
        Enum.reduce(@row_defaults, change, fn {default_key, default_value}, acc ->
          Map.put_new(acc, default_key, default_value)
        end)
      end)

    # 对数据分组排序
    ordered_changes_list =
      changes_list_with_defaults
      |> Enum.group_by(& &1.hash) # 集合中每个元素执行hash函数，并进行分组
      |> Enum.map(fn {_, grouped_addresses} ->
        Enum.max_by(grouped_addresses, fn address -> #找出每个group的最大的address？有什么目的？
          address_max_by(address)
        end)
      end)
      |> Enum.sort_by(& &1.hash)# 通过上面找出的最大地址，给group排序？

    multi
    |> Multi.run(:filter_addresses, fn repo, _ ->  #runer是个fn/2，第一个参数是repo, 第二个参数是修改的数据
      Instrumenter.block_import_stage_runner( #计算和记录运行时间，返回 filter_addresses/2的结果： {:ok, {[map()], map()}}
        fn -> filter_addresses(repo, ordered_changes_list) end,# 这个是真正执行的函数，这个函数是对db查询操作，返回值如何使用？{:ok, {filtered_addresses, existing_addresses_map}}，类型是：{:ok, {[map()], map()}}
        :addresses,
        :addresses,
        :filter_addresses
      )
    end)
    |> Multi.run(:addresses, fn repo, %{filter_addresses: {addresses, _existing_addresses}} ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, addresses, insert_options) end,
        :addresses,
        :addresses,
        :addresses
      )
    end)
    |> Multi.run(:created_address_code_indexed_at_transactions, fn repo,
                                                                   %{
                                                                     addresses: addresses,
                                                                     filter_addresses: {_, existing_addresses_map}
                                                                   }
                                                                   when is_list(addresses) ->
      Instrumenter.block_import_stage_runner(
        #更新transactions表
        fn -> update_transactions(repo, addresses, existing_addresses_map, update_transactions_options) end,
        :addresses,
        :addresses,
        :created_address_code_indexed_at_transactions
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  ## Private Functions

  @spec filter_addresses(Repo.t(), [map()]) :: {:ok, {[map()], map()}}
  defp filter_addresses(repo, changes_list) do
    # changes_list中取出hash字段对应的值
    hashes = Enum.map(changes_list, & &1.hash)

    # 构建一个 Ecto 查询，从数据库中取出匹配的hashs对应的信息
    existing_addresses_query =
      from(a in Address,
        where: a.hash in ^hashes,
        select: [:hash, :contract_code, :fetched_coin_balance_block_number, :nonce]
      )

    # key 是hash，值是对应查询结果的map
    existing_addresses_map =  # 查询已经存在的地
      existing_addresses_query
      |> repo.all()
      #Map.new([:a, :b], fn x -> {x, x} end)
      #%{a: :a, b: :b}
      #
      #Map.new(%{a: 2, b: 3, c: 4}, fn {key, val} -> {key, val * 2} end)
      #%{a: 4, b: 6, c: 8}
      |> Map.new(&{&1.hash, &1}) #把返回的schema.struct list，转成map

    # 把需求更新的保留，没有变化的过滤掉
    # 把需求更新的保留，没有变化的过滤掉
    filtered_addresses =
      changes_list
      |> Enum.reduce([], fn address, acc ->
        existing_address = existing_addresses_map[address.hash]

        if should_update?(address, existing_address) do
          [address | acc]
        else
          acc
        end
      end)
      |> Enum.reverse()

    {:ok, {filtered_addresses, existing_addresses_map}}
  end

  # 比较新旧数据，判断是否需要更新
  defp should_update?(new_address, existing_address) do
    is_nil(existing_address) or
      (not is_nil(new_address[:contract_code]) and new_address[:contract_code] != existing_address.contract_code) or
      (not is_nil(new_address[:fetched_coin_balance_block_number]) and
         (is_nil(existing_address.fetched_coin_balance_block_number) or
            new_address[:fetched_coin_balance_block_number] >= existing_address.fetched_coin_balance_block_number)) or
      (not is_nil(new_address[:nonce]) and
         (is_nil(existing_address.nonce) or new_address[:nonce] > existing_address.nonce))
  end

  @spec insert(Repo.t(), [%{hash: Hash.Address.t()}], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Address.t()]}
  defp insert(repo, ordered_changes_list, %{timeout: timeout, timestamps: timestamps} = options)
       when is_list(ordered_changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    Import.insert_changes_list(
      repo,
      ordered_changes_list, #插入的地址列表
      conflict_target: :hash, #冲突处理字段
      on_conflict: on_conflict, # 冲突处理策略
      for: Address,  # 要插入的表
      returning: true, # 插入完成返回插入地址列表
      timeout: timeout, # 操作超时时间
      timestamps: timestamps # 记录操作时间
    )
  end


  #处理address struct，返回满足条件的第一个分支
  defp address_max_by(address) do
    cond do
      Map.has_key?(address, :address) ->
        address.fetched_coin_balance_block_number

      Map.has_key?(address, :nonce) ->
        address.nonce

      true ->
        address
    end
  end

  defp default_on_conflict do
    from(address in Address,
      update: [
        set: [
          contract_code: fragment("COALESCE(EXCLUDED.contract_code, ?)", address.contract_code),
          # ARGMAX on two columns
          fetched_coin_balance:
            fragment(
              """
              CASE WHEN EXCLUDED.fetched_coin_balance_block_number IS NOT NULL
                    AND EXCLUDED.fetched_coin_balance IS NOT NULL AND
                        (? IS NULL OR ? IS NULL OR
                         EXCLUDED.fetched_coin_balance_block_number >= ?) THEN
                          EXCLUDED.fetched_coin_balance
                   ELSE ?
              END
              """,
              address.fetched_coin_balance,
              address.fetched_coin_balance_block_number,
              address.fetched_coin_balance_block_number,
              address.fetched_coin_balance
            ),
          # MAX on two columns（有冲突时把最新的插入db）
          fetched_coin_balance_block_number:
            fragment(
              "GREATEST(EXCLUDED.fetched_coin_balance_block_number, ?)",
              address.fetched_coin_balance_block_number
            ),
          nonce: fragment("GREATEST(EXCLUDED.nonce, ?)", address.nonce),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", address.updated_at)
        ]
      ],
      # where any of `set`s would make a change
      # This is so that tuples are only generated when a change would occur
      where:
        fragment("COALESCE(?, EXCLUDED.contract_code) IS DISTINCT FROM ?", address.contract_code, address.contract_code) or
          fragment(
            "EXCLUDED.fetched_coin_balance_block_number IS NOT NULL AND (? IS NULL OR EXCLUDED.fetched_coin_balance_block_number >= ?)",
            address.fetched_coin_balance_block_number,
            address.fetched_coin_balance_block_number
          ) or fragment("GREATEST(?, EXCLUDED.nonce) IS DISTINCT FROM  ?", address.nonce, address.nonce)
    )
  end

  defp update_transactions(repo, addresses, existing_addresses_map, %{timeout: timeout, timestamps: timestamps}) do
    ordered_created_contract_hashes =
      addresses
      |> Enum.filter(fn address ->
        existing_address = existing_addresses_map[address.hash]

        not is_nil(address.contract_code) and (is_nil(existing_address) or is_nil(existing_address.contract_code))
      end)
      |> MapSet.new(& &1.hash)
      |> Enum.sort()

    if Enum.empty?(ordered_created_contract_hashes) do
      {:ok, []}
    else
      query =
        from(t in Transaction,
          where: t.created_contract_address_hash in ^ordered_created_contract_hashes,
          # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
          order_by: t.hash,
          lock: "FOR NO KEY UPDATE" #标识Transaction作为主表，不会更新primary key, 有FK关联到Transaction.主键的表可以正常insert/update。
        )
      #为什么要有个subquery?不能结合query一个updateQuery就更新吗？
      try do
        {_, result} =
          repo.update_all(
            from(t in Transaction, join: s in subquery(query), on: t.hash == s.hash),
            [set: [created_contract_code_indexed_at: timestamps.updated_at]],
            timeout: timeout
          )

        {:ok, result}
      rescue
        postgrex_error in Postgrex.Error ->
          {:error, %{exception: postgrex_error, transaction_hashes: ordered_created_contract_hashes}}
      end
    end
  end
end
