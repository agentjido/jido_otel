defmodule Jido.Otel.UnsafeInspect do
  @moduledoc false

  defstruct [:value]
end

defimpl Inspect, for: Jido.Otel.UnsafeInspect do
  def inspect(_value, _opts), do: raise("inspect failed")
end
