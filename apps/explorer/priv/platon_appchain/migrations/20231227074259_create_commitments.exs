defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateCommitments do
  use Ecto.Migration

  def change do
    create table(:commitments, primary_key: false) do
      # 批次state root
      add(:state_root, :bytea, null: false, primary_key: true)
      # 交易hash
      add(:hash, :bytea, null: false)
      # 交易所在区块
      add(:block_number, :bigint, null: false)
      # 批次起始msgId
      add(:start_id, :integer, null: false)
      # 批次结束msgId
      add(:end_id, :integer, null: false)
      # 批次总交易数（endId-startId+1）
      add(:tx_number, :integer, null: false)
      # 批次交易发起者
      add(:from, :bytea, null: false)
      # 交易时间
      add(:block_timestamp, :bigint, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
