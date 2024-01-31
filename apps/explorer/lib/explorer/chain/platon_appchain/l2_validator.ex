defmodule Explorer.Chain.PlatonAppchain.L2Validator do
  use Explorer.Schema

  # alias Ecto.Changeset
  alias Explorer.{
    Chain,
    Repo
  }

  alias Explorer.Chain.{
    Hash
  }

  @optional_attrs ~w(locking_stake_amount withdrawal_stake_amount stake_reward delegate_reward rank name detail logo website expect_apr block_rate auth_status role)a

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
  """
  @type t :: %__MODULE__{
               validator_hash:  Hash.Address.t(),
               stake_epoch:  non_neg_integer(),
               owner_hash:  Hash.Address.t(),
               commission_rate:  non_neg_integer(),
               stake_amount:  Wei,
               locking_stake_amount:  Wei,
               withdrawal_stake_amount:  Wei,
               delegate_amount:  Wei,
               stake_reward:  Wei,
               delegate_reward:  Wei,
               rank: non_neg_integer(),
               name:  String.t(),
               detail:  String.t(),
               logo:  String.t(),
               website:  String.t(),
               expect_apr:  integer(),
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
    field(:stake_amount, :decimal)
    field(:locking_stake_amount, :decimal)
    field(:withdrawal_stake_amount, :decimal)
    field(:delegate_amount, :decimal)
    field(:stake_reward, :decimal)
    field(:delegate_reward, :decimal)
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

  # 增加新的质押节点，如果节点hash已经存在，则更新
  def add_new_validator(dataMap) do
    changeset(dataMap)
    |> Repo.insert(
      on_conflict: [set: [locking_stake_amount: 0, withdrawal_stake_amount: 0, stake_reward: 0, delegate_reward: 0, rank: 0, name: nil, detail: nil, logo: nil, website: nil, expect_apr: 0, block_rate: 0, auth_status: 0, role: 0]],
      conflict_target: [:validator_hash],
      returning: true)
  end

  # 修改质押金额, 如果increment就是负数，就是减少质押
  def update_stake_amount(validator_hash, increment) do
    query = from v in __MODULE__, where: v.address == ^validator_hash
    Repo.update_all(query, inc: [stake_amount: increment])
  end

  # 修改委托金额, 如果increment就是负数，就是减少委托
  def update_delegate_amount(validator_hash, increment) do
    from(v in __MODULE__, where: v.address == ^validator_hash)
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
    from(v in __MODULE__, where: v.address == ^validator_hash, update: [set: [status: ^newStatus]])
    |> Repo.update_all([])
  end

  def update_rank(rank_tuple_list) do
    Ecto.Multi.new()
    |> do_reset_rank(rank_tuple_list)
    |> Repo.transaction()
  end

  defp do_reset_rank(multi, rank_tuple_list) do
    Enum.reduce(rank_tuple_list, multi, fn tuple, multi ->
      Ecto.Multi.update_all(multi, {:reset_validator_rank, elem(tuple, 0)}, from(v in __MODULE__, where: v.validator_hash == ^elem(tuple, 0)), [set: [rank: elem(tuple, 1)]])
    end)
  end
end
