defmodule Commands.Utils do
  alias Nostrum.Api


  def websocket(%{msg: msg, args: _args}) do
    case Vennie.GatewayTracker.get_state() do
      nil ->
        Api.create_message(msg.channel_id, "WebSocket details not available yet!")

      ws_state ->
        details = 
          ws_state
          |> inspect(pretty: true)
          |> String.slice(0, 1900)

        Api.create_message(msg.channel_id, "WebSocket details:\n```elixir\n#{details}```\n

")
    end
  end
end
