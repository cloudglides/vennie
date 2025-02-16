defmodule Vennie.GatewayTracker do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def set_state(ws_state) do
    Agent.update(__MODULE__, fn _ -> ws_state end)
  end

  def get_state do
    Agent.get(__MODULE__, & &1)
  end
end

