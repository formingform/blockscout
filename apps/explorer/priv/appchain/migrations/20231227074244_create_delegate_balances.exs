defmodule Explorer.Repo.Appchain.Migrations.CreateDelegateBalances do
  use Ecto.Migration

  def change do
    create table(:delegate_balances, primary_key: false) do
      # 委托人地址
      add(:delegator_hash, :bytea, null: false)
      # 验证人地址
      add(:validator_hash, :bytea, null: false)
      # 委托金额
      add(:delegate_amount, :numeric, precision: 100, null: false)
      # 无效委托金额
      add(:invalid_delegate_amount, :numeric, precision: 100, null: false)
      # 解委托-锁定中的数量
      add(:unbonding_delegate_amount, :numeric, precision: 100, null: false)
      # 已解锁-可以提取的数量
      add(:pending_withdrawal_amount, :numeric, precision: 100, null: false)
      # 可以领取的奖励
      add(:claimable_reward_amount, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
