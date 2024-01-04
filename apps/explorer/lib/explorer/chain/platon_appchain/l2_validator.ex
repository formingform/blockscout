defmodule Explorer.Chain.PlatonAppchain.L2Validator do
  use Explorer.Schema

  # alias Ecto.Changeset
  alias Explorer.{
    Chain,
    PagingOptions
  }

  alias Explorer.Chain.{
    Hash
  }

  @optional_attrs ~w(name detail logo website)a

  @required_attrs ~w(rank validator_hash owner_hash commission self_bonded unbondeding pending_withdrawal_bonded total_delegation validator_reward delegator_reward expect_apr block_rate auth_status status stake_epoch epoch)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `rank` - validator rank
  * `name` - validator name
  * `detail` - validator detail
  * `logo` - validator logo
  * `website` - validator website
  * `validator_hash` - validator address
  * `owner_hash` - validator owner
  * `commission` - validator commission
  * `self_bonded` - validator self bonded
  * `unbondeding` - validator unbondeding
  * `pending_withdrawal_bonded` - validator pending withdrawal bonded
  * `total_delegation` - validator total delegation
  * `validator_reward` - validator reward
  * `delegator_reward` - validator delegator reward
  * `expect_apr` - validator expect 数据库存整数（乘10000）
  * `block_rate` - validator block rate 数据库存整数（乘10000）
  * `auth_status` - 是否验证 0-未验证，1-已验证
  * `status` - 0-Active 1- Verifying 2-candidate
  * `stake_epoch` - 验证人质押所在周期
  * `epoch` - 当前结算周期（看验证人是哪个周期同步的）
  """
  @type t :: %__MODULE__{
               rank: non_neg_integer(),
               name:  String.t(),
               detail:  String.t(),
               logo:  String.t(),
               website:  String.t(),
               validator_hash:  Hash.Address.t(),
               owner_hash:  Hash.Address.t(),
               commission:  non_neg_integer() | nil,
               self_bonded:  Wei,
               unbondeding:  Wei,
               pending_withdrawal_bonded:  Wei,
               total_delegation:  Wei,
               validator_reward:  Wei,
               delegator_reward:  Wei,
               expect_apr:  Wei,
               block_rate:  Wei,
               auth_status:  non_neg_integer() | nil,
               status:  non_neg_integer() | nil,
               stake_epoch:  Wei,
               epoch:  Wei
             }

  @primary_key {:validator_hash, Hash.Address, autogenerate: false}
  schema "l2_validators" do
    field(:rank, :integer)
    field(:name, :string)
    field(:detail, :string)
    field(:logo, :string)
    field(:website, :string)
#    field(:validator_hash, Hash.Address)
    field(:owner_hash, Hash.Address)
    field(:commission, :integer)
    field(:self_bonded, :decimal)
    field(:unbondeding, :decimal)
    field(:pending_withdrawal_bonded, :decimal)
    field(:total_delegation, :decimal)
    field(:validator_reward, :decimal)
    field(:delegator_reward, :decimal)
    field(:expect_apr, :decimal)
    field(:block_rate, :decimal)
    field(:auth_status, :integer)
    field(:status, :integer)
    field(:stake_epoch, :decimal)
    field(:epoch, :decimal)

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

end
