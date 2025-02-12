defmodule Vennie.Consumer do
  use Nostrum.Consumer
  require Logger

  @prefix ~w(v V)

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  # Called when the bot connects.
  def handle_event({:READY, data, _ws_state}) do
    Logger.info("#{data.user.username} connected!")
    :ok
  end

  # Called for every message.
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    if has_prefix?(msg.content) do
      process_command(msg)
    end

    :ok
  end

  def handle_event(_event), do: :ok

  # Splits the message and dispatches commands.
  defp process_command(msg) do
    [command | args] = String.split(msg.content)
    command = String.downcase(command)

    case command do
      "vjoin"  -> handle_join(msg, args)
      "vplay"  -> handle_play(msg, args)
      "vleave" -> handle_leave(msg)
      _ -> :ok
    end
  end

  # vjoin: If a channel ID is provided, use it. Otherwise, try using the message author’s voice state.
  defp handle_join(msg, [channel_id_str | _]) do
    channel_id =
      case Integer.parse(channel_id_str) do
        {id, _} -> id
        :error -> nil
      end

    if channel_id do
      case Nostrum.Voice.join_channel(msg.guild_id, channel_id) do
        :ok ->
          send_message(msg.channel_id, "Joined voice channel!")
        {:ok, _conn} ->
          send_message(msg.channel_id, "Joined voice channel!")
        {:error, reason} ->
          send_message(msg.channel_id, "Failed to join: #{inspect(reason)}")
      end
    else
      send_message(msg.channel_id, "Invalid channel ID provided!")
    end
  end

  defp handle_join(msg, []) do
    # If no channel ID is provided, try using the voice state of the command sender.
    case get_voice_channel(msg) do
      nil ->
        send_message(msg.channel_id, "You need to be in a voice channel!")
      channel_id ->
        case Nostrum.Voice.join_channel(msg.guild_id, channel_id) do
          :ok ->
            send_message(msg.channel_id, "Joined voice channel!")
          {:ok, _conn} ->
            send_message(msg.channel_id, "Joined voice channel!")
          {:error, reason} ->
            send_message(msg.channel_id, "Failed to join: #{inspect(reason)}")
        end
    end
  end

  # vplay: Download the audio and play it if the bot is ready.
  defp handle_play(msg, [url | _]) do
    case download_youtube_audio(url) do
      {:ok, path} ->
        # Instead of checking the command sender’s voice state, we check if the bot is ready.
        if Nostrum.Voice.ready?(msg.guild_id) do
          case Nostrum.Voice.play(msg.guild_id, path, :url) do
            :ok ->
              send_message(msg.channel_id, "Now playing!")
            {:error, reason} ->
              send_message(msg.channel_id, "Error playing audio: #{inspect(reason)}")
          end
        else
          send_message(msg.channel_id, "Bot is not in a voice channel or not ready!")
        end

      {:error, reason} ->
        send_message(msg.channel_id, "Error downloading audio: #{inspect(reason)}")
    end
  end

  # vleave: Leave the voice channel.
  defp handle_leave(msg) do
    case Nostrum.Voice.leave_channel(msg.guild_id) do
      :ok ->
        send_message(msg.channel_id, "Left voice channel!")
      {:error, reason} ->
        send_message(msg.channel_id, "Error leaving: #{inspect(reason)}")
    end
  end

  # Retrieves the voice channel of the command sender from the guild cache.
  # (Used only for vjoin if no channel id is provided.)
  defp get_voice_channel(msg) do
    with {:ok, guild} <- Nostrum.Cache.GuildCache.get(msg.guild_id),
         voice_states when is_map(voice_states) <- guild.voice_states,
         voice_state when not is_nil(voice_state) <- Map.get(voice_states, msg.author.id)
    do
      voice_state.channel_id
    else
      _ -> nil
    end
  end

  # Download audio using yt-dlp and save it as an MP3 file in the system temporary directory.
  defp download_youtube_audio(url) do
    file_path = "#{System.tmp_dir()}/#{:rand.uniform(999_999)}.mp3"

    args = [
      "-x",
      "--audio-format", "mp3",
      "--audio-quality", "0",
      "-o", file_path,
      url
    ]

    case Porcelain.exec("yt-dlp", args) do
      %{status: 0} -> {:ok, file_path}
      error -> {:error, error}
    end
  end

  # Check if the message starts with an allowed prefix.
  defp has_prefix?(content) when is_binary(content) do
    String.starts_with?(content, @prefix)
  end
  defp has_prefix?(_), do: false

  # Sends a message to a Discord channel.
  defp send_message(channel_id, content) do
    Nostrum.Api.create_message(channel_id, content)
  end
end

