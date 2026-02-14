defmodule Jido.Otel.TracerTest do
  use ExUnit.Case, async: false

  alias Jido.Otel.Tracer

  require Record

  Record.defrecordp(:span, Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl"))
  Record.defrecordp(:event, Record.extract(:event, from_lib: "opentelemetry/include/otel_span.hrl"))
  Record.defrecordp(:status, Record.extract(:status, from_lib: "opentelemetry_api/include/opentelemetry.hrl"))

  setup do
    {:ok, _apps} = Application.ensure_all_started(:opentelemetry)

    if Process.whereis(:otel_test_exporter) != nil do
      raise "otel test exporter is already registered"
    end

    true = Process.register(self(), :otel_test_exporter)
    flush_exported_spans()

    on_exit(fn ->
      if Process.whereis(:otel_test_exporter) == self() do
        Process.unregister(:otel_test_exporter)
      end
    end)

    :ok
  end

  test "span_start/span_stop uses event-prefix name and maps attributes" do
    tracer_ctx =
      Tracer.span_start([:jido, :agent, :run], %{
        agent_id: "agent-1",
        attempt: 2,
        active: true,
        state: :running,
        tags: ["alpha", "beta"],
        mixed: [1, "two"],
        details: %{step: 3}
      })

    assert :ok = Tracer.span_stop(tracer_ctx, %{duration: 1234, retries: 1})

    exported_span = assert_exported_span()

    assert span(name: "jido.agent.run") = exported_span
    assert status(code: :ok) = span(exported_span, :status)

    attributes = span_attributes(exported_span)

    assert attributes["agent_id"] == "agent-1"
    assert attributes["attempt"] == 2
    assert attributes["active"] == true
    assert attributes["state"] == "running"
    assert attributes["tags"] == ["alpha", "beta"]
    assert is_binary(attributes["mixed"])
    assert is_binary(attributes["details"])
    assert attributes["duration"] == 1234
    assert attributes["retries"] == 1
  end

  test "span_exception sets error status and records exception attributes" do
    tracer_ctx = Tracer.span_start([:jido, :agent, :fail], %{agent_id: "agent-2"})

    {kind, reason, stacktrace} =
      try do
        raise ArgumentError, "invalid input"
      rescue
        error -> {:error, error, __STACKTRACE__}
      end

    assert :ok = Tracer.span_exception(tracer_ctx, kind, reason, stacktrace)

    exported_span = assert_exported_span()

    assert span(name: "jido.agent.fail") = exported_span
    assert status(code: :error) = span(exported_span, :status)

    attributes = span_attributes(exported_span)
    assert attributes["error.kind"] == "error"
    assert String.contains?(attributes["error.reason"], "invalid input")

    [exception_event | _] = span_events(exported_span)
    assert event(name: :exception) = exception_event

    event_attributes =
      exception_event
      |> event(:attributes)
      |> :otel_attributes.map()

    assert event_attributes["kind"] == "error"
    assert String.contains?(event_attributes["reason"], "invalid input")
    assert is_binary(event_attributes["stacktrace"])
  end

  test "Jido.Observe uses Jido.Otel.Tracer when configured in jido observability config" do
    previous_observability = Application.get_env(:jido, :observability, [])

    Application.put_env(
      :jido,
      :observability,
      Keyword.put(previous_observability, :tracer, Tracer)
    )

    on_exit(fn ->
      Application.put_env(:jido, :observability, previous_observability)
    end)

    assert :ok =
             Jido.Observe.with_span([:jido, :observe, :integration], %{component: :test}, fn ->
               :ok
             end)

    exported_span = assert_exported_span()

    assert span(name: "jido.observe.integration") = exported_span
    assert status(code: :ok) = span(exported_span, :status)
    assert span_attributes(exported_span)["component"] == "test"
  end

  defp assert_exported_span do
    assert_receive {:span, exported_span}, 1_000
    exported_span
  end

  defp span_attributes(exported_span) do
    exported_span
    |> span(:attributes)
    |> :otel_attributes.map()
  end

  defp span_events(exported_span) do
    exported_span
    |> span(:events)
    |> :otel_events.list()
  end

  defp flush_exported_spans do
    receive do
      {:span, _span} -> flush_exported_spans()
    after
      0 -> :ok
    end
  end
end
