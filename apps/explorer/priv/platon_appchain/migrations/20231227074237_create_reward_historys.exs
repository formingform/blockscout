defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateRewardHistorys do
  use Ecto.Migration

  def change do
    create table(:reward_history, primary_key: false) do
      # 验证人地址
      add(:validator_hash, :bytea, null: false)
      # 领到奖励金额
      add(:draw_amount, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
