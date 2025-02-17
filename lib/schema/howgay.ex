defmodule Vennie.HowGay do
  use Ecto.Schema
  import Ecto.Changeset

  schema "howgay" do
    field :user_id, :integer
    field :howgay_percentage, :integer

    timestamps()
  end

  def changeset(howgay, attrs) do
    howgay
    |> cast(attrs, [:user_id, :howgay_percentage])
    |> validate_required([:user_id, :howgay_percentage])
    |> validate_number(:howgay_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end

