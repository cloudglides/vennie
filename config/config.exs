import Config

config :nostrum,
  token: System.get_env("TOKEN"), 
  gateway_intents: :all,
  streamlink: false,
  youtubedl: false




