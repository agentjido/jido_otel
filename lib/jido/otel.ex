defmodule Jido.Otel do
  @moduledoc """
  OpenTelemetry extension for the Jido.Observe system.

  Jido.Otel provides integrated observability instrumentation for Jido-based
  applications, bridging the Jido ecosystem with standard OpenTelemetry practices.

  ## Overview

  This library is in active development. See the project README for more information.
  """

  @version "0.1.0"

  @doc """
  Returns the current package version.
  """
  @spec version() :: String.t()
  def version, do: @version
end
