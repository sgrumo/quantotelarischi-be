defmodule Quantomelarischio.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QuantomelarischioWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:quantomelarischio, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Quantomelarischio.PubSub},
      {Registry, keys: :unique, name: Quantomelarischio.RoomRegistry},
      {DynamicSupervisor, name: Quantomelarischio.RoomSupervisor, strategy: :one_for_one},
      # Start a worker by calling: Quantomelarischio.Worker.start_link(arg)
      # {Quantomelarischio.Worker, arg},
      # Start to serve requests, typically the last entry
      QuantomelarischioWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Quantomelarischio.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QuantomelarischioWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
