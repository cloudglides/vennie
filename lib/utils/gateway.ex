defmodule Vennie.GatewayTracker do
  @table :gateway_tracker

  def init_ets do
    :ets.new(@table, [:set, :named_table, :public])
  end

  def set_state(ws_state) do
    :ets.insert(@table, {:ws_state, ws_state})
  end

  def get_state do
    case :ets.lookup(@table, :ws_state) do
      [{:ws_state, state}] -> state
      [] -> nil
    end
  end
end

