defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateDailyStatic do
  use Ecto.Migration

  def change do
    create table(:daily_static, primary_key: false) do
      # 统计日期
      add(:static_date, :string, null: false, primary_key: true )
      # 总验证人数(活跃与候选节点)
      add(:total_validator_size, :integer, null: false)
      # 有效总质押量（不包含解质押或解委托的）
      add(:total_bonded, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
