defmodule Isuumo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Isuumo.Worker.start_link(arg)
      # {Isuumo.Worker, arg}
      {Plug.Cowboy, scheme: :http, plug: Isuumo.Router, port: 4000}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Isuumo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
