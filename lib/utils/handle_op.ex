defmodule HandleOp do
  require Logger
  use GenServer
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def store_message(userid, messageid) do
    GenServer.cast(__MODULE__, {:store_message, userid, messageid})
  end

  def get_userid(messageid) do
    GenServer.call(__MODULE__, {:get_userid, messageid})
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast({:store_message, userid, messageid}, state) do
    Logger.debug("genserver #{messageid}")
    Logger.debug("genserver #{userid}")
    new_state = Map.put(state, messageid, %{userid: userid, timestamp: :os.system_time(:seconds)})
    Process.send_after(self(), {:expire_message, messageid}, 60_000)

    {:noreply, new_state}
  end

  def handle_call({:get_userid, messageid}, _from, state) do
    case Map.get(state, messageid) do
      nil -> 
        {:reply, nil, state}
      %{userid: userid, timestamp: timestamp} ->
        if :os.system_time(:seconds) - timestamp < 60 do
          {:reply, userid, state}
        else
          new_state = Map.delete(state, messageid)
          {:reply, nil, new_state}
        end
    end
  end
  def handle_info({:expire_message, messageid}, state) do
    new_state = Map.delete(state, messageid)
    {:noreply, new_state}
  end
end
