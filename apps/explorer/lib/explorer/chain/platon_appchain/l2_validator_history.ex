defmodule Explorer.Chain.PlatonAppchain.L2ValidatorHistory do
  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  # alias Ecto.Changeset
  alias Explorer.{
    Chain,
    Repo,
    PagingOptions
    }

  alias Explorer.Chain.{
    Hash, Wei
    }

  @optional_attrs ~w(locking_stake_amount withdrawal_stake_amount stake_reward delegate_reward rank name detail logo website expect_apr block_rate auth_status role exit_desc)a

  @required_attrs ~w(validator_hash owner_hash stake_amount delegate_amount commission_rate stake_epoch status exit_block)a

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
     stake_reward:  验证人可领取奖励（出块与质押）,
     delegate_reward:  委托奖励,
     rank: 排名，获取所有质押节点返回的列表序号,
     name:  String.t(),
     detail:  String.t(),
     logo:  String.t(),
     website:  String.t(),
     expect_apr:  预估年收益率，万分之一单位,
     block_rate:  最近24小时出块率，万分之一单位,
     auth_status:  是否验证 0-未验证，1-已验证,
     role:  0-candidate(质押节点) 1-active(共识节点后续人) 2-verifying(共识节点),
     status:  浏览器目前只判断：0: 正常 1：无效 2：低出块 4: 低阈值 8: 双签 16：解质押 32:惩罚
     exit_block: 退出区块
     exit_desc: 退出内容
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
               stake_reward:  Wei.t(),
               delegate_reward:  Wei.t(),
               rank: non_neg_integer(),
               name:  String.t(),
               detail:  String.t(),
               logo:  String.t(),
               website:  String.t(),
               expect_apr:  integer(),
               block_rate:  integer(),
               auth_status:  non_neg_integer(),
               role:  non_neg_integer(),
               status:  non_neg_integer(),
               exit_block: non_neg_integer(),
               exit_desc: String.t()
             }

  @primary_key false
  schema "l2_validator_historys" do
    field(:validator_hash, Hash.Address, primary_key: true)
    field(:stake_epoch, :integer)
    field(:owner_hash, Hash.Address)
    field(:commission_rate, :integer)
    field(:stake_amount, Wei)
    field(:locking_stake_amount, Wei)
    field(:withdrawal_stake_amount, Wei)
    field(:delegate_amount, Wei)
    field(:stake_reward, Wei)
    field(:delegate_reward, Wei)
    field(:rank, :integer)
    field(:name, :string)
    field(:detail, :string)
    field(:logo, :string)
    field(:website, :string)
    field(:expect_apr, :integer)
    field(:block_rate, :integer)
    field(:auth_status, :integer)
    field(:role, :integer)
    field(:status, :integer)
    field(:exit_block, :integer)
    field(:exit_desc, :string)
    timestamps()
  end


  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> validate_required(@required_attrs)
    |> unique_constraint(:validator_hash)
  end

  @spec list_validators(list()) :: list()
  def list_validators(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        v in __MODULE__,
        order_by: [asc: v.validator_hash]
      )

    base_query
    |> page_history_validators(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  #  24小时验证人变化数（验证人表24小时新增数-验证人历史表24小时新增数）
  def validators_24_change_size() do
    # 获取当前时间前24小时的时间戳
    twenty_four_hours_ago = Timex.shift(DateTime.utc_now(), days: -1)

    query =
      from(l in __MODULE__,
        where: l.inserted_at  >= ^twenty_four_hours_ago,
        select: %{
          history_validators_24_hours: coalesce(count(1), 0)
        }
      )

    query
    |> select_repo([]).one()
  end

  defp page_history_validators(query, %PagingOptions{key: nil}), do: query

  defp page_history_validators(query, %PagingOptions{key: {validator_hash}}) do
    from(item in query, where: item.validator_hash > ^validator_hash)  # > 或者 <， 取决于 base_query 中的 order by
  end

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
end
