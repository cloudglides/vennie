defmodule Vennie.DeletedMessageStore do
  use GenServer
  require Logger

  @max_messages 10

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def store_message(message) do
    GenServer.cast(__MODULE__, {:store, message})
  end

  def get_message(index) do
    GenServer.call(__MODULE__, {:get, index})
  end

  # Server Callbacks
  @impl true
  def init(_) do
    # Initialize with empty list for deleted messages
    {:ok, []}
  end

  @impl true
  def handle_cast({:store, message}, state) do
    # Add new message to the front of the list and limit to max size
    updated_state = [message | state] |> Enum.take(@max_messages)
    {:noreply, updated_state}
  end

  @impl true
  def handle_call({:get, index}, _from, state) do
    # Get message at specified index (1-based for user convenience)
    message = if index > 0 and index <= length(state) do
      Enum.at(state, index - 1)
    else
      nil
    end
    
    {:reply, message, state}
  end
end
