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
        gay = :rand.uniform(100)
        Repo.insert!(%HowGay{user_id: msg.author.id, howgay_percentage: gay})
        Api.Message.create(
          msg.channel_id,
          content: "You are #{gay}% dumb <:dumb:1342556626351161516>",
          message_reference: %{message_id: msg.id}
        )
        
      record ->
       Api.Message.create(
          msg.channel_id,
          content: "You are #{record.howgay_percentage}% dumb <:dumb:1342556626351161516>",
          message_reference: %{message_id: msg.id}
        )
    end
  end
end

