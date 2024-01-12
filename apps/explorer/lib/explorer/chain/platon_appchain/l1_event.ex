defmodule Explorer.Chain.PlatonAppchain.L1Event do
  use Explorer.Schema

  # alias Ecto.Changeset
  alias Explorer.{
    Chain,
    PagingOptions
    }

  alias Explorer.Chain.{
    Hash,
    Block
    }

  @optional_attrs ~w(amount block_timestamp validator)a

  @required_attrs ~w(event_Id tx_type hash from to block_number)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `event_Id` - msgId
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
               event_Id: non_neg_integer(),
               tx_type:  String.t(),
               amount:  non_neg_integer() | nil,
               hash:  Hash.t(),
               from:  Hash.Address.t(),
               to:  Hash.Address.t(),
               block_number:  Block.block_number(),
               block_timestamp:  non_neg_integer() | nil,
               validator: Hash.Address.t() | nil,
             }

  @primary_key {:hash, Hash, autogenerate: false}
  schema "l1_events" do
    field(:event_Id, :integer)
    field(:tx_type, :string)
    field(:amount, :integer)
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
