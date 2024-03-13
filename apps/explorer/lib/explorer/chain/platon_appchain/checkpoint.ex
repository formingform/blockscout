defmodule Explorer.Chain.PlatonAppchain.Checkpoint do
  use Explorer.Schema

  alias Explorer.Chain.{
    Hash,
    Block,
    Data
    }
  @optional_attrs ~w(from tx_fee)a

  @required_attrs ~w(epoch start_block_number end_block_number state_root event_counts block_number hash block_timestamp)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `epoch` - l2上的epoch
  * `start_block_number` - checkpoint收集的事件的L2开始块高（epoch开始的前3个块高）
  * `end_block_number` - checkpoint收集事件的l2上截至块高（epoch结束的前3个块高）
  * `state_root` - state root
  * `event_counts` - checkpoint总包含的事件数（另起线程统计l2_events中数据）
  * `block_number` - 交易所在L1区块
  * `hash` - checkpoint交易在L1上的hash
  * `block_timestamp` - checkpoint交易所在L1交易时间
  * `from` - 交易发起者
  * `tx_fee` - 交易手序费
  """
  @type t :: %__MODULE__{
               epoch: non_neg_integer(),
               start_block_number:  Block.block_number(),
               end_block_number:  Block.block_number(),
               state_root:  Data.t(),
               event_counts: non_neg_integer(),
               block_number: Block.block_number(),
               hash: Hash.t(),
               block_timestamp: DateTime.t() | nil,
               from:  Hash.Address.t(),
               tx_fee: Gas.t() | nil,
             }

  @primary_key false
  schema "checkpoints" do
    field(:epoch, :integer, primary_key: true)
    field(:start_block_number, :integer)
    field(:end_block_number, :integer)
    field(:state_root, Data)
    field(:event_counts, :integer)
    field(:block_number, :integer)
    field(:hash, Hash.Full)
    field(:block_timestamp, :utc_datetime_usec)
    field(:from, Hash.Address)
    field(:tx_fee, :decimal)

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
