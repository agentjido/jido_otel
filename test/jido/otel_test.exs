defmodule Jido.OtelTest do
  use ExUnit.Case, async: true
  doctest Jido.Otel

  test "version is available" do
    assert Jido.Otel.version() == "0.1.0"
  end
end
