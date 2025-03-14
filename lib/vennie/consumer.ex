defmodule Vennie.Consumer do
  @behaviour Nostrum.Consumer
  alias Nostrum.Api
  require Logger

  @prefix ~w(v V)
  @required_role_id 1_339_183_257_736_052_777
  @misc_commands ~w(howdumb hd rank r)
  @mod_commands ~w(websocket ws mute m unmute um lock l)
  @ranks_channel_id 1_022_644_903_248_920_656
  @help_channel_id 1_068_808_327_716_405_329
  @link_patterns [
    ~r/https?:\/\/[^\s]*\.vercel\.app[^\s]*/,
    ~r/https?:\/\/[^\s]*linkedin\.com[^\s]*/
  ]

  def handle_event({:READY, _data, ws_state}) do
    Vennie.GatewayTracker.set_state(ws_state)
    Nostrum.Api.Self.update_status(:online, {:watching, "We Write Code"})
  end

  def handle_event({:INTERACTION_CREATE, msg, _ws_state}) do
    Vennie.Events.interaction(msg)
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    Logger.debug("Received message: #{msg.content}")

    cond do
      msg.author.bot ->
        :ignore

      msg.channel_id == @ranks_channel_id ->
        Commands.Ranks.handle_message(msg)
        handle_command(msg)

      should_delete_message?(msg.content) ->
        Nostrum.Api.delete_message(msg.channel_id, msg.id)

      String.downcase(msg.content) =~ "help" ->
        {:ok, help_msg} =
          Nostrum.Api.create_message(
            msg.channel_id,
            "Please make a post in <##{@help_channel_id}> to get help!"
          )

        Process.sleep(10_000)
        Nostrum.Api.delete_message(msg.channel_id, help_msg.id)

      true ->
        handle_command(msg)
    end
  end

  def handle_event({:THREAD_CREATE, thread, _ws_state}) do
    if thread.parent_id == @help_channel_id and is_nil(thread.member) do
      # Small delay to prevent duplicates
      Process.sleep(500)

      Nostrum.Api.create_message(thread.id, """
      Hey <a:hey:1339161785961545779>, <@#{thread.owner_id}>
      * Consider reading https://discord.com/channels/1022510020736331806/1268430786332332107 to improve your question!
      * Explain what exactly your issue is.
      * Post the full error stack trace, not just the top part!
      * Show your code!
      """)

      Logger.debug(thread)
    else
      :noop
    end
  end

  def handle_event(_event), do: :noop

  defp should_delete_message?(content) do
    Enum.any?(@link_patterns, &Regex.match?(&1, content))
  end

  defp handle_command(msg) do
    case parse_command(msg.content) do
      {command, args} ->
        Logger.debug("Command: #{command}, args: #{inspect(args)}")
        context = %{msg: msg, args: args}

        if command in @misc_commands do
          execute_command(command, context)
        else
          if is_nil(msg.guild_id) do
            :ignore
          else
            case Nostrum.Api.get_guild_member(msg.guild_id, msg.author.id) do
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
        # Split the first element into the prefix and the remainder
        <<prefix::binary-size(1), remainder::binary>> = first

        if prefix in @prefix do
          # Check if the remainder contains an inline code block delimiter
          if String.contains?(remainder, "```") do
            # Split the remainder into the command and the code block start
            {command, code_part} = String.split_at(remainder, 1)

            if String.starts_with?(code_part, "```") do
              # Prepend the missing "```" to the code block and adjust args
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

  defp execute_command(cmd, context) when cmd in ["rank", "r"],
    do: Commands.Ranks.handle_rank(context)

  # defp execute_command(cmd, context) when cmd in ["join", "j"], do: Commands.Music.handle_join(context)
  # defp execute_command(cmd, context) when cmd in ["volume", "v"], do: Commands.Music.volume(context)
  # defp execute_command(cmd, context) when cmd in ["backward", "bw"], do: Commands.Music.backward(context)
  # defp execute_command(cmd, context) when cmd in ["queue", "q"], do: Commands.Music.queue(context)
  # defp execute_command(cmd, context) when cmd in ["skip", "s"], do: Commands.Music.skip(context)
  # defp execute_command(cmd, context) when cmd in ["forward", "fw"], do: Commands.Music.forward(context)
  # defp execute_command(cmd, context) when cmd in ["p", "play"], do: Commands.Music.handle_play(context)
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
end
