import Config


if config_env() in [:dev, :test] do
  for path <- [".env.exs", ".env.#{config_env()}.exs"] do
    path = Path.join(__DIR__, "..") |> Path.join("config") |> Path.join(path) |> Path.expand()
    if File.exists?(path), do: import_config(path)
  end
end

config :nostrum,
  token: System.get_env("TOKEN"), 
  gateway_intents: :all,
  ws_heartbeat_interval: 5_000,  # 30 seconds
  await_guild_timeout: 30_000,
  force_http1: false,
  streamlink: false,
  youtubedl: false




