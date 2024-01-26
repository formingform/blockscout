defmodule Explorer.Chain.PlatonAppchain.Commitment do
  use Explorer.Schema

  alias Explorer.Chain.{
    Hash,
    Block
    }
  @optional_attrs ~w()a

  @required_attrs ~w(start_end_Id state_batch_hash state_root start_id end_id tx_number from to block_number block_timestamp)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `start_end_Id` - （start_id+ end_id）组合id
  * `state_batch_hash` - 批次交易hash
  * `state_root` - 批次state root
  * `start_id` - 批次起始event id
  * `end_id` - 批次结束event id
  * `tx_number` - 批次总交易数（endId-startId+1）
  * `from` - 批次交易发起者
  * `to` - 批次交易接收者
  * `block_number` - 批次交易所在区块
  * `block_timestamp` - 批次交易所在区块时间戳
  """
  @type t :: %__MODULE__{
               state_batch_hash:  Hash.t(),
               state_root:  Hash.t(),
               start_id:  non_neg_integer(),
               end_id: non_neg_integer(),
               tx_number: non_neg_integer(),
               from:  Hash.Address.t(),
               to:  Hash.Address.t(),
               block_number:  Block.block_number(),
               block_timestamp:  non_neg_integer() | nil,
             }

  @primary_key false
  schema "commitments" do
    field(:state_batch_hash, Hash.Full, primary_key: true)
    field(:state_root, Hash.Full)
    field(:start_id, :integer)
    field(:end_id, :integer)
    field(:tx_number, :integer)
    field(:from, Hash.Address)
    field(:to, Hash.Address)
    field(:block_number, :integer)
    field(:block_timestamp, :integer)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> validate_required(@required_attrs)
    |> unique_constraint(:state_batch_hash)
  end

end
