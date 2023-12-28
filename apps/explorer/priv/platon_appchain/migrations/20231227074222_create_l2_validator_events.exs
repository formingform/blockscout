defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2ValidatorEvents do
  use Ecto.Migration

  def change do
    create table(:l2_validator_events, primary_key: false) do
      # 验证人地址
      add(:validator_hash, :bytea, null: false)
      # 事件所在区块
      add(:number, :bigint, null: false)
      # 事件所在交易hash
      add(:hash, :bytea, null: false, primary_key: true)
      # 事件类型：1.质押 2增加质押 3.修改节点拥金比例 4.解质押  5.零出块处罚  6.治理事件
      add(:action_type, :integer, null: true)
      # 事件描述
      add(:action_desc, :string, null: true)
      # 金额(增加/减少用负数表示)
      add(:amount, :numeric, precision: 100, null: false)
      # 交易时间
      add(:tx_at, :utc_datetime_usec, default: fragment("NULL"), null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
