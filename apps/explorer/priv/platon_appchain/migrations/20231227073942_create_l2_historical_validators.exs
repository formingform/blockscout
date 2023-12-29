defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2HistoricalValidators do
  use Ecto.Migration
  def change do
    create table(:l2_historical_validators, primary_key: false) do
      # 验证人地址
      add(:validator_hash, :bytea, null: false, primary_key: true)
      # 质押成为验证人的epoch
      add(:stake_epoch, :bigint, null: false)
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
      # 验证人owner地址
      add(:owner_hash, :bytea, null: false)
      # 委托分红比例，万分之一单位
      add(:commission_rate, :integer, null: true)
      # 总权重(总质押+总委托)
      add(:total_bonded, :numeric, precision: 100, null: false)
      # 总委托
      add(:total_delegation, :numeric, precision: 100, null: false)
      # 总质押
      add(:self_stakes, :numeric, precision: 100, null: false)
      # 解质押中（锁定期）
      add(:freezing_states, :numeric, precision: 100, null: false)
      # 解质押待提取
      add(:pending_withdrawal_stakes, :numeric, precision: 100, null: false)
      # 验证人可领取奖励（出块与质押）
      add(:validator_reward, :numeric, precision: 100, null: false)
      # 委托奖励
      add(:delegator_reward, :numeric, precision: 100, null: false, default: 0)
      # 预估年收益率，万分之一单位
      add(:expect_apr, :numeric, precision: 100, null: true)
      # 最近24小时出块率，万分之一单位
      add(:block_rate, :numeric, precision: 100, null: true)
      # 是否验证 0-未验证，1-已验证
      add(:auth_status, :integer, null: false)
      # 0-Active（201） 1- Verifying（43） 2-candidate（201之外的质押用户）
      add(:status, :integer, null: false)
      # 当前结算周期(根据这个周期去查询合约)
      add(:epoch, :bigint, null: false)
      # 当前共识周期
      add(:round, :bigint, null: false)
      # 出块总数
      add(:blocks, :bigint, null: false)
      # 退出区块
      add(:quit_block_number, :bigint, null: false)
      # 退出内容
      add(:quit_event, :string, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
