defmodule Commands.Ranks do
  alias Vennie.{Repo, UserRank}
  import Ecto.Query
  require Logger

  @xp_per_message 1
  @base_xp_for_level 100
  @xp_increase_per_level 50
  @embedded_role_id 1339105757492416566
  @xp_role_id 1342150077841674291
  @regular_role_id 1342149453532102666

  def handle_message(msg) do
    now = DateTime.utc_now()
    
    case get_or_create_user_rank(msg.author.id) do
      {:ok, user_rank} ->
        new_xp = user_rank.xp + @xp_per_message
        new_level = calculate_level(new_xp)
        new_daily_xp = user_rank.daily_xp + @xp_per_message

        {new_daily_xp, reset_time} = 
          if should_reset_daily_xp?(user_rank.daily_xp_reset_at) do
            {new_daily_xp, now}
          else
            {new_daily_xp, user_rank.daily_xp_reset_at}
          end

        {:ok, updated_rank} = 
          user_rank
          |> UserRank.changeset(%{
            xp: new_xp,
            level: new_level,
            last_message_at: now,
            daily_xp: new_daily_xp,
            daily_xp_reset_at: reset_time
          })
          |> Repo.update()

        check_and_update_roles(msg.guild_id, msg.author.id, updated_rank)

      {:error, reason} ->
        Logger.error("Failed to handle message XP: #{inspect(reason)}")
    end
  end

  def handle_rank(context) do
    case get_user_id_from_context(context) do
      {:ok, user_id} ->
        case Repo.get_by(UserRank, user_id: user_id) do
          nil ->
            {:ok, _rank} = create_user_rank(user_id)
            send_rank_embed(context, user_id, 0, 0, 0)

          rank ->
            next_level_xp = calculate_xp_for_level(rank.level + 1)
            remaining_xp = next_level_xp - rank.xp
            send_rank_embed(context, user_id, rank.xp, rank.level, remaining_xp)
        end

      {:error, _reason} ->
        Nostrum.Api.create_message(context.msg.channel_id, "Invalid user mention or ID.")
    end
  end

  defp get_user_id_from_context(%{args: args, msg: msg}) do
    case args do
      [] -> {:ok, msg.author.id}
      [user_mention] ->
        case Regex.run(~r/<@!?(\d+)>/, user_mention) do
          [_, user_id] -> {:ok, String.to_integer(user_id)}
          nil -> 
            case Integer.parse(user_mention) do
              {user_id, ""} -> {:ok, user_id}
              _ -> {:error, :invalid_format}
            end
        end
      _ -> {:error, :invalid_format}
    end
  end

  defp send_rank_embed(context, user_id, xp, level, remaining_xp) do
    embed = %Nostrum.Struct.Embed{
      title: "Rank Information",
      description: "<@#{user_id}>",
      fields: [
        %{name: "Level", value: "#{level}", inline: true},
        %{name: "XP", value: "#{xp}", inline: true},
        %{name: "XP until next level", value: "#{remaining_xp}", inline: true}
      ],
      color: 0x7289DA
    }

    Nostrum.Api.create_message(context.msg.channel_id, embed: embed)
  end

  defp get_or_create_user_rank(user_id) do
    case Repo.get_by(UserRank, user_id: user_id) do
      nil -> create_user_rank(user_id)
      user_rank -> {:ok, user_rank}
    end
  end

  defp create_user_rank(user_id) do
    %UserRank{}
    |> UserRank.changeset(%{
      user_id: user_id,
      daily_xp_reset_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp calculate_level(xp) do
    Stream.iterate(1, &(&1 + 1))
    |> Enum.find(fn level ->
      calculate_xp_for_level(level) > xp
    end)
    |> Kernel.-(1)
  end

  defp calculate_xp_for_level(level) do
    @base_xp_for_level + (level - 1) * @xp_increase_per_level
  end

  defp should_reset_daily_xp?(reset_time) when is_nil(reset_time), do: true
  defp should_reset_daily_xp?(reset_time) do
    DateTime.compare(DateTime.utc_now(), DateTime.add(reset_time, 24 * 60 * 60, :second)) == :gt
  end

  defp check_and_update_roles(guild_id, user_id, rank) do
    if rank.level >= 5 do
      Nostrum.Api.add_guild_member_role(guild_id, user_id, @embedded_role_id)
    end

    if rank.level >= 10 do
      Nostrum.Api.add_guild_member_role(guild_id, user_id, @xp_role_id)
    end

    if rank.daily_xp >= 200 do
      Nostrum.Api.add_guild_member_role(guild_id, user_id, @regular_role_id)
    end
  end
end
