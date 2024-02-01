defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL1TxExecutes do
  use Ecto.Migration

  def change do
    create table(:l1_executes, primary_key: false) do
      # 交易计数器 msgId
      add(:event_id, :bigint, null: false, primary_key: true)
      # 与tx表中一致（待定具体类型值）
      add(:tx_type, :integer, null: false)
      # 金额（不同的tx_type可能有不同的值
      add(:amount, :numeric, precision: 100, null: true)
      # l1上交易hash
      add(:hash, :bytea, null: false)
      # L1交易checkpoint批次提交hash（目前做关联checkpoints的l1_transaction_hash字段用，后续看是否删除）
      add(:state_batch_hash, :bytea, null: false)
      # 回放状态(业务状态，只有用户手工操作后，吐出事件才会更新) 0-未知 1-成功 2-失败 后续调合约确认哪值表示成功
      add(:replay_status, :integer, null: true)
      # 交易状态
      add(:status, :integer, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
