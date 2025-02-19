defmodule Vennie.Repo.Migrations.CreateBansAndHowGay do
  use Ecto.Migration

  def change do
    create table(:bans) do
      add :user_id, :integer
      add :ban_reason, :string
      add :banned_by, :integer
      add :banned_at, :utc_datetime

      timestamps()
    end

    create index(:bans, [:user_id])

    create table(:howgay) do
      add :user_id, :bigint, null: false
      add :howgay_percentage, :integer, null: false

      timestamps()
    end

    create unique_index(:howgay, [:user_id])
  end
end

