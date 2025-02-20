defmodule Commands.Music do

@moduledoc """
ignore this mf for now i wanna delete this module but i am not confident enough if i can even rewrite this piece of shit ong
"""


  use GenServer
  alias Nostrum.Api
  require Logger

  @default_volume 100
  @forward_seconds 10
  @backward_seconds 10


  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{queues: %{}, volumes: %{}, current_tracks: %{}}}
  end


  def queue_add(guild_id, url, title) do
    GenServer.cast(__MODULE__, {:queue_add, guild_id, url, title})
  end

  def queue_next(guild_id) do
    GenServer.call(__MODULE__, {:queue_next, guild_id})
  end

  def queue_clear(guild_id) do
    GenServer.cast(__MODULE__, {:queue_clear, guild_id})
  end

  def get_queue(guild_id) do
    GenServer.call(__MODULE__, {:get_queue, guild_id})
  end

  def set_volume(guild_id, volume) do
    GenServer.cast(__MODULE__, {:set_volume, guild_id, volume})
  end

  def get_volume(guild_id) do
    GenServer.call(__MODULE__, {:get_volume, guild_id})
  end

  def set_current_track(guild_id, track) do
    GenServer.cast(__MODULE__, {:set_current_track, guild_id, track})
  end

  def get_current_track(guild_id) do
    GenServer.call(__MODULE__, {:get_current_track, guild_id})
  end


  def handle_cast({:queue_add, guild_id, url, title}, state) do
    queue = Map.get(state.queues, guild_id, [])
    {:noreply, put_in(state.queues[guild_id], queue ++ [{url, title}])}
  end

  def handle_cast({:queue_clear, guild_id}, state) do
    {:noreply, put_in(state.queues[guild_id], [])}
  end

  def handle_cast({:set_volume, guild_id, volume}, state) do
    {:noreply, put_in(state.volumes[guild_id], volume)}
  end

  def handle_cast({:set_current_track, guild_id, track}, state) do
    {:noreply, put_in(state.current_tracks[guild_id], track)}
  end

  def handle_call({:queue_next, guild_id}, _from, state) do
    case Map.get(state.queues, guild_id, []) do
      [] -> {:reply, nil, state}
      [next | rest] ->
        {:reply, next, put_in(state.queues[guild_id], rest)}
    end
  end

  def handle_call({:get_queue, guild_id}, _from, state) do
    {:reply, Map.get(state.queues, guild_id, []), state}
  end

  def handle_call({:get_volume, guild_id}, _from, state) do
    {:reply, Map.get(state.volumes, guild_id, @default_volume), state}
  end

  def handle_call({:get_current_track, guild_id}, _from, state) do
    {:reply, Map.get(state.current_tracks, guild_id), state}
  end


  def handle_join(%{msg: msg, args: [channel_id_str | _]}) do
    channel_id =
      case Integer.parse(channel_id_str) do
        {id, _} -> id
        :error -> nil
      end

    if channel_id do
      join_voice_channel(msg.guild_id, channel_id, msg.channel_id)
    else
      send_message(msg.channel_id, "Invalid channel ID provided!")
    end
  end

  def handle_join(%{msg: msg}) do
    case get_voice_channel(msg) do
      nil ->
        send_message(msg.channel_id, "You need to be in a voice channel!")
      channel_id ->
        join_voice_channel(msg.guild_id, channel_id, msg.channel_id)
    end
  end

  def handle_play(%{msg: msg, args: [url | _]}) do
    case ensure_voice_connection(msg) do
      :ok ->
        process_play_request(msg.guild_id, msg.channel_id, url)
      {:error, reason} ->
        send_message(msg.channel_id, "Error: #{reason}")
    end
  end

  def handle_play(%{msg: msg}) do
    send_message(msg.channel_id, "Usage: !play <url>")
  end

  def handle_skip(%{msg: msg}) do
    current_track = get_current_track(msg.guild_id)
    if current_track do
      Nostrum.Voice.stop(msg.guild_id)
      play_next_in_queue(msg.guild_id, msg.channel_id)
    else
      send_message(msg.channel_id, "No track is currently playing!")
    end
  end

  def handle_stop(%{msg: msg}) do
    Nostrum.Voice.stop(msg.guild_id)
    queue_clear(msg.guild_id)
    set_current_track(msg.guild_id, nil)
    send_message(msg.channel_id, "Playback stopped and queue cleared!")
  end

  def handle_pause(%{msg: msg}) do
    if get_current_track(msg.guild_id) do
      Nostrum.Voice.pause(msg.guild_id)
      send_message(msg.channel_id, "Playback paused!")
    else
      send_message(msg.channel_id, "No track is currently playing!")
    end
  end

  def handle_resume(%{msg: msg}) do
    if get_current_track(msg.guild_id) do
      Nostrum.Voice.resume(msg.guild_id)
      send_message(msg.channel_id, "Playback resumed!")
    else
      send_message(msg.channel_id, "No track is currently playing!")
    end
  end

  def handle_volume(%{msg: msg, args: [volume_str | _]}) do
    case Integer.parse(volume_str) do
      {volume, _} when volume >= 0 and volume <= 200 ->
        set_volume(msg.guild_id, volume)
        send_message(msg.channel_id, "Volume set to #{volume}%")
      _ ->
        send_message(msg.channel_id, "Please provide a volume between 0 and 200")
    end
  end

  def handle_volume(%{msg: msg}) do
    volume = get_volume(msg.guild_id)
    send_message(msg.channel_id, "Current volume: #{volume}%")
  end

  def handle_forward(%{msg: msg}) do
    if get_current_track(msg.guild_id) do
      Nostrum.Voice.seek_relative(msg.guild_id, @forward_seconds)
      send_message(msg.channel_id, "Forwarded #{@forward_seconds} seconds")
    else
      send_message(msg.channel_id, "No track is currently playing!")
    end
  end

  def handle_backward(%{msg: msg}) do
    if get_current_track(msg.guild_id) do
      Nostrum.Voice.seek_relative(msg.guild_id, -@backward_seconds)
      send_message(msg.channel_id, "Rewound #{@backward_seconds} seconds")
    else
      send_message(msg.channel_id, "No track is currently playing!")
    end
  end

  def handle_queue(%{msg: msg}) do
    current_track = get_current_track(msg.guild_id)
    queue = get_queue(msg.guild_id)
    cond do
      current_track == nil and queue == [] ->
        send_message(msg.channel_id, "Queue is empty!")
      true ->
        queue_text = build_queue_text(current_track, queue)
        send_message(msg.channel_id, queue_text)
    end
  end

  def handle_leave(%{msg: msg}) do
    Nostrum.Voice.stop(msg.guild_id)
    queue_clear(msg.guild_id)
    set_current_track(msg.guild_id, nil)
    case Nostrum.Voice.leave_channel(msg.guild_id) do
      :ok ->
        send_message(msg.channel_id, "Left voice channel!")
      {:error, reason} ->
        send_message(msg.channel_id, "Error leaving voice channel: #{inspect(reason)}")
    end
  end


  defp ensure_voice_connection(msg) do
    case get_voice_channel(msg) do
      nil ->
        {:error, "You need to be in a voice channel!"}
      channel_id ->
        if Nostrum.Voice.ready?(msg.guild_id) do
          :ok
        else
          case join_voice_channel(msg.guild_id, channel_id, msg.channel_id) do
            :ok -> :ok
            {:error, reason} -> {:error, reason}
          end
        end
    end
  end

  defp join_voice_channel(guild_id, channel_id, text_channel_id) do
    case Nostrum.Voice.join_channel(guild_id, channel_id) do
      {:ok, _conn} ->
        send_message(text_channel_id, "Joined voice channel!")
        :ok
      :ok ->
        send_message(text_channel_id, "Joined voice channel!")
        :ok
      {:error, reason} ->
        send_message(text_channel_id, "Failed to join: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_play_request(guild_id, channel_id, url) do
    case get_video_info(url) do
      {:ok, title, final_url} ->
        queue_add(guild_id, final_url, title)
        case get_current_track(guild_id) do
          nil -> # Nothing is playing; start this track
            play_track(guild_id, channel_id, final_url, title)
          _ ->
            send_message(channel_id, "Added to queue: #{title}")
        end
      {:error, _reason} ->
        # Fallback to direct download if getting info fails
        file_path = "#{System.tmp_dir()}/#{:rand.uniform(999_999)}.mp3"
        args = [
          "-x",
          "--audio-format", "mp3",
          "--format", "bestaudio[ext=m4a]/bestaudio/best",
          "--no-playlist",
          "--no-warnings",
          "--print", "%(title)s",
          "--downloader", "aria2c",
          "--downloader-args", "aria2c:-x 16 -s 16 -k 1M",
          "-o", file_path,
          url
        ]
        case Porcelain.exec("yt-dlp", args, [err: :out]) do
          %{status: 0, out: title} ->
            queue_add(guild_id, file_path, String.trim(title))
            case get_current_track(guild_id) do
              nil ->
                play_track(guild_id, channel_id, file_path, String.trim(title))
              _ ->
                send_message(channel_id, "Added to queue: #{String.trim(title)}")
            end
          error ->
            Logger.error("Download error: #{inspect(error)}")
            send_message(channel_id, "Failed to process video. Please check the URL and try again.")
        end
    end
  end

  defp play_track(guild_id, channel_id, source, title) do
    if String.starts_with?(source, "http") do
      case download_youtube_audio(source, channel_id) do
        {:ok, path} ->
          do_play_track(guild_id, channel_id, path, title)
        {:error, reason} ->
          send_message(channel_id, "Error downloading audio: #{reason}")
      end
    else
      do_play_track(guild_id, channel_id, source, title)
    end
  end

  defp do_play_track(guild_id, channel_id, file_path, title) do
    set_current_track(guild_id, {file_path, title})
    case Nostrum.Voice.play(guild_id, file_path, :file) do
      :ok ->
        send_message(channel_id, "Now playing: #{title}")
        Nostrum.Voice.subscribe(guild_id, fn
          :END -> play_next_in_queue(guild_id, channel_id)
          _ -> :ok
        end)
      {:error, reason} ->
        set_current_track(guild_id, nil)
        send_message(channel_id, "Error playing audio: #{inspect(reason)}")
    end
  end

  defp play_next_in_queue(guild_id, channel_id) do
    case queue_next(guild_id) do
      nil ->
        set_current_track(guild_id, nil)
        send_message(channel_id, "Queue finished!")
      {url, title} ->
        play_track(guild_id, channel_id, url, title)
    end
  end

  defp get_video_info(url) do
    args = [
      "-j",
      "--no-playlist",
      "--no-warnings",
      url
    ]
    case Porcelain.exec("yt-dlp", args) do
      %{status: 0, out: output} ->
        case Jason.decode(output) do
          {:ok, data} ->
            title = data["title"]
            formats = data["formats"]
            audio_format = Enum.find(formats, fn format ->
              format["acodec"] != "none" and format["protocol"] in ["http", "https"]
            end)
            case audio_format do
              nil -> {:error, "No suitable audio format found"}
              format -> {:ok, title, format["url"]}
            end
          {:error, _} ->
            {:error, "Failed to parse video info"}
        end
      error ->
        Logger.error("yt-dlp error: #{inspect(error)}")
        {:error, "Failed to get video info"}
    end
  end

  defp download_youtube_audio(url, channel_id) do
    file_path = "#{System.tmp_dir()}/#{:rand.uniform(999_999)}.mp3"
    args = [
      "-x",
      "--audio-format", "mp3",
      "--format", "bestaudio[ext=m4a]/bestaudio/best",
      "--no-playlist",
      "--no-warnings",
      "--downloader", "aria2c",
      "--downloader-args", "aria2c:-x 16 -s 16 -k 1M",
      "-o", file_path,
      url
    ]
    {:ok, progress_msg} = Api.create_message(channel_id, "Downloading: 0%")
    proc = Porcelain.spawn("yt-dlp", args, [err: :stream, out: :stream])
    Enum.each(proc.out, fn line ->
      if String.contains?(line, "[download]") do
        case Regex.run(~r/\[download\]\s+([\d.]+)%/, line) do
          [_, percent_str] ->
            Api.edit_message(channel_id, progress_msg.id, %{content: "Downloading: #{percent_str}%"})
          _ ->
            :noop
        end
      end
    end)
    result = Porcelain.Process.await(proc)
    cond do
      result.status == 0 ->
        Api.edit_message(channel_id, progress_msg.id, %{content: "Download complete!"})
        {:ok, file_path}
      true ->
        err_out = result.out || ""
        error_message =
          if String.contains?(err_out, "Broken pipe") do
            "Download failed: Broken pipe error. This may be due to network/proxy issues or a too-long file path."
          else
            "Download failed with aria2c exit code #{result.status}: #{err_out}"
          end
        Api.edit_message(channel_id, progress_msg.id, %{content: error_message})
        {:error, error_message}
    end
  end

  defp get_voice_channel(msg) do
    with {:ok, guild} <- Nostrum.Cache.GuildCache.get(msg.guild_id) do
      Logger.debug("Guild voice states: #{inspect(guild.voice_states)}")
      Logger.debug("Author ID: #{inspect(msg.author.id)}")
      voice_state = Enum.find(guild.voice_states, fn state ->
        state.user_id == msg.author.id
      end)
      case voice_state do
        nil ->
          Logger.debug("User not found in voice states")
          nil
        state ->
          Logger.debug("Found voice state: #{inspect(state)}")
          state.channel_id
      end
    else
      error ->
        Logger.error("Error getting guild: #{inspect(error)}")
        nil
    end
  end

  defp get_voice_channel_users(guild_id, channel_id) do
    with {:ok, guild} <- Nostrum.Cache.GuildCache.get(guild_id) do
      users =
        guild.voice_states
        |> Enum.filter(fn state -> state.channel_id == channel_id end)
        |> Enum.map(fn state ->
          case Nostrum.Cache.UserCache.get(state.user_id) do
            {:ok, user} -> user.username
            _ -> "Unknown User"
          end
        end)
      {:ok, users}
    else
      _ -> {:error, "Could not get guild information"}
    end
  end

  defp build_queue_text(current_track, queue) do
    current = case current_track do
      nil -> ""
      {_url, title} -> "Now Playing: #{title}\n\n"
    end
    queue_items =
      queue
      |> Enum.with_index(1)
      |> Enum.map(fn {{_url, title}, index} -> "#{index}. #{title}" end)
      |> Enum.join("\n")
    case queue_items do
      "" -> current <> "Queue is empty!"
      items -> current <> "Queue:\n" <> items
    end
  end

  defp send_message(channel_id, content) do
    Api.create_message(channel_id, content)
  end
end

