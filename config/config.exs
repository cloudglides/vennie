import Config




config :vennie,
  ecto_repos: [Vennie.Repo]

config :vennie, Vennie.Repo,
  database: "priv/repo/vennie.sqlite3",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

