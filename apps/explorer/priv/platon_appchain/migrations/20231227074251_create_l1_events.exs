defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL1Txs do
  use Ecto.Migration

  def change do
    create table(:l1_events, primary_key: false) do
      # 交易计数器 msgId
      add(:event_id, :bigint, null: false, primary_key: true)
      # 与tx表中一致（待定具体类型值）
      add(:tx_type, :integer, null: false)
      # 金额（不同的tx_type可能有不同的值
      add(:amount, :numeric, precision: 100, null: true)
      # l1上交易hash
      add(:hash, :bytea, null: false)
      # 交易发起者
      add(:from, :bytea, null: false)
      # 交易接收者(l1上面接收合约)
      add(:to, :bytea, null: false)
      # 交易所在区块
      add(:block_number, :bigint, null: false)
      # 交易时间 客户端算根据此值计算（age）
      add(:block_timestamp, :"timestamp without time zone", null: true)
      #  质押 委托对应L2上面验证人地址（如果是其它交易有可能没有值）
      add(:validator, :bytea, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
