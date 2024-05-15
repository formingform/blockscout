defmodule Explorer.Chain.PlatonAppchain.L2ValidatorEvent do
  use Explorer.Schema

  alias Explorer.Chain.{
    Hash,
    Block,
    Wei
    }

  import Explorer.Chain, only: [select_repo: 1]

  @optional_attrs ~w(action_desc amount delegator_hash)a

  @required_attrs ~w(hash log_index block_number epoch validator_hash action_type block_timestamp)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `validator_hash` - 验证人地址
  * `action_type` - 事件类型 事件类型：1.质押 2增加质押 3.修改节点拥金比例 4.解质押  5.解委托 6.提取质押 7. 提取委托 8.零出块处罚  9.治理事件
  * `action_desc` - 事件描述
  * `amount` - 事件涉及金额
  * `block_number` - 事件发生块高
  * `epoch` - 事件发生epoch
  * `block_timestamp` - 交易所在区块时间戳
  * `log_index` - 日志索引
  * `hash` - 事件所在交易hash
  * `delegator_hash` - 委托人地址
  """
  @type t :: %__MODULE__{
               hash: Hash.t(),
               log_index: non_neg_integer(),
               block_number: Block.block_number(),
               epoch: non_neg_integer,
               validator_hash: Hash.Address.t(),
               action_type: non_neg_integer(),
               action_desc: String.t() | nil,
               amount: Wei.t() | nil,
               block_timestamp: DateTime.t() | nil,
               delegator_hash: Hash.Address.t(),
             }

  @primary_key false
  schema "l2_validator_events" do
    field(:hash, Hash.Full, primary_key: true)
    field(:log_index, :integer, primary_key: true)
    field(:block_number, :integer)
    field(:epoch, :integer)
    field(:validator_hash, Hash.Address)
    field(:action_type, :integer)
    field(:action_desc, :string)
    field(:amount, Wei)
    field(:block_timestamp, :utc_datetime_usec)
    field(:delegator_hash, Hash.Address)
    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:hash, :log_index, :validator_hash])
  end

  @spec get_undelegate_events_by_epoch_range(integer(), integer()) :: list()
  def get_undelegate_events_by_epoch_range(epoch_start, epoch_end, options \\ []) do
    base_query =
      from(
        v in __MODULE__,
        select: %{
          hash: v.hash,
          log_index: v.log_index,
          block_number: v.block_number,
          epoch: v.epoch,
          validator_hash: v.validator_hash,
          action_type: v.action_type,
          action_desc: v.action_desc,
          amount: v.amount,
          block_timestamp: v.block_timestamp,
          delegator_hash: v.delegator_hash,
          inserted_at: v.inserted_at,
          updated_at: v.updated_at},
        where: v.epoch >= ^epoch_start and v.epoch<= ^epoch_end
      )

    base_query
    |> select_repo(options).all()
  end
end
