defmodule Explorer.Chain.PlatonAppchain.L2Delegator do
  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  # alias Ecto.Changeset
  alias Explorer.{
    Chain,
    Repo
    }

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @optional_attrs ~w(locking_delegate_amount withdrawal_delegate_amount withdrawn_delegate_reward pending_delegate_reward)a

  @required_attrs ~w(delegator_hash validator_hash delegate_amount)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
     delegator_hash： 委托人地址
     validator_hash:  验证人地址,
     delegate_amount:  有效委托金额,
     locking_delegate_amount:  锁定的委托金额,
     withdrawal_delegate_amount:  可提取的委托金额,
     withdrawn_delegate_reward: 已提取的委托奖励,
     pending_delegate_reward: 待提取的委托奖励
  """
  @type t :: %__MODULE__{
    delegator_hash: Hash.Address.t(),
    validator_hash:  Hash.Address.t(),
    delegate_amount:  Wei.t(),
    locking_delegate_amount: Wei.t(),
    withdrawal_delegate_amount: Wei.t(),
    withdrawn_delegate_reward: Wei.t(),
    pending_delegate_reward: Wei.t(),
  }

  @primary_key false
  schema "l2_delegators" do
    field(:delegator_hash, Hash.Address, primary_key: true)
    field(:validator_hash, Hash.Address, primary_key: true)
    field(:delegate_amount, Wei)
    field(:locking_delegate_amount, Wei)
    field(:withdrawal_delegate_amount, Wei)
    field(:withdrawn_delegate_reward, Wei)
    field(:pending_delegate_reward, Wei)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> validate_required(@required_attrs)
    |> unique_constraint(:delegator_hash, :validator_hash)
  end

  @spec update_changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def update_changeset(%__MODULE__{} = module,params \\ %{}) do
    module
    |> cast(params, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:delegator_hash, :validator_hash)
  end

  # 修改已提取的委托奖励, 如果increment就是负数，就是减少委托
  def update_withdrawn_delegator_reward(delegator_hash, validator_hash, increment) do
    from(v in __MODULE__, where: v.validator_hash == ^validator_hash and v.delegator_hash == ^delegator_hash)
    |> Repo.update_all(inc: [withdrawn_delegate_reward: increment])
  end

  # 修改已提取的委托奖励, 如果increment就是负数，就是减少委托
  def update_delegations(l2_delegator_data_maps) do
    update_changeset(l2_delegator_data_maps)
    |> Repo.insert(
         on_conflict: {:replace, [:delegate_amount, :locking_delegate_amount, :withdrawal_delegate_amount, :updated_at]},
         conflict_target: [:delegator_hash, :validator_hash],
         returning: false)
  end

end
