defmodule Explorer.Chain.PlatonAppchain.L2Validator do
  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  # alias Ecto.Changeset
  alias Explorer.{
    Chain,
    Repo
  }

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @optional_attrs ~w(locking_stake_amount withdrawal_stake_amount withdrawn_reward stake_reward delegate_reward rank name detail logo website expect_apr block_rate auth_status role)a

  @required_attrs ~w(validator_hash owner_hash stake_amount delegate_amount commission_rate stake_epoch status)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
     validator_hash:  质押节点地址,
     stake_epoch:  初始质押epoch,
     owner_hash:  节点owner地址,
     commission_rate: 拥金比例, 每个结算周期，每个验证人获得总奖励，首先按此金额扣除CommissionRate，剩余的再按质押/委托金额比例分配,
     stake_amount:  有效质押金额,
     locking_stake_amount:  锁定的质押金额,
     withdrawal_stake_amount:  可提取的质押金额,
     delegate_amount:  有效委托金额,
     withdrawn_reward: 已提取的奖励
     stake_reward:  验证人可领取奖励（出块与质押）,
     delegate_reward:  委托奖励,
     pending_validator_rewards:  验证人可提取的金额,
     rank: 排名，获取所有质押节点返回的列表序号,
     name:  String.t(),
     detail:  String.t(),
     logo:  String.t(),
     website:  String.t(),
     expect_apr:  预估年收益率，万分之一单位,
     produced_blocks:  最近24小时出块数,
     block_rate:  最近24小时出块率，万分之一单位,
     auth_status:  是否验证 0-未验证，1-已验证,
     role:  0-candidate(质押节点) 1-active(共识节点候选人) 2-verifying(共识节点),
     status:  浏览器目前只判断：0: 正常 1：无效 2：低出块 4: 低阈值 8: 双签 16：解质押 32:惩罚
  """
  @type t :: %__MODULE__{
               validator_hash:  Hash.Address.t(),
               stake_epoch:  non_neg_integer(),
               owner_hash:  Hash.Address.t(),
               commission_rate:  non_neg_integer(),
               stake_amount:  Wei.t(),
               locking_stake_amount:  Wei.t(),
               withdrawal_stake_amount:  Wei.t(),
               delegate_amount:  Wei.t(),
               withdrawn_reward: Wei.t(),
               stake_reward:  Wei.t(),
               delegate_reward:  Wei.t(),
               pending_validator_rewards:  Wei.t(),
               rank: non_neg_integer(),
               name:  String.t(),
               detail:  String.t(),
               logo:  String.t(),
               website:  String.t(),
               expect_apr:  integer(),
               produced_blocks:  non_neg_integer(),
               block_rate:  integer(),
               auth_status:  non_neg_integer(),
               role:  non_neg_integer(),
               status:  non_neg_integer()
             }

  @primary_key false
  schema "l2_validators" do
    field(:validator_hash, Hash.Address, primary_key: true)
    field(:stake_epoch, :integer)
    field(:owner_hash, Hash.Address)
    field(:commission_rate, :integer)
    field(:stake_amount, Wei)
    field(:locking_stake_amount, Wei)
    field(:withdrawal_stake_amount, Wei)
    field(:delegate_amount, Wei)
    field(:withdrawn_reward, Wei)
    field(:stake_reward, Wei)
    field(:delegate_reward, Wei)
    field(:pending_validator_rewards, Wei)
    field(:rank, :integer)
    field(:name, :string)
    field(:detail, :string)
    field(:logo, :string)
    field(:website, :string)
    field(:expect_apr, :integer)
    field(:produced_blocks, :integer)
    field(:block_rate, :integer)
    field(:auth_status, :integer)
    field(:role, :integer)
    field(:status, :integer)

    timestamps()
  end

  def get_by_rank(rank, options) do
    Chain.select_repo(options).get_by(__MODULE__, rank: 1)
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> validate_required(@required_attrs)
    |> unique_constraint(:validator_hash)
  end

  def update_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:validator_hash)
  end

  def update_validator(repo, dataMap) do
    repo.get_by(__MODULE__, validator_hash: dataMap.validator_hash)
    |> changeset(dataMap)
    |> repo.update()
  end

  @spec upsert_validator(Ecto.Repo.t(), map()) :: {:ok, Ecto.Schema.t()} | {:eroror, reason :: String.t()}
  def upsert_validator(repo, dataMap) do
    %__MODULE__{}
    |> cast(dataMap, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> repo.insert(
         on_conflict: :replace_all,   # replace_all 更新所有字段
         conflict_target: [:validator_hash],
         returning: true)
  end

  # 增加新的质押节点，如果节点hash已经存在，则更新（实际上，不会有重复主键的，因为解质押的节点信息，已经被移入历史表中）
  def add_new_validator(repo, dataMap) do
    %__MODULE__{}
    |> changeset(dataMap)
    |> repo.insert(
         on_conflict: [set: [locking_stake_amount: 0, withdrawal_stake_amount: 0, stake_reward: 0, delegate_reward: 0, rank: 0, name: nil, detail: nil, logo: nil, website: nil, expect_apr: 0, block_rate: 0, auth_status: 0, role: 0]],
         conflict_target: [:validator_hash],
         returning: true)
  end

  # 增加新的质押节点，如果节点hash已经存在，则更新（实际上，不会有重复主键的，因为解质押的节点信息，已经被移入历史表中）
  def add_new_validator(dataMap) do
    %__MODULE__{}
    |> changeset(dataMap)
    |> Repo.insert(
      on_conflict: [set: [locking_stake_amount: 0, withdrawal_stake_amount: 0, stake_reward: 0, delegate_reward: 0, rank: 0, name: nil, detail: nil, logo: nil, website: nil, expect_apr: 0, block_rate: 0, auth_status: 0, role: 0]],
      conflict_target: [:validator_hash],
      returning: true)
  end

  # 修改质押金额, 如果increment就是负数，就是减少质押
  def update_stake_amount(validator_hash, increment) do
    query = from v in __MODULE__, where: v.validator_hash == ^validator_hash
    Repo.update_all(query, inc: [stake_amount: increment])
  end

  # 修改质押金额, 如果increment就是负数，就是减少质押
  def update_withdrawn_reward(validator_hash, increment) do
    query = from v in __MODULE__, where: v.validator_hash == ^validator_hash
    Repo.update_all(query, inc: [withdrawn_reward: increment])
  end

  # 修改委托金额, 如果increment就是负数，就是减少委托
  def update_delegate_amount(validator_hash, increment) do
    from(v in __MODULE__, where: v.validator_hash == ^validator_hash)
    |> Repo.update_all(inc: [delegate_amount: increment])
  end

  # 惩罚验证人，减少每个验证人的质押金额
  def slash(slash_tuple_list) do
    Ecto.Multi.new()
    |> do_slash(slash_tuple_list)
    |> Repo.transaction()
  end

  defp do_slash(multi, slash_tuple_list) do
    Enum.reduce(slash_tuple_list, multi, fn tuple, multi ->
      Ecto.Multi.update_all(multi, {:slash_validator, elem(tuple, 0)}, from(v in __MODULE__, where: v.validator_hash == ^elem(tuple, 0)), [inc: [stake_amount: 0 - elem(tuple, 1)]])
    end)
  end

  def update_status(validator_hash, newStatus) do
    from(v in __MODULE__, where: v.validator_hash == ^validator_hash, update: [set: [status: ^newStatus]])
    |> Repo.update_all([])
  end

  def update_rank_and_amount(rank_tuple_list) do
    Ecto.Multi.new()
    |> do_reset_rank_and_amount(rank_tuple_list)
    |> Repo.transaction()
  end

  defp do_reset_rank_and_amount(multi, rank_tuple_list) do
    Enum.reduce(rank_tuple_list, multi, fn tuple, multi ->
      Ecto.Multi.update_all(multi, {:reset_validator_rank, elem(tuple, 0)}, from(v in __MODULE__, where: v.validator_hash == ^elem(tuple, 0)),
        [set: [rank: elem(tuple, 1),locking_stake_amount: elem(tuple, 2),withdrawal_stake_amount:  elem(tuple, 3),pending_validator_rewards:  elem(tuple, 4)]])
    end)
  end

  def unstake(addr, exit_block, exit_desc, unstake_enum) do
    query = from v in __MODULE__,
                 select: %{
                   validator_hash: v.validator_hash,
                   stake_epoch: v.stake_epoch,
                   owner_hash: v.owner_hash,
                   commission_rate: v.commission_rate,
                   stake_amount: v.stake_amount,
                   locking_stake_amount: v.locking_stake_amount,
                   withdrawal_stake_amount: v.withdrawal_stake_amount,
                   delegate_amount: v.delegate_amount,
                   stake_reward: v.stake_reward,
                   delegate_reward: v.delegate_reward,
                   rank: v.rank,
                   name: v.name,
                   detail: v.detail,
                   logo: v.logo,
                   website: v.website,
                   expect_apr: v.expect_apr,
                   block_rate: v.block_rate,
                   auth_status: v.auth_status,
                   role: v.role,
                   #status: v.status,
                   status: ^unstake_enum,
                   exit_block: ^exit_block,
                   inserted_at: v.inserted_at,
                   updated_at: v.updated_at},
                 where: v.validator_hash == ^addr

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(
        :backup,
        Explorer.Chain.PlatonAppchain.L2ValidatorHistory,
        query,
        on_conflict: :replace_all, #{:replace_all_except, [:inserted_at, :updated_at]},
        conflict_target: [:validator_hash])
    |> Ecto.Multi.delete_all(
         :delete,
         from(x in __MODULE__, where: x.validator_hash == ^addr),
         [])
  end


  def backup_exited_validator(repo, validator_hash, status, exit_block, exit_desc) do
    query = from v in __MODULE__,
                 select: %{
                   validator_hash: v.validator_hash,
                   stake_epoch: v.stake_epoch,
                   owner_hash: v.owner_hash,
                   commission_rate: v.commission_rate,
                   stake_amount: v.stake_amount,
                   locking_stake_amount: v.locking_stake_amount,
                   withdrawal_stake_amount: v.withdrawal_stake_amount,
                   delegate_amount: v.delegate_amount,
                   stake_reward: v.stake_reward,
                   delegate_reward: v.delegate_reward,
                   rank: v.rank,
                   name: v.name,
                   detail: v.detail,
                   logo: v.logo,
                   website: v.website,
                   expect_apr: v.expect_apr,
                   block_rate: v.block_rate,
                   auth_status: v.auth_status,
                   role: v.role,
                   #status: v.status,
                   status: ^status,
                   exit_block: ^exit_block,
                   exit_desc: ^exit_desc,
                   inserted_at: v.inserted_at,
                   updated_at: v.updated_at},
                 where: v.validator_hash == ^validator_hash

      repo.insert_all(
        Explorer.Chain.PlatonAppchain.L2ValidatorHistory,
        query,
        on_conflict: :replace_all, #{:replace_all_except, [:inserted_at, :updated_at]},
        conflict_target: [:validator_hash])
  end

  def delete_exited_validator(repo, validator_hash) do
    repo.delete_all(
      from(x in __MODULE__, where: x.validator_hash == ^validator_hash))
  end

  @spec list_validators_by_role([]) :: [__MODULE__.t]
  def list_validators_by_role(options \\ []) do
    role_value = Keyword.get(options, :role, "All")
    query =
      case String.downcase(role_value) do
        "all" ->
          from(
            v in __MODULE__,
            order_by: [desc: v.rank]
          )
        "active" ->
          from(
            v in __MODULE__,
            where: v.role == 1,
            order_by: [desc: v.rank]
          )
        "candidate" ->
          from(
            v in __MODULE__,
            where: v.role == 0,
            order_by: [desc: v.rank]
          )
      end

    query
    |> select_repo(options).all()
  end

  @spec find_by_validator_hash(Hash.Address.t()) :: {:ok, L2Validator.t()} | {:error, :not_found}
  def find_by_validator_hash(%Hash{byte_count: unquote(Hash.Address.byte_count())} = validator_hash, options \\ []) do
    L2Validator
    |> where(hash: ^validator_hash)
    |> select_repo(options).one()
    |> case do
         nil ->
           {:error, :not_found}
         validator ->
           {:ok, validator}
    end
  end

  #  首页统计
  def statistics_validators() do
    query =
      from(l in __MODULE__,
        select: %{
          validator_count: coalesce(count(1), 0),
          total_staked: coalesce(sum(l.stake_amount + l.locking_stake_amount),0)
        }
      )

    query
    |> select_repo([]).one()
  end

  #  验证人首页统计(总验证人数)
  def validators_size() do
    query =
      from(l in __MODULE__,
        select: %{
          validator_count: coalesce(count(1), 0)
        }
      )

    query
    |> select_repo([]).one()
  end

  def get_total_bonded() do
    query =
      from(l in __MODULE__,
        select: coalesce(sum(l.stake_amount + l.delegate_amount),0)
      )

    query
    |> select_repo([]).one()
  end

  #  24小时验证人变化数（验证人表24小时新增数-验证人历史表24小时新增数）
#  def validators_24_change_size() do
#    # 获取当前时间前24小时的时间戳
#    twenty_four_hours_ago = Timex.shift(DateTime.utc_now(), days: -1)
#
#    query =
#      from(l in __MODULE__,
#        where: l.inserted_at  >= ^twenty_four_hours_ago,
#        select: %{
#          validators_24_hours: coalesce(count(1), 0)
#        }
#      )
#
#    query
#    |> select_repo([]).one()
#  end

  # 根据owner_hash查询validator数量
  def count_by_owner_hash(owner_hash) do
    query =
      from(l in __MODULE__,
        select:  coalesce(count(1), 0),
        where: l.owner_hash == ^owner_hash
      )

    Repo.one(query)
  end

  # 根据validator_hash查询validator数量
  def count_by_validator_hash(validator_hash) do
    query =
      from(l in __MODULE__,
        select:  coalesce(count(1), 0),
        where: l.validator_hash == ^validator_hash
      )

    Repo.one(query)
  end

  # 根据validator_hash查询validator数量
  def get_validator_total_assets_staked(validator_hash) do
    query =
      from(l in __MODULE__,
        select: coalesce(sum(l.stake_amount + l.locking_stake_amount),0),
        where: l.validator_hash == ^validator_hash
      )

    Repo.one(query)
  end
end

