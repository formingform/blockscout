defmodule Explorer.Chain.PlatonAppchain.Checkpoint do
  use Explorer.Schema

  alias Explorer.Chain.{
    Hash,
    Block
    }
  @optional_attrs ~w()a

  @required_attrs ~w(epoch start_block_number end_block_number event_root event_counts l1_block_number l1_transaction_hash l1_block_timestamp)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `epoch` - l2上的epoch
  * `start_block_number` - checkpoint收集的事件的L2开始块高（epoch开始的前3个块高）
  * `end_block_number` - checkpoint收集事件的l2上截至块高（epoch结束的前3个块高）
  * `event_root` - event root
  * `event_counts` - checkpoint总包含的事件数（另起线程统计l2_events中数据）
  * `l1_block_number` - 交易所在L1区块
  * `l1_transaction_hash` - checkpoint交易在L1上的hash
  * `l1_block_timestamp` - checkpoint交易所在L1交易时间
  """
  @type t :: %__MODULE__{
               epoch: non_neg_integer(),
               start_block_number:  Block.block_number(),
               end_block_number:  Block.block_number(),
               event_root:  Hash.t(),
               event_counts: non_neg_integer(),
               l1_block_number: Block.block_number(),
               l1_transaction_hash:  Hash.t(),
               l1_block_timestamp:  non_neg_integer(),
               block_number:  Block.block_number(),
               block_timestamp:  non_neg_integer(),
             }

  @primary_key {:epoch, :integer, autogenerate: false}
  schema "checkpoints" do
#    field(:epoch, :integer)
    field(:start_block_number, :integer)
    field(:end_block_number, :integer)
    field(:event_root, Hash.Full)
    field(:event_counts, :integer)
    field(:l1_block_number, :integer)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_block_timestamp, :integer)
    field(:block_number, :integer)
    field(:block_timestamp, :integer)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> validate_required(@required_attrs)
    |> unique_constraint(:epoch)
  end

end
