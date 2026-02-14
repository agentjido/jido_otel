defmodule Jido.Otel.Tracer do
  @moduledoc """
  OpenTelemetry tracer adapter for `Jido.Observe`.

  This module implements `Jido.Observe.Tracer` and maps Jido span lifecycle
  callbacks to OpenTelemetry spans.
  """

  @behaviour Jido.Observe.Tracer

  require OpenTelemetry.Tracer, as: Tracer

  alias OpenTelemetry.Span

  @typedoc """
  Context carried from `span_start/2` to stop/exception callbacks.
  """
  @type tracer_ctx :: %{
          span_ctx: OpenTelemetry.span_ctx(),
          previous_span_ctx: OpenTelemetry.span_ctx() | :undefined,
          started_by: pid()
        }

  @doc """
  Starts an OpenTelemetry span from a Jido event prefix and metadata map.

  The event prefix is converted to a dot-joined span name and metadata is
  normalized into OpenTelemetry-compatible span attributes.
  """
  @impl true
  @spec span_start(Jido.Observe.Tracer.event_prefix(), Jido.Observe.Tracer.metadata()) :: tracer_ctx()
  def span_start(event_prefix, metadata) when is_list(event_prefix) and is_map(metadata) do
    span_name = event_prefix_to_name(event_prefix)
    previous_span_ctx = Tracer.current_span_ctx()

    span_ctx =
      Tracer.start_span(
        span_name,
        %{
          kind: :internal,
          attributes: normalize_attributes(metadata)
        }
      )

    _ = Tracer.set_current_span(span_ctx)

    %{
      span_ctx: span_ctx,
      previous_span_ctx: previous_span_ctx,
      started_by: self()
    }
  end

  @doc """
  Finalizes a successful span and attaches measurements as span attributes.
  """
  @impl true
  @spec span_stop(Jido.Observe.Tracer.tracer_ctx(), Jido.Observe.Tracer.measurements()) :: :ok
  def span_stop(tracer_ctx, measurements) when is_map(measurements) do
    case tracer_ctx do
      %{span_ctx: span_ctx} = ctx ->
        attributes = normalize_attributes(measurements)

        if map_size(attributes) > 0 do
          _ = Span.set_attributes(span_ctx, attributes)
        end

        _ = :otel_span.set_status(span_ctx, :ok)
        _ = Span.end_span(span_ctx)

        maybe_restore_previous_span(ctx)

      _ ->
        :ok
    end

    :ok
  end

  @doc """
  Finalizes a failed span, records an exception event, and marks the span as error.
  """
  @impl true
  @spec span_exception(Jido.Observe.Tracer.tracer_ctx(), atom(), term(), list()) :: :ok
  def span_exception(tracer_ctx, kind, reason, stacktrace) when is_atom(kind) and is_list(stacktrace) do
    case tracer_ctx do
      %{span_ctx: span_ctx} = ctx ->
        _ =
          Span.add_event(
            span_ctx,
            :exception,
            normalize_attributes(%{
              kind: kind,
              reason: reason,
              stacktrace: Exception.format_stacktrace(stacktrace)
            })
          )

        _ =
          Span.set_attributes(
            span_ctx,
            normalize_attributes(%{
              "error.kind" => kind,
              "error.reason" => reason
            })
          )

        _ = :otel_span.set_status(span_ctx, :error)
        _ = Span.end_span(span_ctx)

        maybe_restore_previous_span(ctx)

      _ ->
        :ok
    end

    :ok
  end

  defp maybe_restore_previous_span(%{
         previous_span_ctx: previous_span_ctx,
         started_by: started_by
       })
       when started_by == self() do
    _ = Tracer.set_current_span(previous_span_ctx)
    :ok
  end

  defp maybe_restore_previous_span(_), do: :ok

  defp event_prefix_to_name([]), do: "jido.span"
  defp event_prefix_to_name(event_prefix), do: Enum.map_join(event_prefix, ".", &Atom.to_string/1)

  defp normalize_attributes(attributes) do
    Enum.reduce(attributes, %{}, fn {key, value}, acc ->
      Map.put(acc, normalize_key(key), normalize_value(value))
    end)
  end

  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: inspect(key, limit: 50, printable_limit: 200)

  defp normalize_value(value)
       when is_binary(value) or is_boolean(value) or is_integer(value) or is_float(value),
       do: value

  defp normalize_value(value) when is_atom(value), do: Atom.to_string(value)

  defp normalize_value([]), do: []

  defp normalize_value(value) when is_list(value) do
    cond do
      Enum.all?(value, &is_binary/1) ->
        value

      Enum.all?(value, &is_boolean/1) ->
        value

      Enum.all?(value, &is_integer/1) ->
        value

      Enum.all?(value, &is_float/1) ->
        value

      Enum.all?(value, &is_atom/1) ->
        Enum.map(value, &Atom.to_string/1)

      true ->
        inspect(value, limit: 50, printable_limit: 200)
    end
  end

  defp normalize_value(value), do: inspect(value, limit: 50, printable_limit: 200)
end
