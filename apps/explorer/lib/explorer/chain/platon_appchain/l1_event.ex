defmodule Explorer.Chain.PlatonAppchain.L1Event do
  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @optional_attrs ~w(amount validator)a

  @required_attrs ~w(event_id tx_type hash from to block_number block_timestamp)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `event_id` - event id
  * `tx_type` - 交易类型
  * `amount` - 交易数据amount参数
  * `hash` - l1上交易hash
  * `from` - 交易发起者
  * `to` - 交易接收者
  * `block_number` - 交易所在区块
  *  `block_timestamp` - 交易所在区块时间戳
  * `validator` - 质押/委托对应L2上面验证人地址（如果是其它交易有可能没有值）
  """
  @type t :: %__MODULE__{
               event_id: non_neg_integer(),
               tx_type:  non_neg_integer(),
               amount:  Wei.t() | nil,
               hash:  Hash.t(),
               from:  Hash.Address.t(),
               to:  Hash.Address.t(),
               block_number:  Block.block_number(),
               block_timestamp:  non_neg_integer() | nil,
               validator: Hash.Address.t() | nil,
             }

  @primary_key false
  schema "l1_events" do
    field(:event_id, :integer, primary_key: true)
    field(:tx_type, :integer)
    field(:amount, Wei)
    field(:hash, Hash.Full)
    field(:from, Hash.Address)
    field(:to, Hash.Address)
    field(:block_number, :integer)
    field(:block_timestamp, :integer)
    field(:validator, Hash.Address)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end

end
