defmodule JidoOtel.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Supervision tree will be expanded with observable components
    ]

    opts = [strategy: :one_for_one, name: JidoOtel.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
