import Config

config :vennie,
  ecto_repos: [Vennie.Repo]

config :vennie, Vennie.Repo,
  database: "priv/repo/vennie.sqlite3",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

if config_env() in [:dev, :test] do
  for path <- [".env.exs", ".env.#{config_env()}.exs"] do
    path = Path.join(__DIR__, "..") |> Path.join("config") |> Path.join(path) |> Path.expand()
    if File.exists?(path), do: import_config(path)
  end
end

config :nostrum,
  token: System.get_env("TOKEN"), 
  gateway_intents: :all,
  force_http1: false,
  streamlink: false,
  youtubedl: false

