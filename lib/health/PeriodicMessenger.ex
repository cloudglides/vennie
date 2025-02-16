defmodule Vennie.PeriodicMessenger do
  use GenServer
  alias Nostrum.Api
  require Logger

  @channel_id 1282214150738542614
  @interval 10_000  # 10 seconds in milliseconds

  # Start the GenServer and register it under the module name
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_message()
    {:ok, state}
  end

  @impl true
  def handle_info(:send_message, state) do
    Logger.info("Sending periodic message to channel #{@channel_id}")
    
    case Api.create_message(@channel_id, "Periodic check: I'm still online!") do
      {:ok, _msg} ->
        :ok
      {:error, reason} ->
        Logger.error("Error sending message: #{inspect(reason)}")
    end

    schedule_message()
    {:noreply, state}
  end

  defp schedule_message do
    Process.send_after(self(), :send_message, @interval)
  end
end

