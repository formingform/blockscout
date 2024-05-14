defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2ValidatorEvents do
  use Ecto.Migration

  # 是指L2上发生的和validator有关的所有业务事件
  def change do
    create table(:l2_validator_events, primary_key: false) do
      # 事件所在交易hash
      add(:hash, :bytea, null: false, primary_key: true )
      # 日志索引,
      add(:log_index, :integer, null: false, primary_key: true)
      # 事件所在区块
      add(:block_number, :bigint, null: false)
      # 事件所在epoch
      add(:epoch, :bigint, null: false)
      # 验证人地址
      add(:validator_hash, :bytea, null: false, primary_key: true)
      # 事件类型：1.质押 2增加质押 3.修改节点拥金比例 4.解质押  5.解委托 6.提取质押 7. 提取委托 8.零出块处罚  9.治理事件
      add(:action_type, :integer, null: true)
      # 事件描述
      add(:action_desc, :string, null: true)
      # 金额(增加/减少用负数表示)
      add(:amount, :numeric, precision: 100, null: false)
      # 委托人地址
      add(:delegator_hash, :bytea, null: true)
      # 交易时间
      add(:block_timestamp, :"timestamp without time zone", null: true)
      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
