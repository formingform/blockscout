defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2Delegators do
  use Ecto.Migration

  def change do
    create table(:l2_delegators, primary_key: false) do
      # 委托人地址, delegator_hash
      add(:delegator_hash, :bytea, null: false, primary_key: true)
      # 验证人地址, validator_hash
      add(:validatorr_hash, :bytea, null: false, primary_key: true)
      # 有效委托金额
      add(:delegate_amount, :numeric, precision: 100, null: false, default: 0)
      # 锁定的委托金额
      add(:locking_delegate_amount, :numeric, precision: 100, null: false, default: 0)
      # 可提取的委托金额
      add(:withdrawal_delegate_amount, :numeric, precision: 100, null: false, default: 0)
      # 委托奖励
      add(:delegate_reward, :numeric, precision: 100, null: false, default: 0)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
