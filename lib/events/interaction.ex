defmodule Vennie.Events.Interaction do
  require Logger
  alias Nostrum.Api

  def interaction_create(msg) do
    embed_list = ["embed_1", "embed_2", "embed_3"]

    userid = HandleOp.get_userid(msg.message.id)
    current_embed = HandleOp.get_embed(msg.message.id) || "embed_1"

    index = Enum.find_index(embed_list, fn e -> e == current_embed end)

    cond do
      msg.member.user_id != userid ->
        Api.Interaction.create_response(msg, %{
          type: 4,
          data: %{
            content: "Run your help command again, you can't interact with this one.",
            flags: 64
          }
        })

      msg.data.custom_id == "right" ->
        if index < length(embed_list) - 1 do
          new_embed = Enum.at(embed_list, index + 1)
          HandleOp.store_message(userid, msg.message.id, new_embed)
          Api.Message.edit(msg.channel_id, msg.message.id, embeds: [get_embed_struct(new_embed)])
        else
          Api.Interaction.create_response(msg, %{
            type: 4,
            data: %{content: "Can't move right!", flags: 64}
          })
        end

        # Acknowledge interaction
        Api.Interaction.create_response(msg, %{type: 6})

      msg.data.custom_id == "left" ->
        if index > 0 do
          new_embed = Enum.at(embed_list, index - 1)
          HandleOp.store_message(userid, msg.message.id, new_embed)
          Api.Message.edit(msg.channel_id, msg.message.id, embeds: [get_embed_struct(new_embed)])
        else
          Api.Interaction.create_response(msg, %{
            type: 4,
            data: %{content: "Can't move left!", flags: 64}
          })
        end

        # Acknowledge interaction
        Api.Interaction.create_response(msg, %{type: 6})

      true ->
        # Acknowledge any unexpected interactions
        Api.Interaction.create_response(msg, %{type: 6})
    end
  end

  defp get_embed_struct("embed_1") do
    %Nostrum.Struct.Embed{}
    |> Nostrum.Struct.Embed.put_title("Help Command")
    |> Nostrum.Struct.Embed.put_description(
      "List of available commands for this bot.\n\nPrefix: v or V"
    )
    |> Nostrum.Struct.Embed.put_color(0x808080)
    |> Nostrum.Struct.Embed.put_field("help/h", "Shows this help command.")
  end

  defp get_embed_struct("embed_2") do
    %Nostrum.Struct.Embed{}
    |> Nostrum.Struct.Embed.put_title("Mod Commands")
    |> Nostrum.Struct.Embed.put_color(0x808080)
    |> Nostrum.Struct.Embed.put_field("mute/m", "Mutes a user.")
    |> Nostrum.Struct.Embed.put_field("unban/ub", "Unbans a user.")
    |> Nostrum.Struct.Embed.put_field("lock/l", "Locks the current thread.")
    |> Nostrum.Struct.Embed.put_field("kick/k", "Kicks a user from the server.")
    |> Nostrum.Struct.Embed.put_field("ban/b", "Bans a user.")
    |> Nostrum.Struct.Embed.put_field("websocket/ws", "Shows the current WebSocket details.")
  end

  defp get_embed_struct("embed_3") do
    %Nostrum.Struct.Embed{}
    |> Nostrum.Struct.Embed.put_title("Misc Commands")
    |> Nostrum.Struct.Embed.put_color(0x808080)
    |> Nostrum.Struct.Embed.put_field("howdumb/hd", "Gives a percentage of how dumb you are.")
    |> Nostrum.Struct.Embed.put_field("rank/r", "Displays your rank details.")
    |> Nostrum.Struct.Embed.put_field("whyban/wb", "States the reason for a user's ban.")
  end
end

