defmodule Commands.Moderation do
  alias Nostrum.Api
  alias Commands.Helpers.Duration

  @solved_tag_id 1268429894082236538

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

  def mute(%{msg: msg}) do
    Api.create_message(
      msg.channel_id,
      "Usage: vmute @user <duration\nDurations: 30s, 10m, 1d, etc"
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

  def unmute(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vunmute @user")
  end

  def lock(%{msg: msg}) do
    channel_id = msg.channel_id
    
    with {:ok, channel} <- Api.get_channel(channel_id) do
      if Map.get(channel, :parent_id) do
        with {:ok, _updated_channel} <- Api.modify_channel(channel_id, %{locked: true}),
             {:ok, _} <- apply_solved_tag(channel_id, channel.applied_tags || []) do
          Api.create_message(channel_id, "Thread has been locked and marked as solved.")
        else
          {:error, error} ->
            Api.create_message(channel_id, "Error: #{inspect(error)}")
        end
      else
        Api.create_message(channel_id, "This command can only be used in a thread.")
      end
    else
      {:error, error} ->
        Api.create_message(channel_id, "Error fetching channel details: #{inspect(error)}")
    end
  end

  defp apply_solved_tag(channel_id, current_tags) do
    # Add the solved tag ID to the existing tags if it's not already present
    updated_tags = 
      if @solved_tag_id in current_tags do
        current_tags
      else
        [@solved_tag_id | current_tags]
      end

    Api.modify_channel(channel_id, %{applied_tags: updated_tags})
  end

  defp extract_id(mention) do
    case Regex.run(~r/<@!?(\d+)>/, mention) do
      [_, id_str] -> String.to_integer(id_str)
      _ -> raise ArgumentError, "Invalid user mention format: #{mention}"
    end
  end
end
