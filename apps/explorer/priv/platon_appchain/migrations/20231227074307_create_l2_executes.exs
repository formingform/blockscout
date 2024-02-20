defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2TxExecutes do
  use Ecto.Migration

  # 是指L2通过监控L1上的某些事件，并在L2上执行相应业务处理
  def change do
    create table(:l2_executes, primary_key: false) do
      # 交易计数器 msgId
      add(:event_id, :bigint, null: false, primary_key: true)
      # l2上交易hash
      add(:hash, :bytea, null: false)
      # 交易所在区块
      add(:block_number, :integer, null: false)
      # 关联commitments.hash
      add(:commitment_hash, :bytea, null: false)
      # 回放状态(业务状态) 0-未知 1-成功 2-失败 后续调合约确认哪值表示成功
      add(:replay_status, :integer, null: true)
      # 交易状态:1 成， 0 失败；和ether的tx.status保持一致。
      add(:status, :integer, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
