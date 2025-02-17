defmodule Commands.Moderation do
  require Logger
  alias Nostrum.Api
  alias Commands.Helpers.Duration
  import Bitwise

  @ban_permission 0x00000004
  @kick_permission 0x00000002
  @administrator  0x00000008

  # Checks whether the invoking member has the required permission.
  defp check_permission(%{msg: msg} = context, required_permission) do
    case Api.get_guild_member(msg.guild_id, msg.author.id) do
      {:ok, member} ->
        if has_permission?(member, msg.guild_id, required_permission) do
          :ok
        else
          {:error, "You do not have permission to perform this command."}
        end

      {:error, reason} ->
        {:error, "Failed to fetch member details: #{inspect(reason)}"}
    end
  end

  # Computes effective permissions for a member.
  defp has_permission?(member, guild_id, permission) do
    guild = Nostrum.Cache.GuildCache.get!(guild_id)
    member_role_ids = member.roles

    member_roles =
      guild.roles
      |> Enum.map(fn
           {_, role} -> role
           role when is_map(role) -> role
         end)
      |> Enum.filter(fn role -> role.id in member_role_ids end)

    effective_permissions =
      Enum.reduce(member_roles, 0, fn role, acc ->
        bor(acc, role.permissions)
      end)

    # Administrators have all permissions.
    if (effective_permissions &&& @administrator) > 0 do
      true
    else
      (effective_permissions &&& permission) > 0
    end
  end

  # ---------------------------
  # Kick Command
  # ---------------------------
  def kick(%{msg: msg, args: [raw_user_id | reason]} = context) do
    with :ok <- check_permission(context, @kick_permission) do
      case Api.create_message(msg.channel_id, "Processing kick command for #{raw_user_id}...") do
        {:ok, provisional_msg} ->
          Task.start(fn ->
            try do
              user_id = extract_id(raw_user_id)
              case Api.remove_guild_member(msg.guild_id, user_id) do
                {:ok, _} ->
                  reason_text =
                    if reason != [] do
                      Enum.join(reason, " ")
                    else
                      "No reason provided"
                    end

                  Api.edit_message(
                    msg.channel_id,
                    provisional_msg.id,
                    %{content: "Done! Kicked <@#{user_id}>. Reason: #{reason_text}"}
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
          Api.create_message(
            msg.channel_id,
            "Error creating provisional message: #{inspect(error)}"
          )
      end
    else
      {:error, error_msg} ->
        Api.create_message(msg.channel_id, error_msg)
    end
  end

  def kick(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vkick @user [reason]")
  end

  # ---------------------------
  # Ban Command
  # ---------------------------
  def ban(%{msg: msg, args: [raw_user_id | reason]} = context) do
    with :ok <- check_permission(context, @ban_permission) do
      case Api.create_message(msg.channel_id, "Processing ban command for #{raw_user_id}...") do
        {:ok, provisional_msg} ->
          Task.start(fn ->
            try do
              user_id = extract_id(raw_user_id)
              reason_text =
                if reason != [] do
                  Enum.join(reason, " ")
                else
                  "No reason provided"
                end

              case Api.create_guild_ban(
                     msg.guild_id,
                     user_id,
                     %{"delete_message_days" => 0, "reason" => reason_text}
                   ) do
                {:ok, _} ->
                  Api.edit_message(
                    msg.channel_id,
                    provisional_msg.id,
                    %{content: "Done! Banned <@#{user_id}>. Reason: #{reason_text}"}
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
          Api.create_message(
            msg.channel_id,
            "Error creating provisional message: #{inspect(error)}"
          )
      end
    else
      {:error, error_msg} ->
        Api.create_message(msg.channel_id, error_msg)
    end
  end

  def ban(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vban @user [reason]")
  end

  # ---------------------------
  # Other Commands (Examples)
  # ---------------------------
  def websocket(%{msg: msg, args: _args}) do
    case Vennie.GatewayTracker.get_state() do
      nil ->
        Api.create_message(msg.channel_id, "WebSocket details not available yet!")
      ws_state ->
        details =
          ws_state
          |> inspect(pretty: true)
          |> String.slice(0, 1900)

        Api.create_message(msg.channel_id, "WebSocket details:\n```elixir\n#{details}\n```")
    end
  end

  def mute(%{msg: msg, args: [raw_user_id, duration_str | _reason]} = _context) do
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
        Api.create_message(msg.channel_id, "Error creating provisional message: #{inspect(error)}")
    end
  end

  def mute(%{msg: msg}) do
    Api.create_message(
      msg.channel_id,
      "Usage: vmute @user <duration> [reason]\nDurations: 30m, 1h, 1d"
    )
  end

  def unmute(%{msg: msg, args: [raw_user_id | _]}) do
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

  def unmute(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vunmute @user")
  end

  def lock(%{msg: msg}) do
    channel_id = msg.channel_id

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

  # ---------------------------
  # Helper Functions
  # ---------------------------
  defp send_dm(user_id, message) do
    with {:ok, dm_channel} <- Api.create_dm(user_id),
         {:ok, _msg} <- Api.create_message(dm_channel.id, message) do
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

