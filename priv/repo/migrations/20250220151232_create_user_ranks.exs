defmodule Vennie.Repo.Migrations.CreateUserRanks do
  use Ecto.Migration

  def change do
    create table(:user_ranks) do
      add :user_id, :bigint, null: false
      add :xp, :integer, default: 0
      add :level, :integer, default: 0
      add :last_message_at, :utc_datetime
      add :daily_xp, :integer, default: 0
      add :daily_xp_reset_at, :utc_datetime

      timestamps()
    end

    create unique_index(:user_ranks, [:user_id])
  end
end
