defmodule Commands.Miscellaneous do
  require Logger
  alias Nostrum.Api

  def howgay(%{msg: msg, args: _args}) do
     gay = :rand.uniform(100)
     Nostrum.Api.Message.create(
    msg.channel_id,
    content: "You are #{gay}% gay :rainbow:",
    message_reference: %{message_id: msg.id}
)
  end




end
