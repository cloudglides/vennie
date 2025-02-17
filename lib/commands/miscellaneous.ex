defmodule Commands.Miscellaneous do
  require Logger
  alias Nostrum.Api
  alias Vennie.Repo
  alias Vennie.HowGay
  import Ecto.Query

  def howgay(%{msg: msg, args: _args}) do
    query = from(h in HowGay, where: h.user_id == ^msg.author.id, limit: 1)
    
    case Repo.one(query) do
      nil ->
        # No record exists; generate a new random percentage and store it.
        gay = :rand.uniform(100)
        Repo.insert!(%HowGay{user_id: msg.author.id, howgay_percentage: gay})
        Api.Message.create(
          msg.channel_id,
          content: "You are #{gay}% gay :rainbow:",
          message_reference: %{message_id: msg.id}
        )
        
      record ->
        # Record exists; use the stored value.
        Api.Message.create(
          msg.channel_id,
          content: "You are #{record.howgay_percentage}% gay :rainbow:",
          message_reference: %{message_id: msg.id}
        )
    end
  end
end

