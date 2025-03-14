defmodule Vennie.Ban do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bans" do
    field(:user_id, :integer)
    field(:ban_reason, :string)
    field(:banned_by, :integer)
    field(:banned_at, :utc_datetime)

    timestamps()
  end

  def changeset(ban, attrs) do
    ban
    |> cast(attrs, [:user_id, :ban_reason, :banned_by, :banned_at])
    |> validate_required([:user_id, :ban_reason, :banned_by, :banned_at])
  end
end
