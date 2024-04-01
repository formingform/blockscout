defmodule Explorer.Chain.PlatonAppchain.L2RewardEvent do
  use Explorer.Schema

  alias Explorer.Chain.{
    Hash,
    Block,
    Wei
    }

  @optional_attrs ~w(amount caller_hash validator_hash)a

  @required_attrs ~w(hash log_index block_number action_type block_timestamp)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `validator_hash` - 验证人地址
  * `action_type` - 事件类型 事件类型：1.提取委托奖励 2.提取验证人奖励
  * `amount` - 事件涉及金额
  * `block_number` - 事件发生块高
  * `block_timestamp` - 交易所在区块时间戳
  * `log_index` - 日志索引
  * `hash` - 事件所在交易hash
  * `caller_hash` - 委托人地址
  """
  @type t :: %__MODULE__{
               hash: Hash.t(),
               log_index: non_neg_integer(),
               block_number: Block.block_number(),
               validator_hash: Hash.Address.t(),
               action_type: non_neg_integer(),
               amount: Wei.t() | nil,
               block_timestamp: DateTime.t() | nil,
               caller_hash: Hash.Address.t(),
             }

  @primary_key false
  schema "l2_reward_events" do
    field(:hash, Hash.Full, primary_key: true)
    field(:log_index, :integer, primary_key: true)
    field(:block_number, :integer)
    field(:validator_hash, Hash.Address, primary_key: true)
    field(:action_type, :integer)
    field(:amount, Wei)
    field(:block_timestamp, :utc_datetime_usec)
    field(:caller_hash, Hash.Address)
    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:hash, :log_index])
  end

end
