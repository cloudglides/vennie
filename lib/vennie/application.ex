defmodule Vennie.Application do
  use Application
  def start(_type, _args) do
    children = [
      Vennie.NetworkMonitor,
      Vennie.Consumer,
      Vennie.GatewayTracker,
      Vennie.Repo
    ]

    opts = [strategy: :one_for_one, name: Vennie.Supervisor]
    Supervisor.start_link(children, opts)
  end
end


