defmodule Vennie.EmojiCache do
  require Logger

  @doc """
  Initializes the ETS table for emoji caching.
  Call this function during application startup.
  """
  def init do
    :ets.new(:emoji_cache, [:named_table, :public, :set])
  end

  @doc """
  Updates the emoji cache for a given guild by retrieving the emojis from the GuildCache.
  """
  def update_cache(guild_id) do
    case Nostrum.Cache.GuildCache.get(guild_id) do
      {_, guild} ->
        :ets.insert(:emoji_cache, {guild_id, guild.emojis})
        {:ok, guild.emojis}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Retrieves the cached emojis for the given guild_id.
  """
  def get_emojis(guild_id) do
    case :ets.lookup(:emoji_cache, guild_id) do
      [{^guild_id, emojis}] -> emojis
      [] -> nil
    end
  end
end

