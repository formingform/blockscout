defmodule Explorer.Chain.PlatonAppchain.L2Execute do
  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @optional_attrs ~w(replay_status)a

  @required_attrs ~w(event_id hash block_number status)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `event_id` - event id
  * `hash` - l2上交易hash
  * `block_number` - l2批次交易所在区块
  * `commitment_hash` - commit事件的交易hash
  * `replay_status` - 回放状态(业务状态) 0-未知 1-成功 2-失败
  * `status` - L2上执行的最终状态
  """
  @type t :: %__MODULE__{
               event_id: non_neg_integer(),
               hash:  Hash.t(),
               block_number:  Block.block_number(),
               # commitment_hash:  Hash.t(),
               replay_status:  non_neg_integer() | nil,
               status:  non_neg_integer()
             }

  @primary_key false
  schema "l2_executes" do
    field(:event_id, :integer, primary_key: true)
    field(:hash, Hash.Full)
    field(:block_number, :integer)
    #field(:commitment_hash, Hash.Full)
    field(:replay_status, :integer)
    field(:status, :integer)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> validate_required(@required_attrs)
    |> unique_constraint(:event_id)
  end

end
