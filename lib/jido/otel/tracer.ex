defmodule Jido.Otel.Tracer do
  @moduledoc """
  OpenTelemetry tracer adapter for `Jido.Observe`.

  This module implements `Jido.Observe.Tracer` and maps Jido span lifecycle
  callbacks to OpenTelemetry spans.
  """

  @behaviour Jido.Observe.Tracer

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias OpenTelemetry.Span

  @inspect_limit 50
  @printable_limit 200
  @max_inspect_chars 512
  @max_stacktrace_chars 4_096

  @typedoc """
  Controls whether `span_start/2` mutates process-local current span context.

  `:safe` is OTP-safe across async boundaries and does not activate the started span
  as the current process span.
  `:activate_unsafe` preserves same-process activation/restore behavior.
  """
  @type current_span_mode :: :safe | :activate_unsafe

  defmodule Context do
    @moduledoc """
    Internal tracer context carried between span lifecycle callbacks.
    """

    @enforce_keys [:span_ctx, :terminal_guard, :mode, :started_by]
    defstruct span_ctx: nil,
              previous_span_ctx: :undefined,
              started_by: nil,
              mode: :safe,
              terminal_guard: nil

    @type t :: %__MODULE__{
            span_ctx: OpenTelemetry.span_ctx(),
            previous_span_ctx: OpenTelemetry.span_ctx() | :undefined,
            started_by: pid(),
            mode: Jido.Otel.Tracer.current_span_mode(),
            terminal_guard: :atomics.atomics_ref()
          }
  end

  @typedoc """
  Context carried from `span_start/2` to stop/exception callbacks.
  """
  @type tracer_ctx :: Context.t()

  @doc """
  Starts an OpenTelemetry span from a Jido event prefix and metadata map.

  The event prefix is converted to a dot-joined span name and metadata is
  normalized into OpenTelemetry-compatible span attributes.

  See `t:current_span_mode/0` for current-span activation behavior.
  """
  @impl true
  @spec span_start(Jido.Observe.Tracer.event_prefix(), Jido.Observe.Tracer.metadata()) :: tracer_ctx()
  def span_start(event_prefix, metadata) when is_list(event_prefix) and is_map(metadata) do
    mode = current_span_mode()
    span_name = event_prefix_to_name(event_prefix)
    previous_span_ctx = maybe_capture_previous_span(mode)

    span_ctx =
      Tracer.start_span(
        span_name,
        %{
          kind: :internal,
          attributes: normalize_attributes(metadata)
        }
      )

    _ = maybe_activate_span(mode, span_ctx)

    %Context{
      span_ctx: span_ctx,
      previous_span_ctx: previous_span_ctx,
      started_by: self(),
      mode: mode,
      terminal_guard: :atomics.new(1, signed: false)
    }
  end

  @doc """
  Finalizes a successful span and attaches measurements as span attributes.

  Terminal callbacks are idempotent: first terminal call wins.
  """
  @impl true
  @spec span_stop(Jido.Observe.Tracer.tracer_ctx(), Jido.Observe.Tracer.measurements()) :: :ok
  def span_stop(tracer_ctx, measurements) when is_map(measurements) do
    finalize_span(tracer_ctx, :ok, fn span_ctx ->
      maybe_set_attributes(span_ctx, measurements)
    end)
  end

  @doc """
  Finalizes a failed span, records an exception event, and marks the span as error.

  Terminal callbacks are idempotent: first terminal call wins.
  """
  @impl true
  @spec span_exception(Jido.Observe.Tracer.tracer_ctx(), atom(), term(), list()) :: :ok
  def span_exception(tracer_ctx, kind, reason, stacktrace) when is_atom(kind) and is_list(stacktrace) do
    finalize_span(tracer_ctx, :error, fn span_ctx ->
      _ = record_span_exception(span_ctx, kind, reason, stacktrace)

      maybe_set_attributes(span_ctx, %{
        "error.kind" => kind,
        "error.reason" => reason
      })
    end)
  end

  defp finalize_span(%Context{} = tracer_ctx, status, terminal_callback)
       when is_function(terminal_callback, 1) do
    if claim_terminal?(tracer_ctx.terminal_guard) do
      _ = run_terminal_callback(tracer_ctx.span_ctx, terminal_callback)
      _ = :otel_span.set_status(tracer_ctx.span_ctx, status)
      _ = Span.end_span(tracer_ctx.span_ctx)
      _ = maybe_restore_previous_span(tracer_ctx)
    end

    :ok
  end

  defp finalize_span(_tracer_ctx, _status, _terminal_callback), do: :ok

  defp claim_terminal?(terminal_guard) do
    :atomics.compare_exchange(terminal_guard, 1, 0, 1) == :ok
  end

  defp maybe_restore_previous_span(%Context{
         mode: :activate_unsafe,
         previous_span_ctx: previous_span_ctx,
         started_by: started_by
       })
       when started_by == self() do
    _ = Tracer.set_current_span(previous_span_ctx)
    :ok
  end

  defp maybe_restore_previous_span(%Context{
         mode: :activate_unsafe,
         started_by: started_by
       }) do
    Logger.warning(
      "Jido.Otel.Tracer received terminal callback in #{inspect(self())} for a span started by " <>
        "#{inspect(started_by)} while current_span_mode is :activate_unsafe; skipping span-context restore"
    )

    :ok
  end

  defp maybe_restore_previous_span(_), do: :ok

  defp current_span_mode do
    case Application.get_env(:jido_otel, :current_span_mode, :safe) do
      :safe ->
        :safe

      :activate_unsafe ->
        :activate_unsafe

      invalid ->
        Logger.warning("Invalid :jido_otel current_span_mode #{inspect(invalid)}. Falling back to :safe")

        :safe
    end
  end

  defp maybe_capture_previous_span(:activate_unsafe), do: Tracer.current_span_ctx()
  defp maybe_capture_previous_span(:safe), do: :undefined

  defp maybe_activate_span(:activate_unsafe, span_ctx) do
    _ = Tracer.set_current_span(span_ctx)
    :ok
  end

  defp maybe_activate_span(:safe, _span_ctx), do: :ok

  defp run_terminal_callback(span_ctx, terminal_callback) do
    terminal_callback.(span_ctx)
  rescue
    exception ->
      Logger.warning("Jido.Otel.Tracer terminal callback failed: #{Exception.message(exception)}")

      :ok
  end

  defp record_span_exception(span_ctx, kind, reason, stacktrace) do
    if is_exception(reason) do
      _ =
        Span.record_exception(
          span_ctx,
          reason,
          stacktrace,
          kind: Atom.to_string(kind),
          reason: truncate_string(Exception.message(reason), @max_inspect_chars)
        )
    else
      _ =
        Span.add_event(
          span_ctx,
          :exception,
          normalize_attributes(%{
            kind: kind,
            reason: reason,
            stacktrace: truncate_string(Exception.format_stacktrace(stacktrace), @max_stacktrace_chars)
          })
        )
    end

    :ok
  end

  defp maybe_set_attributes(span_ctx, attributes) when is_map(attributes) do
    normalized_attributes = normalize_attributes(attributes)

    if map_size(normalized_attributes) > 0 do
      _ = Span.set_attributes(span_ctx, normalized_attributes)
    end

    :ok
  end

  defp event_prefix_to_name([]), do: "jido.span"

  defp event_prefix_to_name(event_prefix),
    do: Enum.map_join(event_prefix, ".", &normalize_event_segment/1)

  defp normalize_event_segment(segment) when is_atom(segment), do: Atom.to_string(segment)
  defp normalize_event_segment(segment) when is_binary(segment), do: segment
  defp normalize_event_segment(segment), do: safe_inspect(segment, 20, 80)

  defp normalize_attributes(attributes) do
    Enum.reduce(attributes, %{}, fn {key, value}, acc ->
      Map.put(acc, normalize_key(key), normalize_value(value))
    end)
  end

  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: safe_inspect(key)

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
        safe_inspect(value)
    end
  end

  defp normalize_value(value), do: safe_inspect(value)

  defp safe_inspect(value, limit \\ @inspect_limit, printable_limit \\ @printable_limit) do
    value
    |> inspect(limit: limit, printable_limit: printable_limit)
    |> truncate_string(@max_inspect_chars)
  end

  defp truncate_string(value, max_chars) when is_binary(value) do
    if String.length(value) > max_chars do
      String.slice(value, 0, max_chars) <> "...(truncated)"
    else
      value
    end
  end
end
