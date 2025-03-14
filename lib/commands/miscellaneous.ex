defmodule Commands.Miscellaneous do
  require Logger
  alias Nostrum.Api
  alias Vennie.Repo
  alias Vennie.HowGay
  import Ecto.Query
  import Nostrum.Struct.Embed

  {:ok, _pid} = HandleOp.start_link([])

  def howgay(%{msg: msg, args: _args}) do
    query = from(h in HowGay, where: h.user_id == ^msg.author.id, limit: 1)

    case Repo.one(query) do
      nil ->
        gay = :rand.uniform(100)
        Repo.insert!(%HowGay{user_id: msg.author.id, howgay_percentage: gay})

        Message.create(
          msg.channel_id,
          content: "You are #{gay}% dumb <:dumb:1342556626351161516>",
          message_reference: %{message_id: msg.id}
        )

      record ->
        Message.create(
          msg.channel_id,
          content: "You are #{record.howgay_percentage}% dumb <:dumb:1342556626351161516>",
          message_reference: %{message_id: msg.id}
        )
    end
  end

  def help(%{msg: msg, args: _args}) do
    buttons = [
      %Nostrum.Struct.Component{
        type: :button,
        style: :primary,
        label: "Click me!",
        custom_id: "button_click"
      }
    ]

    embed_1 =
      %Nostrum.Struct.Embed{}
      |> Nostrum.Struct.Embed.put_title("Help Command")
      |> Nostrum.Struct.Embed.put_description(
        "List of available commands for this bot.\n\nPrefix: v or V"
      )
      |> Nostrum.Struct.Embed.put_color(0x808080)
      |> Nostrum.Struct.Embed.put_field("help/h", "Shows this help command.")

    embed_2 =
      %Nostrum.Struct.Embed{}
      |> Nostrum.Struct.Embed.put_title("Mod Commands")
      |> Nostrum.Struct.Embed.put_color(431_948)
      |> Nostrum.Struct.Embed.put_field("mute/m", "Mutes a user.")
      |> Nostrum.Struct.Embed.put_field("unban/ub", "Unbans a user.")
      |> Nostrum.Struct.Embed.put_field("lock/l", "Locks the current thread.")
      |> Nostrum.Struct.Embed.put_field("kick/k", "Kicks a user from the server.")
      |> Nostrum.Struct.Embed.put_field("ban/b", "Bans a user.")
      |> Nostrum.Struct.Embed.put_field("websocket/ws", "Shows the current WebSocket details.")

    embed_3 =
      %Nostrum.Struct.Embed{}
      |> Nostrum.Struct.Embed.put_title("Misc Commands")
      |> Nostrum.Struct.Embed.put_color(431_948)
      |> Nostrum.Struct.Embed.put_field("howdumb/hd", "Gives a percentage of how dumb you are.")
      |> Nostrum.Struct.Embed.put_field("rank/r", "Displays your rank details.")
      |> Nostrum.Struct.Embed.put_field("whyban/wb", "States the reason for a user's ban.")

    embed_list = [embed_1, embed_2, embed_3]

    button =
      Nostrum.Struct.Component.Button.interaction_button("Right", "right", style: 2)

    button2 =
      Nostrum.Struct.Component.Button.interaction_button("Left", "left", style: 2)

    components = Nostrum.Struct.Component.ActionRow.action_row(components: [button2, button])

    Logger.debug("User ID: #{msg.author.id}")
    Logger.debug("Message ID: #{msg.id}")

    {:ok, sent_message} =
      Api.create_message(msg.channel_id, embed: embed_1, components: [components])

    Logger.debug("Bot Sent Message ID: #{sent_message.id}")
    HandleOp.store_message(msg.author.id, sent_message.id, "embed_1")

    userid = HandleOp.get_userid(msg.id)
  end
end
