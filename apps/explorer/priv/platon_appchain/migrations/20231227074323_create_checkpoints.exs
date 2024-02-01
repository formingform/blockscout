defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateCheckPoints do
  use Ecto.Migration

  def change do
    create table(:checkpoints, primary_key: false) do
      # l2上的epoch，一个epoch结束块高生成一个checkpoint
      add(:epoch, :bigint, null: false, primary_key: true)
      # checkpoint收集的事件的L2开始块高（epoch开始的前3个块高）
      add(:start_block_number, :bigint, null: false)
      # checkpoint收集事件的l2上截至块高（epoch结束的前3个块高）
      add(:end_block_number, :bigint, null: false)
      # event_root
      add(:event_root, :bytea, null: false)
      # checkpoint中包含的事件数（另起线程统计l2_events中数据，缺省就是null, 如果是null表示还没有统计。)
      add(:event_counts, :integer, null: true)
      # 交易所在L1区块
      add(:block_number, :bigint, null: false)
      # checkpoint 批次在L1上的hash
      add(:hash, :bytea, null: false)
      # checkpoint交易所在L1交易时间
      add(:block_timestamp, :utc_datetime_usec, null: false)

      #record timestamp
      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
