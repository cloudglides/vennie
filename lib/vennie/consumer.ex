defmodule Vennie.Consumer do
  use Nostrum.Consumer
  require Logger

  @prefix ~w(v V)
  @required_role_id 1339183257736052777

  # Handle the READY event
  def handle_event({:READY, _data, ws_state}) do
    Nostrum.Api.update_status(:online, "Elixir <3", 0)
    Vennie.GatewayTracker.set_state(ws_state)
  end

  # Handle the MESSAGE_CREATE event
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    Logger.debug("Received message: #{msg.content}")

    case parse_command(msg.content) do
      {command, args} ->
        Logger.debug("Command: #{command}, args: #{inspect(args)}")
        
        if is_nil(msg.guild_id) do
          # React with ❌ if the command is used in DMs
          Nostrum.Api.create_reaction(msg.channel_id, msg.id, "❌")
          :ignore
        else
          case Nostrum.Api.get_guild_member(msg.guild_id, msg.author.id) do
            {:ok, member} ->
              if Enum.member?(member.roles, @required_role_id) do
                # Execute the command if the user has the required role
                execute_command(command, %{msg: msg, args: args})
              else
                # React with ❌ if the user doesn't have the required role
                Nostrum.Api.create_reaction(msg.channel_id, msg.id, "❌")
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

  # Handle the THREAD_CREATE event
  def handle_event({:THREAD_CREATE, thread, _ws_state}) do
    if thread.parent_id == 1068808327716405329 and is_nil(thread.member) do
      Process.sleep(500)  # Small delay to prevent duplicates
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

  # Ignore all other events
  def handle_event(_event), do: :noop

  # Parse the command from the message content
  defp parse_command(content) do
    parts = String.split(content)
    Logger.debug("Split parts: #{inspect(parts)}")

    case parts do
      [<<prefix::binary-size(1), command::binary>> | args] when prefix in @prefix ->
        Logger.debug("Prefix: #{prefix}, Command: #{command}")
        {command, args}

      _ ->
        :invalid
    end
  end

  # Execute commands based on the parsed command
  defp execute_command(cmd, context) when cmd in ["websocket", "ws"], do: Commands.Moderation.websocket(context)
  defp execute_command(cmd, context) when cmd in ["mute", "m"], do: Commands.Moderation.mute(context)
  defp execute_command(cmd, context) when cmd in ["unmute", "um"], do: Commands.Moderation.unmute(context)
  defp execute_command(cmd, context) when cmd in ["lock", "l"], do: Commands.Moderation.lock(context)
  defp execute_command(cmd, _) do
    Logger.debug("Unknown command: #{cmd}")
    :ignore
  end
end
