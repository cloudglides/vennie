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
    # Create the button
    buttons = [
      %Nostrum.Struct.Component{
        type: :button,
        style: :primary,
        label: "Click me!",
        custom_id: "button_click"
      }
    ]

    # Create the embed
    embed =
      %Nostrum.Struct.Embed{}
      |> Nostrum.Struct.Embed.put_title("Help Command")
      |> Nostrum.Struct.Embed.put_description(
        "List of available commands for this bot.\n\nPrefix: v or V"
      )
      |> Nostrum.Struct.Embed.put_color(431_948)
      |> Nostrum.Struct.Embed.put_field("help/h", "Shows this help command.")
      |> Nostrum.Struct.Embed.put_field("howdumb/hd", "Gives a percentage of how dumb you are.")
      |> Nostrum.Struct.Embed.put_field("rank/r", "Displays your rank details.")
      |> Nostrum.Struct.Embed.put_field("websocket/ws", "Shows the current WebSocket details.")
      |> Nostrum.Struct.Embed.put_field("mute/m", "Mutes a user.")
      |> Nostrum.Struct.Embed.put_field("whyban/wb", "States the reason for a user's ban.")
      |> Nostrum.Struct.Embed.put_field("unban/ub", "Unbans a user.")
      |> Nostrum.Struct.Embed.put_field("lock/l", "Locks the current thread.")
      |> Nostrum.Struct.Embed.put_field("kick/k", "Kicks a user from the server.")
      |> Nostrum.Struct.Embed.put_field("ban/b", "Bans a user.")

    # Create the button component
    button =
      Nostrum.Struct.Component.Button.interaction_button("refresh", "trackmania_refresh",
        emoji: %Nostrum.Struct.Emoji{name: "refresh", id: 1_200_130_727_187_054_613}
      )

    components = Nostrum.Struct.Component.ActionRow.action_row(components: [button])

    # Log the message details
    Logger.debug("User ID: #{msg.author.id}")
    Logger.debug("Message ID: #{msg.id}")

    # Create the bot's message with the embed and components (buttons)
    {:ok, sent_message} =
      Api.create_message(msg.channel_id, embed: embed, components: [components])

    # Store the message ID of the message the bot sent
    Logger.debug("Bot Sent Message ID: #{sent_message.id}")
    HandleOp.store_message(msg.author.id, sent_message.id)

    # Optionally, if you want to retrieve the user ID from a message and store it
    userid = HandleOp.get_userid(msg.id)
  end
end
