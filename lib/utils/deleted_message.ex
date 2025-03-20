defmodule Vennie.MessageCache do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def store_message(message) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, message.id, message)
    end)
  end

  def get_message(message_id) do
    Agent.get(__MODULE__, &Map.get(&1, message_id))
  end

  # Remove the message once it’s deleted
  def remove_message(message_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      {Map.get(state, message_id), Map.delete(state, message_id)}
    end)
  end
end

