defmodule Commands.Moderation do
  require Logger
  alias Nostrum.Api
  alias Commands.Helpers.Duration


def websocket(%{msg: msg, args: _args}) do
    case Vennie.GatewayTracker.get_state() do
      nil ->
        Api.create_message(msg.channel_id, "WebSocket details not available yet!")

      ws_state ->
        details = 
          ws_state
          |> inspect(pretty: true)
          |> String.slice(0, 1900)  # Trim to avoid Discord's message length limits

        Api.create_message(msg.channel_id, "WebSocket details:\n```elixir\n#{details}\n```")
    end
  end




  def mute(%{msg: msg, args: [raw_user_id, duration_str | _reason]} = _context) do
    # Immediately acknowledge the command with a provisional message.
    case Api.create_message(msg.channel_id, "Processing mute command for #{raw_user_id}...") do
      {:ok, provisional_msg} ->
        Task.start(fn ->
          try do
            user_id = extract_id(raw_user_id)
            duration_seconds = Duration.parse_duration(duration_str)
            timeout_until = DateTime.utc_now() |> DateTime.add(duration_seconds, :second)

            case Api.modify_guild_member(
                   msg.guild_id,
                   user_id,
                   communication_disabled_until: DateTime.to_iso8601(timeout_until)
                 ) do
              {:ok, _} ->
                Api.edit_message(
                  msg.channel_id,
                  provisional_msg.id,
                  %{content: "<a:bonk:1338730809510858772> Done! Muted <@#{user_id}> for #{duration_str}"}
                )

               send_dm(user_id, "You have been muted in the We Write Code Server for #{duration_str}.")
              {:error, error} ->
                Api.edit_message(
                  msg.channel_id,
                  provisional_msg.id,
                  %{content: "Error: #{inspect(error)}"}
                )
            end
          rescue
            e ->
              Api.edit_message(
                msg.channel_id,
                provisional_msg.id,
                %{content: "Exception: #{inspect(e)}"}
              )
          end
        end)

      {:error, error} ->
        # Fallback if the provisional message cannot be sent.
        Api.create_message(msg.channel_id, "Error creating provisional message: #{inspect(error)}")
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
    # Immediate acknowledgement can also be applied here if desired.
    case Api.create_message(msg.channel_id, "Processing unmute command for #{raw_user_id}...") do
      {:ok, provisional_msg} ->
        Task.start(fn ->
          try do
            user_id = extract_id(raw_user_id)
            case Api.modify_guild_member(
                   msg.guild_id,
                   user_id,
                   communication_disabled_until: nil
                 ) do
              {:ok, _} ->
                Api.edit_message(
                  msg.channel_id,
                  provisional_msg.id,
                  %{content: "Done! Unmuted <@#{user_id}>"}
                )
              {:error, error} ->
                Api.edit_message(
                  msg.channel_id,
                  provisional_msg.id,
                  %{content: "Error: #{inspect(error)}"}
                )
            end
          rescue
            e ->
              Api.edit_message(
                msg.channel_id,
                provisional_msg.id,
                %{content: "Exception: #{inspect(e)}"}
              )
          end
        end)

      {:error, error} ->
        Api.create_message(msg.channel_id, "Error creating provisional message: #{inspect(error)}")
    end
  end

  # Handle invalid unmute command format
  def unmute(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vunmute @user")
  end

  def lock(%{msg: msg}) do
    channel_id = msg.channel_id

    # For lock, you might also consider immediate feedback if needed.
    with {:ok, channel} <- Api.get_channel(channel_id) do
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

defp send_dm(user_id, message) do
  with {:ok, dm_channel} <- Nostrum.Api.create_dm(user_id),
       {:ok, _msg} <- Nostrum.Api.create_message(dm_channel.id, message) do
    :ok
  else
    {:error, error} ->
      IO.inspect(error, label: "Failed to send DM")
      {:error, error}
  end
end



  defp extract_id(mention) do
    case Regex.run(~r/<@!?(\d+)>/, mention) do
      [_, id_str] -> String.to_integer(id_str)
      _ -> raise ArgumentError, "Invalid user mention format: #{mention}"
    end
  end
end

