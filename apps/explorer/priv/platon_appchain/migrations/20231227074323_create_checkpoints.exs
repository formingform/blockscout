defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateCheckPoints do
  use Ecto.Migration

  def change do
    create table(:checkpoints, primary_key: false) do
      # （l2_block_start +l2_block_end）组合id
      add(:start_end_block, :string, null: false, primary_key: true)
      # 交易所在区块
      add(:l1_block_number, :bigint, null: false)
      # checkpoint 批次在L1上的hash
      add(:l1_transaction_hash, :bytea, null: false)
      # event_root
      add(:event_root, :bytea, null: false)
      # check point 周期
      add(:epoch, :bigint, null: false)
      # check point 周期 对应截止块高
      add(:block_number, :bigint, null: false)
      # checkpoint总交易数（根据事件中blockNumber推算出来）
      add(:tx_number, :integer, null: false)
      # checkpoint交易时间
      add(:block_timestamp, :utc_datetime_usec, null: false)
      # 0-waiting for state root 1-Ready for replay 2-Replayed（监听到事件应该批次处理成功了，所以目前应该只有2）
      add(:status, :integer, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
