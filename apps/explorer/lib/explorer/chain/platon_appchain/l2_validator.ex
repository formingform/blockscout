defmodule Explorer.Chain.PlatonAppchain.L2Validator do
  @moduledoc "Models PlatonAppchain L2Validator."

  use Explorer.Schema
  alias Explorer.PagingOptions
  alias Explorer.Chain.Wei

  @optional_attrs ~w(name detail logo_url web_site freezing_stakes pending_withdrawal_stakes validator_reward delegator_reward expect_apr block_rate auth_status epoch round blocks)a

  @required_attrs ~w(validator_hash stake_epoch owner_hash total_bonded total_delegation self_stakes commission status)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `msg_id` - id of the message
  * `from` - source address of the message
  * `to` - target address of the message
  * `l1_transaction_hash` - hash of the L1 transaction containing the corresponding StateSynced event
  * `l1_timestamp` - timestamp of the L1 transaction block
  * `l1_block_number` - block number of the L1 transaction
  """
  @type t :: %__MODULE__{
               validator_hash: Hash.Address.t(),
               stake_epoch: non_neg_integer(),
               rank: non_neg_integer(),
               name: String.t(),
               detail: String.t(),
               logo_url: String.t(),
               web_site: String.t(),
               owner_hash: Hash.Address.t(),
               commission_rate: non_neg_integer(),
               total_bonded: Wei.t(),
               total_delegation: Wei.t(),
               self_stakes: Wei.t(),
               freezing_stakes: Wei.t(),
               pending_withdrawal_stakes: Wei.t(),
               validator_reward: Wei.t(),
               delegator_reward: Wei.t(),
               expect_apr: non_neg_integer(),
               block_rate: non_neg_integer(),
               auth_status: boolean(),
               status: non_neg_integer(),
               epoch: non_neg_integer(),
               round: non_neg_integer(),
               blocks: non_neg_integer(),
             }

  @primary_key false
  schema "l2validator" do
    field(:validator_hash, Hash.Address, primary_key: true) #验证人地址，主键
    field(:stake_epoch, :integer) #质押成为验证人的epoch
    field(:rank, :integer)  #排序序号（就是从底层获取验证人列表的列表序号）
    field(:name, :string) #名称
    field(:detail, :string)  #描述
    field(:logo_url, :string) #logo url
    field(:web_site, :string) #website url
    field(:owner_hash, Hash.Address) #owner地址
    field(:commission_rate, :integer) #收益分配比例，万分之一单位
    field(:total_bonded, Wei) #总有效权重(总有效质押+总有效委托)
    field(:total_delegation, Wei) #总有效委托
    field(:self_stakes, Wei) #总有效质押
    field(:freezing_stakes, Wei) #解质押中（锁定期）
    field(:pending_withdrawal_stakes, Wei) ## 解质押待提取（锁定结束）
    field(:validator_reward, Wei) ## 验证人可领取奖励（出块与质押）
    field(:delegator_reward, Wei) ## 委托奖励
    field(:expect_apr, :integer) # 年化收益率，万分之一单位
    field(:block_rate, :integer) # 出块率，万分之一单位
    field(:auth_status, :integer) #是否验证 0-未验证，1-已验证
    field(:status, :integer) #0-Active（201） 1- Verifying（43） 2-candidate（201之外的质押用户）
    field(:epoch, :integer)  # 当前结算周期(根据这个周期去查询合约)
    field(:round, :integer) #接受的委托数量
    field(:blocks, :integer)  # 总出块数
    #field(:claimable_rewards, Wei) #可领取的奖励
    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address_hash)
  end
end
