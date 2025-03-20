defmodule Vennie.Application do
  use Application

  @impl true
  def start(_type, _args) do
     Vennie.EmojiCache.init()
    bot_options = %{
      consumer: Vennie.Consumer,
      intents: :all,
      wrapped_token: fn -> System.fetch_env!("BOT_TOKEN") end
    }

    children = [
      {Nostrum.Bot, bot_options},
      Vennie.Repo,
      Commands.Music,
      HandleOp,
      Vennie.MessageCache,
      Vennie.DeletedMessageStore,
      {Bandit, plug: Vennie.Router, scheme: :http, port: 3333}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
