defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateCheckPoints do
  use Ecto.Migration

  def change do
    create table(:checkpoints, primary_key: false) do
      # check point 周期
      add(:epoch, :bigint, null: false, primary_key: true)
      # check point 周期 对应截止块高
      add(:block_number, :bigint, null: false)
      # （l2_block_start +l2_block_end）组合id
      add(:end_block_number, :bigint, null: false)
      # event_root
      add(:event_root, :bytea, null: false)
      # checkpoint总包含的事件数（另起线程统计l2_events中数据）
      add(:event_counts, :integer, null: false)
      # 交易所在L1区块
      add(:l1_block_number, :bigint, null: false)
      # checkpoint 批次在L1上的hash
      add(:l1_transaction_hash, :bytea, null: false)
      # checkpoint交易所在L1交易时间
      add(:block_timestamp, :utc_datetime_usec, null: false)

      #record timestamp
      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
