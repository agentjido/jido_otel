defmodule Jido.Otel.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: Supervisor.on_start()
  def start(_type, _args) do
    children = [
      # Supervision tree will be expanded with observable components
    ]

    opts = [strategy: :one_for_one, name: Jido.Otel.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
