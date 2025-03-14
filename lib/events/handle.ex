defmodule Vennie.Events do
  require Logger
  alias Nostrum.Api
  def interaction(msg) do
    userid = HandleOp.get_userid(msg.message.id)
    cond do
      msg.data.custom_id == "trackmania_refresh" && msg.member.user_id == userid ->
        Api.Message.edit(msg.channel_id, msg.message.id, "hola")
        Api.Interaction.create_response(msg, %{type: 6})

      true -> 
        :ok 
    end
  end
end

