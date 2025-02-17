defmodule Vennie.Ban do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bans" do
    field :user_id, :integer
    field :ban_reason, :string

    timestamps()
  end

  def changeset(ban, attrs) do
    ban
    |> cast(attrs, [:user_id, :ban_reason])
    |> validate_required([:user_id, :ban_reason])
  end
end

