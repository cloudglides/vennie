defmodule Vennie.Repo.Migrations.CreateBansAndHowGay do
  use Ecto.Migration

  def change do
    create table(:bans) do
      add :user_id, :bigint, null: false
      add :ban_reason, :text, null: false

      timestamps()
    end

    create table(:howgay) do
      add :user_id, :bigint, null: false
      add :howgay_percentage, :integer, null: false

      timestamps()
    end

    create unique_index(:howgay, [:user_id])
  end
end

