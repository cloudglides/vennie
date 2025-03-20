defmodule Vennie.Consumer do
  @behaviour Nostrum.Consumer
  alias Nostrum.Api
  require Logger
  def handle_event({:READY, data, ws_state}) do
    Vennie.GatewayTracker.set_state(ws_state)
    Api.Self.update_status(:online, {:watching, "We Write Code"})
  end
  def handle_event({:INTERACTION_CREATE, msg, ws_state}) do
    Vennie.Events.Interaction.interaction_create(msg)
  end
  def handle_event({:MESSAGE_CREATE, msg, ws_state}) do
    Vennie.Events.Message.message_create(msg)
  end
  def handle_event({:MESSAGE_DELETE, data, ws_state}) do
    Vennie.Events.Message.message_delete(data)
  end
  def handle_event({:THREAD_CREATE, msg, ws_state}) do
    Vennie.Events.Thread.thread_create(msg)
  end
  def handle_event(_event), do: :noop
end
