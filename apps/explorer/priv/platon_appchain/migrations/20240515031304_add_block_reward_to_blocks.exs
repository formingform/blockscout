defmodule Explorer.Repo.PlatonAppchain.Migrations.AddBlockRewardToBlocks do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:block_reward, :numeric, precision: 100, null: false)
    end
  end
end
