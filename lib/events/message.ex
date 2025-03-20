defmodule Vennie.Events.Message do
  alias Nostrum.Api
  alias Nostrum.Struct.{Message, User}
  alias Nostrum.Struct.Event.MessageDelete
  alias Vennie.DeletedMessageStore
  alias Vennie.MessageCache
  require Logger

  @prefix ~w(v V)
  @required_role_id 1_339_183_257_736_052_777
  @misc_commands ~w(howdumb hd rank r snipe sn updatecache)
  @mod_commands ~w(websocket ws mute m unmute um lock l)
  @ranks_channel_id 1_022_644_903_248_920_656
  @help_channel_id 1_068_808_327_716_405_329
  @link_patterns [
    ~r/https?:\/\/[^\s]*\.vercel\.app[^\s]*/,
    ~r/https?:\/\/[^\s]*linkedin\.com[^\s]*/
  ]

  # --- Message Deletion Handler ---
  def message_delete(%MessageDelete{
        id: message_id,
        channel_id: _channel_id,
        deleted_message: deleted_message
      } = event) do
    message =
      if deleted_message do
        deleted_message
      else
        case Vennie.MessageCache.remove_message(message_id) do
          nil ->
            Logger.warn("Message #{message_id} not found in MessageCache for deletion: #{inspect(event)}")
            nil

          cached_message ->
            cached_message
        end
      end

    if message do
      Logger.info("Storing deleted message: #{inspect(message)}")
      Vennie.DeletedMessageStore.store_message(message)
    end

    :ok
  end

  # --- Message Creation & Command Handling ---
  def message_create(%Message{} = msg) do
    unless msg.author.bot do
      Vennie.MessageCache.store_message(msg)
    end

    Logger.debug("Received message: #{msg.content} in channel: #{msg.channel_id}")

    cond do
      msg.author.bot ->
        :ignore

      matches_emoji_pattern?(msg.content) ->
        Logger.debug("Matched emoji pattern in channel: #{msg.channel_id}")
        handle_emoji_message(msg)

      msg.channel_id == @ranks_channel_id ->
        Commands.Ranks.handle_message(msg)
        handle_command(msg)

      should_delete_message?(msg.content) ->
        Api.delete_message(msg.channel_id, msg.id)

      String.downcase(msg.content) =~ "help" ->
        {:ok, help_msg} =
          Api.create_message(
            msg.channel_id,
            "Please make a post in <##{@help_channel_id}> to get help!"
          )

        Process.sleep(10_000)
        Api.delete_message(msg.channel_id, help_msg.id)

      true ->
        handle_command(msg)
    end
  end

  # --- Emoji Handling ---
  defp matches_emoji_pattern?(content) do
    Regex.match?(~r/:([a-zA-Z0-9_]+):/, content)
  end

  defp handle_emoji_message(%Message{
         channel_id: channel_id,
         author: author,
         id: message_id,
         content: content,
         guild_id: guild_id
       } = _msg) do
    # Retrieve cached emojis from ETS; update the cache if not available.
    emojis =
      case Vennie.EmojiCache.get_emojis(guild_id) do
        nil ->
          case Vennie.EmojiCache.update_cache(guild_id) do
            {:ok, emojis} -> emojis
            _ -> []
          end

        cached ->
          cached
      end

    # Limit to animated emojis only.
    animated_emojis = Enum.filter(emojis, & &1.animated)

    with :ok <- Api.delete_message(channel_id, message_id) do
      emoji_matches = Regex.scan(~r/:([a-zA-Z0-9_]+):/, content, capture: :all_but_first)
      unique_emoji_names = emoji_matches |> List.flatten() |> Enum.uniq()
      new_content = replace_custom_emojis(content, unique_emoji_names, animated_emojis)
      send_animated_emoji(channel_id, author, new_content)
    else
      {:error, reason} ->
        Logger.error("Failed to delete message in emoji handler: #{inspect(reason)}")
      nil ->
        :ignore
    end
  end

  defp replace_custom_emojis(content, emoji_names, guild_emojis) do
    Enum.reduce(emoji_names, content, fn emoji_name, acc ->
      case find_custom_emoji(guild_emojis, emoji_name) do
        nil -> acc
        %{animated: true, name: name, id: id} ->
          String.replace(acc, ":#{emoji_name}:", "<a:#{name}:#{id}>")
      end
    end)
  end

  defp find_custom_emoji(emojis, emoji_name) do
    Enum.find(emojis, fn emoji -> emoji.name == emoji_name end)
  end

  defp send_animated_emoji(channel_id, author, content) do
    case get_or_create_webhook(channel_id, "Emoji Animator") do
      {:ok, webhook} ->
        Api.execute_webhook(webhook.id, webhook.token, %{
          content: content,
          username: author.username,
          avatar_url: User.avatar_url(author)
        })

      {:error, reason} ->
        Logger.error("Webhook failed: #{inspect(reason)}")
    end
  end

  # --- Command Handling ---
  defp should_delete_message?(content) do
    Enum.any?(@link_patterns, &Regex.match?(&1, content))
  end

  defp handle_command(msg) do
    case parse_command(msg.content) do
      {command, args} ->
        Logger.debug("Command: #{command}, args: #{inspect(args)}")
        context = %{msg: msg, args: args}

        cond do
          command in @misc_commands ->
            execute_command(command, context)

          is_nil(msg.guild_id) ->
            :ignore

          true ->
            case Api.get_guild_member(msg.guild_id, msg.author.id) do
              {:ok, member} ->
                if Enum.member?(member.roles, @required_role_id) do
                  execute_command(command, context)
                else
                  :ignore
                end

              {:error, reason} ->
                Logger.error("Failed to fetch member: #{inspect(reason)}")
                :ignore
            end
        end

      :invalid ->
        Logger.debug("Invalid command format")
        :ignore
    end
  end

  defp parse_command(content) do
    parts = String.split(content)
    Logger.debug("Split parts: #{inspect(parts)}")

    case parts do
      [first | rest] ->
        <<prefix::binary-size(1), remainder::binary>> = first

        if prefix in @prefix do
          if String.contains?(remainder, "```") do
            {command, code_part} = String.split_at(remainder, 1)

            if String.starts_with?(code_part, "```") do
              new_args = [code_part | rest]
              Logger.debug("Prefix: #{prefix}, Command: #{command}")
              {command, new_args}
            else
              Logger.debug("Prefix: #{prefix}, Command: #{remainder}")
              {remainder, rest}
            end
          else
            Logger.debug("Prefix: #{prefix}, Command: #{remainder}")
            {remainder, rest}
          end
        else
          :invalid
        end

      _ ->
        :invalid
    end
  end

  # --- Command Execution Handlers ---
  defp execute_command(cmd, %{msg: msg, args: args}) when cmd in ["snipe", "sn"] do
    index =
      case args do
        [num_str | _] ->
          case Integer.parse(num_str) do
            {num, _} when num >= 1 and num <= 10 -> num
            _ -> 1
          end

        _ ->
          1
      end

    case Vennie.DeletedMessageStore.get_message(index) do
      nil ->
        Api.create_message(msg.channel_id, "No deleted message found at position #{index}.")
      deleted_msg ->
        case get_or_create_webhook(msg.channel_id, "Snipe Webhook") do
          {:ok, webhook} ->
            Api.execute_webhook(webhook.id, webhook.token, %{
              content: deleted_msg.content,
              username: deleted_msg.author.username,
              avatar_url: User.avatar_url(deleted_msg.author)
            })
          {:error, reason} ->
            Logger.error("Snipe webhook failed: #{inspect(reason)}")
            Api.create_message(msg.channel_id, "Failed to snipe message.")
        end
    end
  end

  defp execute_command("updatecache", %{msg: msg}) do
    case Vennie.EmojiCache.update_cache(msg.guild_id) do
      {:ok, _emojis} ->
        Api.create_message(msg.channel_id, "Emoji cache updated!")
      {:error, reason} ->
        Api.create_message(msg.channel_id, "Failed to update emoji cache: #{inspect(reason)}")
    end
  end

  defp execute_command(cmd, context) when cmd in ["pr", "prototype"],
    do: Commands.Miscellaneous.prototype(context)
  defp execute_command(cmd, context) when cmd in ["rank", "r"],
    do: Commands.Ranks.handle_rank(context)
  defp execute_command(cmd, context) when cmd in ["howdumb", "hd"],
    do: Commands.Miscellaneous.howgay(context)
  defp execute_command(cmd, context) when cmd in ["e", "eval", "exec"],
    do: Commands.Utils.execute(context)
  defp execute_command(cmd, context) when cmd in ["help", "h"],
    do: Commands.Miscellaneous.help(context)
  defp execute_command(cmd, context) when cmd in ["websocket", "ws"],
    do: Commands.Utils.websocket(context)
  defp execute_command(cmd, context) when cmd in ["mute", "m"],
    do: Commands.Moderation.mute(context)
  defp execute_command(cmd, context) when cmd in ["wb", "whyban", "whybanne"],
    do: Commands.Moderation.baninfo(context)
  defp execute_command(cmd, context) when cmd in ["unban", "ub"],
    do: Commands.Moderation.unban(context)
  defp execute_command(cmd, context) when cmd in ["purge", "p"],
    do: Commands.Moderation.purge(context)
  defp execute_command(cmd, context) when cmd in ["unmute", "um"],
    do: Commands.Moderation.unmute(context)
  defp execute_command(cmd, context) when cmd in ["lock", "l"],
    do: Commands.Moderation.lock(context)
  defp execute_command(cmd, context) when cmd in ["kick", "k"],
    do: Commands.Moderation.kick(context)
  defp execute_command(cmd, context) when cmd in ["ban", "b"],
    do: Commands.Moderation.ban(context)
  defp execute_command(cmd, _) do
    Logger.debug("Unknown command: #{cmd}")
    :ignore
  end

  # --- Webhook Helper ---
  defp get_or_create_webhook(channel_id, name) do
    Logger.debug("Getting webhook for #{name} in channel: #{channel_id}")

    case Api.get_channel_webhooks(channel_id) do
      {:ok, webhooks} ->
        webhook = Enum.find(webhooks, fn hook -> hook.name == name end)

        if webhook do
          {:ok, webhook}
        else
          case Api.create_webhook(channel_id, %{name: name}) do
            {:ok, webhook} -> {:ok, webhook}
            error -> error
          end
        end

      error ->
        error
    end
  end
end

