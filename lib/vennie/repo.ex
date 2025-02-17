defmodule Vennie.Repo do
  use Ecto.Repo,
    otp_app: :vennie,
    adapter: Ecto.Adapters.SQLite3
end

