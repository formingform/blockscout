defmodule Explorer.Chain.PlatonAppchain.L2ValidatorEvent do
  use Explorer.Schema

  alias Explorer.Chain.{
    Hash,
    Block,
    Wei
    }

  @optional_attrs ~w(action_desc amount)a

  @required_attrs ~w(validator_hash action_type block_number block_timestamp log_index hash)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `validator_hash` - 验证人地址
  * `action_type` - 事件类型 事件类型：1.质押 2增加质押 3.修改节点拥金比例 4.解质押  5.解委托 6.提取质押 7. 提取委托 8.零出块处罚  9.治理事件
  * `action_desc` - 事件描述
  * `amount` - 事件涉及金额
  * `block_number` - 事件发生块高
  * `block_timestamp` - 交易所在区块时间戳
  * `log_index` - 日志索引
  * `transaction_hash` - 事件所在交易hash
  """
  @type t :: %__MODULE__{
               validator_hash: Hash.Address.t(),
               action_type: non_neg_integer(),
               action_desc: String.t() | nil,
               amount: Wei.t() | nil,
               block_number: Block.block_number(),
               block_timestamp: non_neg_integer(),
               log_index: non_neg_integer(),
               hash: Hash.t(),
             }

  schema "l2_validator_events" do
    field(:validator_hash, Hash.Address)
    field(:action_type, :integer)
    field(:action_desc, :string)
    field(:amount, Wei)
    field(:block_number, :integer)
    field(:block_timestamp, :integer)
    field(:log_index, :integer)
    field(:hash, Hash.Full)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:block_number, :log_index)
  end

end
