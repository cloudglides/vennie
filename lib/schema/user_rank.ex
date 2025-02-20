defmodule Vennie.UserRank do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_ranks" do
    field :user_id, :integer
    field :xp, :integer, default: 0
    field :level, :integer, default: 0
    field :last_message_at, :utc_datetime
    field :daily_xp, :integer, default: 0
    field :daily_xp_reset_at, :utc_datetime

    timestamps()
  end

  def changeset(user_rank, attrs) do
    user_rank
    |> cast(attrs, [:user_id, :xp, :level, :last_message_at, :daily_xp, :daily_xp_reset_at])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end
