defmodule Vennie.Consumer do
  use Nostrum.Consumer
  require Logger

  @prefix ~w(v V)

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    Logger.debug("Received message: #{msg.content}")

    case parse_command(msg.content) do
      {command, args} ->
        Logger.debug("Command: #{command}, args: #{inspect(args)}")
        execute_command(command, %{msg: msg, args: args})

      :invalid ->
        Logger.debug("Invalid command format")
        :ignore
    end
  end

  def handle_event({:THREAD_CREATE, thread, _ws_state}) do
    if thread.parent_id == 1068808327716405329 and is_nil(thread.member) do
      Process.sleep(500)  # Small delay to prevent duplicates
      Nostrum.Api.create_message(thread.id, "Hey <a:hey:1339161785961545779>, <@#{thread.owner_id}>
*  Consider reading https://discord.com/channels/1022510020736331806/1268430786332332107  to improve your question!
* Explain what exactly your issue is.
* Post the full error stack trace, not just the top part!
* Show your code!")

      Logger.debug(thread)
    else
      :noop
    end
  end

  def handle_event(_event), do: :noop

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

  defp execute_command("mute", context), do: Commands.Moderation.mute(context)
  defp execute_command("unmute", context), do: Commands.Moderation.unmute(context)
  defp execute_command("lock", context), do: Commands.Moderation.lock(context)
  defp execute_command(cmd, _) do
    Logger.debug("Unknown command: #{cmd}")
    :ignore
  end
end

