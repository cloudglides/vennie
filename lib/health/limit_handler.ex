defmodule Vennie.NetworkMonitor do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok)

  def init(:ok) do
    schedule_check()
    {:ok, nil}
  end

  def handle_info(:check_connection, state) do
    if Nostrum.Api.get_current_user() == :error do
      # Force reconnect if API fails
      Nostrum.Shard.Supervisor.restart_shards()
    end

    schedule_check()
    {:noreply, state}
  end

  defp schedule_check, do: Process.send_after(self(), :check_connection, 10_000)
end
