defmodule Explorer.Chain.PlatonAppchain.L2BlockProducedStatistic do
  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  # alias Ecto.Changeset
  alias Explorer.{
    Chain,
    Repo
    }

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @optional_attrs ~w()a

  @required_attrs ~w(validator_hash round should_blocks actual_blocks)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
      # 验证人地址, validator_hash
      add(:validator_hash, :bytea, null: false, primary_key: true)
      # l2上的round
      add(:round, :bigint, null: false, primary_key: true)
      # 应当出块数
      add(:should_blocks, :bigint, null: false, default: 0)
      # 实际出块数
      add(:actual_blocks, :bigint, null: false, default: 0)
  """
  @type t :: %__MODULE__{
               validator_hash:  Hash.Address.t(),
               round: non_neg_integer(),
               should_blocks:  non_neg_integer(),
               actual_blocks: non_neg_integer(),
             }

  @primary_key false
  schema "l2_block_produced_statistics" do
    field(:validator_hash, Hash.Address, primary_key: true)
    field(:round, :integer, primary_key: true)
    field(:should_blocks, :integer)
    field(:actual_blocks, :integer)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)  # 确保@allowed_attrs中指定的key才会赋值到结构体中
    |> validate_required(@required_attrs)
    |> unique_constraint(:validator_hash, :round)
  end
end
