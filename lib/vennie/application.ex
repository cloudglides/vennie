defmodule Vennie.Application do
  use Application

  def start(_type, _args) do
    children = [
      Vennie.Consumer,
      Vennie.GatewayTracker,
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
