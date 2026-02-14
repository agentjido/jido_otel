defmodule JidoOtelTest do
  use ExUnit.Case
  doctest JidoOtel

  test "version is available" do
    assert JidoOtel.version() == "0.1.0"
  end
end
