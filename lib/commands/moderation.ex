defmodule Commands.Moderation do
  require Logger
  alias Nostrum.Api
  alias Commands.Helpers.Duration
  alias Vennie.Repo
  alias Vennie.Ban
  import Ecto.Query
  import Bitwise

  @ban_permission 0x00000004
  @kick_permission 0x00000002
  @administrator 0x00000008
  @manage_channels 0x00000010

  # ---------------------------
  # Permission Checking
  # ---------------------------
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

defp has_permission?(member, guild_id, permission) do
  # Check if user has the special bypass role
  if 1339183257736052777 in member.roles do
    true
  else
    # Original permission check logic
    guild = Nostrum.Cache.GuildCache.get!(guild_id)
    member_roles =
      guild.roles
      |> Enum.map(fn
        {_, role} -> role
        role when is_map(role) -> role
      end)
      |> Enum.filter(fn role -> role.id in member.roles end)

    effective_permissions =
      Enum.reduce(member_roles, 0, fn role, acc ->
        bor(acc, role.permissions)
      end)

    if (effective_permissions &&& @administrator) > 0 do
      true
    else
      (effective_permissions &&& permission) > 0
    end
  end
end

  # ---------------------------
  # Helpers
  # ---------------------------
  defp extract_user_id(input) do
    cond do
      # Match mention format: <@!123456789> or <@123456789>
      Regex.match?(~r/^<@!?(\d+)>$/, input) ->
        case Regex.run(~r/^<@!?(\d+)>$/, input) do
          [_, id] ->
            case Integer.parse(id) do
              {user_id, ""} -> {:ok, user_id}
              _ -> {:error, :invalid_user}
            end
          _ ->
            {:error, :invalid_user}
        end

      # Match raw ID format: 123456789
      Regex.match?(~r/^\d+$/, input) ->
        case Integer.parse(input) do
          {user_id, ""} -> {:ok, user_id}
          _ -> {:error, :invalid_user}
        end

      true ->
        {:error, :invalid_user}
    end
  end

  defp send_dm(user_id, message) do
    with {:ok, dm_channel} <- Api.create_dm(user_id),
         {:ok, _msg} <- Api.create_message(dm_channel.id, message) do
      :ok
    else
      {:error, error} ->
        Logger.error("Failed to send DM: #{inspect(error)}")
        {:error, error}
    end
  end

  # ---------------------------
  # Ban Command
  # ---------------------------
  def ban(%{msg: msg, args: [raw_user_id | reason]} = context) do
    with :ok <- check_permission(context, @ban_permission),
         {:ok, user_id} <- extract_user_id(raw_user_id) do
      case Api.create_message(msg.channel_id, "Processing ban command...") do
        {:ok, provisional_msg} ->
          Task.start(fn ->
            try do
              reason_text =
                if reason != [], do: Enum.join(reason, " "), else: "No reason provided"

              guild =
                case Api.get_guild(msg.guild_id) do
                  {:ok, guild_data} -> guild_data
                  _ -> nil
                end

              dm_message = """
              You have been banned from the #{guild && guild.name || "server"} Server by #{msg.author.username}.
              # Reason:
              ```#{msg.author.username}: #{reason_text}```
              """
              _ = send_dm(user_id, dm_message)

              ban_attrs = %{
                user_id: user_id,
                ban_reason: reason_text,
                banned_by: msg.author.id,
                banned_at: DateTime.utc_now() |> DateTime.truncate(:second)
              }

              # Use the changeset so only the allowed fields are inserted
              changeset = Ban.changeset(%Ban{}, ban_attrs)

              case Repo.insert(changeset) do
                {:ok, _record} ->
                  case Api.create_guild_ban(msg.guild_id, user_id, 0, reason_text) do
                    {:ok} ->
                      Api.edit_message(
                        msg.channel_id,
                        provisional_msg.id,
                        %{content: "Done! Banned <@#{user_id}>. Reason: #{reason_text}"}
                      )

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

                {:error, db_error} ->
                  Api.edit_message(
                    msg.channel_id,
                    provisional_msg.id,
                    %{content: "Database error: #{inspect(db_error)}"}
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
    else
      {:error, :invalid_user} ->
        Api.create_message(
          msg.channel_id,
          "Invalid user format. Please mention a user or provide a valid ID."
        )
      {:error, error_msg} ->
        Api.create_message(msg.channel_id, error_msg)
    end
  end

  def ban(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vban @user [reason]")
  end

  # ---------------------------
  # Unban Command
  # ---------------------------
  def unban(%{msg: msg, args: [raw_user_id | reason]} = context) do
    with :ok <- check_permission(context, @ban_permission),
         {:ok, user_id} <- extract_user_id(raw_user_id) do
      case Api.create_message(msg.channel_id, "Processing unban command...") do
        {:ok, provisional_msg} ->
          Task.start(fn ->
            try do
              reason_text =
                if reason != [], do: Enum.join(reason, " "), else: "No reason provided"

              case Repo.delete_all(from b in Ban, where: b.user_id == ^user_id) do
                {_, _} ->
                  case Api.remove_guild_ban(msg.guild_id, user_id, reason_text) do
                    {:ok} ->
                      Api.edit_message(
                        msg.channel_id,
                        provisional_msg.id,
                        %{content: "Done! Unbanned user ID #{user_id}. Reason: #{reason_text}"}
                      )

                    {:ok, _} ->
                      Api.edit_message(
                        msg.channel_id,
                        provisional_msg.id,
                        %{content: "Done! Unbanned user ID #{user_id}. Reason: #{reason_text}"}
                      )

                    {:error, error} ->
                      Api.edit_message(
                        msg.channel_id,
                        provisional_msg.id,
                        %{content: "Error: #{inspect(error)}"}
                      )
                  end
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
    else
      {:error, :invalid_user} ->
        Api.create_message(
          msg.channel_id,
          "Invalid user format. Please mention a user or provide a valid ID."
        )
      {:error, error_msg} ->
        Api.create_message(msg.channel_id, error_msg)
    end
  end

  def unban(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vunban <user_id> [reason]")
  end

  # ---------------------------
  # Ban Info Command
  # ---------------------------
  def baninfo(%{msg: msg, args: [raw_user_id | _]} = context) do
    with :ok <- check_permission(context, @ban_permission),
         {:ok, user_id} <- extract_user_id(raw_user_id) do
      case Repo.get_by(Ban, user_id: user_id) do
        nil ->
          Api.create_message(msg.channel_id, "No ban record found for this user.")

        ban ->
          formatted_time =
            ban.banned_at
            |> DateTime.from_naive!("Etc/UTC")
            |> DateTime.to_iso8601()

          response = """
          Ban information for <@#{user_id}>:
          **Reason:** #{ban.ban_reason}
          **Banned By:** <@#{ban.banned_by}>
          **Banned At:** #{formatted_time}
          """

          Api.create_message(msg.channel_id, response)
      end
    else
      {:error, :invalid_user} ->
        Api.create_message(
          msg.channel_id,
          "Invalid user format. Please mention a user or provide a valid ID."
        )
      {:error, error_msg} ->
        Api.create_message(msg.channel_id, error_msg)
    end
  end

  def baninfo(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vbaninfo <user_id>")
  end

  # ---------------------------
  # Kick Command
  # ---------------------------
  def kick(%{msg: msg, args: [raw_user_id | reason]} = context) do
    with :ok <- check_permission(context, @kick_permission),
         {:ok, user_id} <- extract_user_id(raw_user_id) do
      case Api.create_message(msg.channel_id, "Processing kick command...") do
        {:ok, provisional_msg} ->
          Task.start(fn ->
            try do
              reason_text =
                if reason != [], do: Enum.join(reason, " "), else: "No reason provided"

              {:ok, guild} = Api.get_guild(msg.guild_id)

              dm_message = """
              You have been kicked from the #{guild.name} Server by #{msg.author.username}.
              # Reason:
              ```#{msg.author.username}: #{reason_text}```
              """
              send_dm(user_id, dm_message)

              case Api.remove_guild_member(msg.guild_id, user_id, reason_text) do
                {:ok, _} ->
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
      {:error, :invalid_user} ->
        Api.create_message(
          msg.channel_id,
          "Invalid user format. Please mention a user or provide a valid ID."
        )
      {:error, error_msg} ->
        Api.create_message(msg.channel_id, error_msg)
    end
  end

  def kick(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vkick @user [reason]")
  end

  # ---------------------------
  # Mute Command
  # ---------------------------
  def mute(%{msg: msg, args: [raw_user_id, duration_str | reason]} = context) do
    with :ok <- check_permission(context, @manage_channels),
         {:ok, user_id} <- extract_user_id(raw_user_id) do
      case Api.create_message(msg.channel_id, "Processing mute command...") do
        {:ok, provisional_msg} ->
          Task.start(fn ->
            try do
              duration_seconds = Duration.parse_duration(duration_str)
              timeout_until =
                DateTime.utc_now()
                |> DateTime.add(duration_seconds, :second)
                |> DateTime.truncate(:second)

              reason_text =
                if reason != [], do: Enum.join(reason, " "), else: "No reason provided"

              {:ok, guild} = Api.get_guild(msg.guild_id)

              dm_message = """
              You have been muted in the #{guild.name} Server by #{msg.author.username} for #{duration_str}.
              # Reason:
              ```#{msg.author.username}: #{reason_text}```
              """
              send_dm(user_id, dm_message)

              case Api.modify_guild_member(
                     msg.guild_id,
                     user_id,
                     communication_disabled_until: DateTime.to_iso8601(timeout_until)
                   ) do
                {:ok, _} ->
                  Api.edit_message(
                    msg.channel_id,
                    provisional_msg.id,
                    %{
                      content:
                        "<a:bonk:1338730809510858772> Done! Muted <@#{user_id}> for #{duration_str}. Reason: #{reason_text}"
                    }
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
      {:error, :invalid_user} ->
        Api.create_message(
          msg.channel_id,
          "Invalid user format. Please mention a user or provide a valid ID."
        )
      {:error, error_msg} ->
        Api.create_message(msg.channel_id, error_msg)
    end
  end

  def mute(%{msg: msg}) do
    Api.create_message(
      msg.channel_id,
      "Usage: vmute @user <duration> [reason]\nDurations: 30m, 1h, 1d"
    )
  end

  # ---------------------------
  # Unmute Command
  # ---------------------------
  def unmute(%{msg: msg, args: [raw_user_id | reason]} = context) do
    with :ok <- check_permission(context, @manage_channels),
         {:ok, user_id} <- extract_user_id(raw_user_id) do
      case Api.create_message(msg.channel_id, "Processing unmute command...") do
        {:ok, provisional_msg} ->
          Task.start(fn ->
            try do
              reason_text =
                if reason != [], do: Enum.join(reason, " "), else: "No reason provided"

              {:ok, guild} = Api.get_guild(msg.guild_id)

              dm_message = """
              You have been unmuted in the #{guild.name} Server by #{msg.author.username}.
              # Reason:
              ```#{msg.author.username}: #{reason_text}```
              """
              send_dm(user_id, dm_message)

              case Api.modify_guild_member(
                     msg.guild_id,
                     user_id,
                     communication_disabled_until: nil
                   ) do
                {:ok, _} ->
                  Api.edit_message(
                    msg.channel_id,
                    provisional_msg.id,
                    %{content: "Done! Unmuted <@#{user_id}>. Reason: #{reason_text}"}
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

  def unmute(%{msg: msg}) do
    Api.create_message(msg.channel_id, "Usage: vunmute @user [reason]")
  end

  # ---------------------------
  # Lock Thread Command
  # ---------------------------
  def lock(%{msg: msg} = context) do
    with :ok <- check_permission(context, @manage_channels) do
      channel_id = msg.channel_id

      case Api.get_channel(channel_id) do
        {:ok, channel} ->
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

        {:error, error} ->
          Api.create_message(channel_id, "Error fetching channel details: #{inspect(error)}")
      end
    else
      {:error, error_msg} ->
        Api.create_message(msg.channel_id, error_msg)
    end
  end
end

