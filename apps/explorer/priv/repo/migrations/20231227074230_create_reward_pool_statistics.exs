defmodule Explorer.Repo.Migrations.CreateRewardPoolStatistics do
  use Ecto.Migration

  def change do
    create table(:reward_pool_static, primary_key: false) do
      # 总质押（所有节点）
      add(:total_bonded, :numeric, precision: 100, null: false)
      # 总委托（所有节点）
      add(:total_delegation, :numeric, precision: 100, null: false)
      # Reward pool 激励池余额
      add(:reward_pool, :numeric, precision: 100, null: false)
      # 总发行量
      add(:total_supply, :numeric, precision: 100, null: false)
      # 总流通量
      add(:circulating, :numeric, precision: 100, null: false)
      # 总验证人数
      add(:total_validator, :integer, null: true)
      # 24小时增减的验证人数
      add(:change_validator, :integer, null: true)
      # 24小时增减的总质押量
      add(:change_bonded, :numeric, precision: 100, null: true)
      # 下个checkpoint批次所在区块
      add(:net_checkpoint_block, :bigint, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
