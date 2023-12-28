defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2Validators do
  use Ecto.Migration

  def change do
    create table(:l2_validators, primary_key: false) do
      # 排名
      add(:rank, :integer, null: false)
      # 验证人名称
      add(:name, :string, null: true)
      # 验证人描述信息
      add(:detail, :string, null: true)
      # 节点logo
      add(:logo, :text, null: true)
      # 验证人官方网站
      add(:website, :string, null: true)
      # 验证人地址
      add(:validator_hash, :bytea, null: false, primary_key: true)
      # 验证人owner地址
      add(:owner_hash, :bytea, null: false)
      # 拥金比例
      add(:commission, :integer, null: true)
      # 自有质押
      add(:self_bonded, :numeric, precision: 100, null: false)
      # 解质押中（锁定期）
      add(:unbondeding, :numeric, precision: 100, null: false)
      # 解质押待提取
      add(:pending_withdrawal_bonded, :numeric, precision: 100, null: false)
      # 有效委托
      add(:total_delegation, :numeric, precision: 100, null: false)
      # 验证人可领取奖励（出块与质押）
      add(:validator_reward, :numeric, precision: 100, null: false)
      # 委托奖励
      add(:delegator_reward, :numeric, precision: 100, null: false, default: 0)
      # 预估年收益率
      add(:expect_apr, :numeric, precision: 100, null: true)
      # 最近24小时出块率
      add(:block_rate, :numeric, precision: 100, null: true)
      # 是否验证 0-未验证，1-已验证
      add(:auth_status, :integer, null: false)
      # 0-Active 1- Verifying 2-candidate
      add(:status, :integer, null: false)
      # 质押成为验证人的epoch
      add(:stake_epoch, :numeric, precision: 100, null: false)
      # 当前结算周期(根据这个周期去查询合约)
      add(:epoch, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
