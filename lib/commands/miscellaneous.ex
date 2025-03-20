defmodule Commands.Miscellaneous do
  require Logger
  alias Nostrum.Api
  alias Vennie.DeletedMessageStore
  alias Nostrum.Struct.User
  alias Vennie.HowGay
  alias Nostrum.Struct.Message
  import Ecto.Query
  import Nostrum.Struct.Embed

  # Ensure any necessary processes (like HandleOp) are started; adjust for your supervision tree.
  {:ok, _pid} = HandleOp.start_link([])

  @doc """
  Handles the snipe command.
  Usage: `vsn <index>` (default index is 1 for the most recent deletion)
  """
def prototype(payload) do
  Logger.debug(inspect(payload, pretty: true))

  message = Map.get(payload, :msg)
  guild_id = Map.get(message, :guild_id)
  channel_id = Map.get(message, :channel_id)

  if guild_id do
    case Nostrum.Cache.GuildCache.get(guild_id) do
      {_, guild} ->
        emojis = Map.get(guild, :emojis, [])

        results =
          emojis
          |> Enum.map(fn emoji ->
            new_name =
              emoji.name
              |> String.downcase()
              |> String.replace(~r/\d|_/, "")

            if emoji.name != new_name do
              # Provide an optional reason for the audit log
              reason = "Renaming emoji to remove digits, underscores, and lowercase"
              case Nostrum.Api.Guild.modify_emoji(guild_id, emoji.id, %{name: new_name}, reason) do
                {:ok, updated_emoji} ->
                  "Renamed emoji #{emoji.name} to #{updated_emoji.name}"
                {:error, err} ->
                  "Failed to rename emoji #{emoji.name}: #{inspect(err)}"
              end
            else
              "Emoji #{emoji.name} already formatted"
            end
          end)

        summary = Enum.join(results, "\n")
        codeblock_message = "```
#{summary}
```"

        case Nostrum.Api.create_message(channel_id, codeblock_message) do
          {:ok, _msg} ->
            Logger.info("Sent summary of emoji renames successfully!")
          {:error, reason} ->
            Logger.error("Failed to send summary message: #{inspect(reason)}")
        end

      _ ->
        Logger.error("Guild not found in cache for guild_id: #{guild_id}")
    end
  else
    Logger.error("guild_id is missing from the message struct!")
  end
end



  def handle_snipe(%{msg: msg, args: args}) do
    index =
      case args do
        [index_str | _] ->
          case Integer.parse(index_str) do
            {index, _} -> index
            :error -> 1
          end

        [] ->
          1
      end

    case DeletedMessageStore.get_message(index) do
      nil ->
        Api.create_message(msg.channel_id, "No deleted message found at position #{index}.")
      deleted_message ->
        send_via_webhook(msg.channel_id, deleted_message)
    end
  end

  @doc """
  Sends the sniped (deleted) message via a webhook that mimics the original sender.
  The allowed_mentions map is passed as `%{"parse" => []}` to prevent pings.
  """
  defp send_via_webhook(channel_id, deleted_message) do
    case get_or_create_webhook(channel_id) do
      {:ok, webhook} ->
        Api.execute_webhook(webhook.id, webhook.token, %{
          content: deleted_message.content,
          username: deleted_message.author.username,
          avatar_url: User.avatar_url(deleted_message.author),
          # Pass allowed_mentions as a proper map—not as a tuple or list!
          allowed_mentions: %{"parse" => []}
        })

      {:error, reason} ->
        Logger.error("Webhook failed for snipe: #{inspect(reason)}")
        Api.create_message(channel_id, "Failed to snipe message due to an error.")
    end
  end

  @doc """
  Retrieves an existing webhook named "Snipe Webhook" for the channel or creates one.
  """
  defp get_or_create_webhook(channel_id) do
    Logger.debug("Getting webhook for snipe in channel: #{channel_id}")

    case Api.get_channel_webhooks(channel_id) do
      {:ok, webhooks} ->
        snipe_webhook = Enum.find(webhooks, fn hook -> hook.name == "Snipe Webhook" end)

        if snipe_webhook do
          {:ok, snipe_webhook}
        else
          case Api.create_webhook(channel_id, %{name: "Snipe Webhook"}) do
            {:ok, webhook} -> {:ok, webhook}
            error -> error
          end
        end

      error ->
        error
    end
  end

  @doc """
  Handles the 'howgay' command.
  Generates (or retrieves) a random percentage for the user.
  """
  def howgay(%{msg: msg, args: _args}) do
    query = from(h in HowGay, where: h.user_id == ^msg.author.id, limit: 1)

    case Vennie.Repo.one(query) do
      nil ->
        gay = :rand.uniform(100)
        Vennie.Repo.insert!(%HowGay{user_id: msg.author.id, howgay_percentage: gay})
        Api.create_message(msg.channel_id, %{
          content: "You are #{gay}% dumb <:dumb:1342556626351161516>",
          message_reference: %{message_id: msg.id}
        })

      record ->
        Api.create_message(msg.channel_id, %{
          content: "You are #{record.howgay_percentage}% dumb <:dumb:1342556626351161516>",
          message_reference: %{message_id: msg.id}
        })
    end
  end

  @doc """
  Handles the help command by sending an embed and buttons.
  """
  def help(%{msg: msg, args: _args}) do
    buttons = [
      Nostrum.Struct.Component.Button.interaction_button("Left", "left", style: 2),
      Nostrum.Struct.Component.Button.interaction_button("Right", "right", style: 2)
    ]

    components = Nostrum.Struct.Component.ActionRow.action_row(components: buttons)

    embed_1 =
      %Nostrum.Struct.Embed{}
      |> Nostrum.Struct.Embed.put_title("Help Command")
      |> Nostrum.Struct.Embed.put_description("List of available commands for this bot.\n\nPrefix: v or V")
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

    Logger.debug("User ID: #{msg.author.id}")
    Logger.debug("Message ID: #{msg.id}")

    {:ok, sent_message} = Api.create_message(msg.channel_id, embed: embed_1, components: [components])
    Logger.debug("Bot Sent Message ID: #{sent_message.id}")
    HandleOp.store_message(msg.author.id, sent_message.id, "embed_1")
    HandleOp.get_userid(msg.id)
  end
end

