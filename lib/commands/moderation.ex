defmodule Commands.Moderation do
  alias Nostrum.Api
  alias Commands.Helpers.Duration

  def mute(%{msg: msg, args: [raw_user_id, duration_str | _reason]} = context) do
    with user_id <- extract_id(raw_user_id),
         duration_seconds <- Duration.parse_duration(duration_str),
         timeout_until <- DateTime.utc_now() |> DateTime.add(duration_seconds, :second) do
      
      case Api.modify_guild_member(
             msg.guild_id,
             user_id,
             communication_disabled_until: DateTime.to_iso8601(timeout_until)
           ) do
        {:ok, _} ->
          Api.create_message(
            msg.channel_id,
            "<a:bonk:1338730809510858772> Done! muted <@#{user_id}> for #{duration_str}"
          )

        {:error, error} ->
          Api.create_message(msg.channel_id, "Error: #{inspect(error)}")
      end
    end
  end

  # Handle invalid mute command format
  def mute(%{msg: msg}) do
    Api.create_message(
      msg.channel_id,
      "Usage: vmute @user <duration> [reason]\nDurations: 30m, 1h, 1d"
    )
  end

  def unmute(%{msg: msg, args: [raw_user_id | _]}) do
    with user_id <- extract_id(raw_user_id) do
      case Api.modify_guild_member(
             msg.guild_id,
             user_id,
             communication_disabled_until: nil
           ) do
        {:ok, _} ->
          Api.create_message(msg.channel_id, "Done! unmuted <@#{user_id}>")

        {:error, error} ->
          Api.create_message(msg.channel_id, "Error: #{inspect(error)}")
      end
    end
  end

  # Handle invalid unmute command format
  def unmute(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vunmute @user")
  end

  # New public command to lock a thread.
  def lock(%{msg: msg}) do
    channel_id = msg.channel_id

    with {:ok, channel} <- Api.get_channel(channel_id) do
      # Check if the channel is a thread (threads have a non-nil parent_id)
      if Map.get(channel, :parent_id) do
        case Api.modify_channel(channel_id, %{locked: true}) do
          {:ok, _updated_channel} ->
            Api.create_message(channel_id, "Thread has been locked.")

          {:error, error} ->
            Api.create_message(channel_id, "Error locking thread: #{inspect(error)}")
        end
      else
        Api.create_message(channel_id, "This command can only be used in a thread.")
      end
    else
      {:error, error} ->
        Api.create_message(channel_id, "Error fetching channel details: #{inspect(error)}")
    end
  end

  defp extract_id(mention) do
    case Regex.run(~r/<@!?(\d+)>/, mention) do
      [_, id_str] -> String.to_integer(id_str)
      _ -> raise ArgumentError, "Invalid user mention format: #{mention}"
    end
  end
end

