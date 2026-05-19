defmodule Jido.Otel.TracerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Jido.Otel.Tracer

  require OpenTelemetry.Tracer, as: OTelTracer
  require Record

  Record.defrecordp(:span, Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl"))
  Record.defrecordp(:event, Record.extract(:event, from_lib: "opentelemetry/include/otel_span.hrl"))
  Record.defrecordp(:status, Record.extract(:status, from_lib: "opentelemetry_api/include/opentelemetry.hrl"))

  setup do
    {:ok, _apps} = Application.ensure_all_started(:opentelemetry)
    previous_span_mode = Application.get_env(:jido_otel, :current_span_mode, :__missing__)

    Application.put_env(:jido_otel, :current_span_mode, :safe)

    if Process.whereis(:otel_test_exporter) != nil do
      raise "otel test exporter is already registered"
    end

    true = Process.register(self(), :otel_test_exporter)
    flush_exported_spans()

    on_exit(fn ->
      restore_env(:jido_otel, :current_span_mode, previous_span_mode)

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

    exception_event = Enum.find(span_events(exported_span), &(event(&1, :name) == :exception))
    assert exception_event != nil

    event_attributes =
      exception_event
      |> event(:attributes)
      |> :otel_attributes.map()

    assert get_event_attr(event_attributes, "kind") == "error"
    assert String.contains?(get_event_attr(event_attributes, "reason"), "invalid input")

    assert is_binary(
             get_event_attr(event_attributes, "exception.stacktrace") ||
               get_event_attr(event_attributes, "stacktrace")
           )
  end

  test "supports empty prefix names and normalizes additional attribute types" do
    tracer_ctx =
      Tracer.span_start([], %{
        {:complex, :key} => "tuple-key",
        empty_list: [],
        bools: [true, false],
        ints: [1, 2],
        floats: [1.5, 2.5],
        atoms: [:one, :two]
      })

    assert :ok = Tracer.span_stop(tracer_ctx, %{})

    exported_span = assert_exported_span()

    assert span(name: "jido.span") = exported_span

    attributes = span_attributes(exported_span)

    # Empty lists are normalized in the tracer but may be dropped by the OTel SDK.
    assert attributes["bools"] == [true, false]
    assert attributes["ints"] == [1, 2]
    assert attributes["floats"] == [1.5, 2.5]
    assert attributes["atoms"] == ["one", "two"]
    assert attributes["{:complex, :key}"] == "tuple-key"
  end

  test "normalizes non-atom event prefix segments without crashing" do
    tracer_ctx = Tracer.span_start([:jido, "agent", 42], %{})
    assert :ok = Tracer.span_stop(tracer_ctx, %{})

    assert span(name: "jido.agent.42") = assert_exported_span()
  end

  test "sanitizes sensitive, stacktrace, and high-cardinality span attributes" do
    long_value = String.duplicate("x", 700)

    tracer_ctx =
      Tracer.span_start([:jido, :agent, :sanitize], %{
        api_key: "secret-api-key",
        authorization: "Bearer secret-token",
        stacktrace: [{__MODULE__, :test, 0, []}],
        message: long_value,
        labels: Enum.map(1..30, &"label-#{&1}"),
        details: %{token: "nested-secret", payload: long_value}
      })

    assert :ok = Tracer.span_stop(tracer_ctx, %{})

    attributes = assert_exported_span() |> span_attributes()

    assert attributes["api_key"] == "[REDACTED]"
    assert attributes["authorization"] == "[REDACTED]"
    assert attributes["stacktrace"] == "[OMITTED]"
    assert attributes["message"] =~ "(truncated)"
    assert String.length(attributes["message"]) < 600
    assert length(attributes["labels"]) == 20
    refute "label-21" in attributes["labels"]
    assert attributes["details"] =~ "[REDACTED]"
    refute attributes["details"] =~ "nested-secret"
  end

  test "safe mode does not leak caller current span across async finish" do
    before_span_ctx = OTelTracer.current_span_ctx()
    tracer_ctx = Tracer.span_start([:jido, :agent, :async_safe], %{})

    assert :ok =
             Task.async(fn ->
               Tracer.span_stop(tracer_ctx, %{duration: 1})
             end)
             |> Task.await()

    assert before_span_ctx == OTelTracer.current_span_ctx()
    assert span(name: "jido.agent.async_safe") = assert_exported_span()
  end

  test "activate_unsafe mode restores current span on same-process finish" do
    Application.put_env(:jido_otel, :current_span_mode, :activate_unsafe)

    before_span_ctx = OTelTracer.current_span_ctx()
    tracer_ctx = Tracer.span_start([:jido, :agent, :unsafe_sync], %{})

    refute before_span_ctx == OTelTracer.current_span_ctx()
    assert :ok = Tracer.span_stop(tracer_ctx, %{})
    assert before_span_ctx == OTelTracer.current_span_ctx()

    assert span(name: "jido.agent.unsafe_sync") = assert_exported_span()
  end

  test "activate_unsafe mode warns when terminal callback runs in another process" do
    Application.put_env(:jido_otel, :current_span_mode, :activate_unsafe)
    tracer_ctx = Tracer.span_start([:jido, :agent, :unsafe_async], %{})

    log =
      capture_log(fn ->
        assert :ok =
                 Task.async(fn ->
                   Tracer.span_stop(tracer_ctx, %{})
                 end)
                 |> Task.await()
      end)

    assert log =~ "current_span_mode is :activate_unsafe"
    assert span(name: "jido.agent.unsafe_async") = assert_exported_span()
  end

  test "invalid current_span_mode logs warning and falls back to safe behavior" do
    Application.put_env(:jido_otel, :current_span_mode, :invalid_mode)
    before_span_ctx = OTelTracer.current_span_ctx()

    log =
      capture_log(fn ->
        tracer_ctx = Tracer.span_start([:jido, :agent, :invalid_mode], %{})

        assert :ok =
                 Task.async(fn ->
                   Tracer.span_stop(tracer_ctx, %{})
                 end)
                 |> Task.await()
      end)

    assert log =~ "Invalid :jido_otel current_span_mode"
    assert before_span_ctx == OTelTracer.current_span_ctx()
    assert span(name: "jido.agent.invalid_mode") = assert_exported_span()
  end

  test "concurrent stop and exception export exactly one terminal span" do
    tracer_ctx = Tracer.span_start([:jido, :agent, :race], %{})

    stop_task =
      Task.async(fn ->
        Tracer.span_stop(tracer_ctx, %{duration: 5})
      end)

    exception_task =
      Task.async(fn ->
        Tracer.span_exception(tracer_ctx, :error, :boom, [])
      end)

    assert :ok = Task.await(stop_task)
    assert :ok = Task.await(exception_task)

    exported_spans = collect_exported_spans(300)
    assert length(exported_spans) == 1

    [exported_span] = exported_spans
    assert span(name: "jido.agent.race") = exported_span
    assert status(span(exported_span, :status), :code) in [:ok, :error]
  end

  test "terminal lifecycle is idempotent under repeated concurrent finish attempts" do
    span_counts =
      Enum.map(1..25, fn iteration ->
        flush_exported_spans()

        tracer_ctx = Tracer.span_start([:jido, :agent, :idempotent, iteration], %{})

        tasks = [
          Task.async(fn -> Tracer.span_stop(tracer_ctx, %{iteration: iteration}) end),
          Task.async(fn -> Tracer.span_exception(tracer_ctx, :error, :boom, []) end),
          Task.async(fn -> Tracer.span_stop(tracer_ctx, %{iteration: iteration, retry: true}) end)
        ]

        Enum.each(tasks, fn task ->
          assert :ok = Task.await(task)
        end)

        collect_exported_spans(300)
        |> length()
      end)

    assert Enum.all?(span_counts, &(&1 == 1))
  end

  test "span_stop handles foreign started_by contexts safely" do
    Application.put_env(:jido_otel, :current_span_mode, :activate_unsafe)

    tracer_ctx = Tracer.span_start([:jido, :agent, :foreign], %{})

    foreign_pid =
      spawn(fn ->
        receive do
        end
      end)

    foreign_ctx = %{tracer_ctx | started_by: foreign_pid}

    log =
      capture_log(fn ->
        assert :ok = Tracer.span_stop(foreign_ctx, %{})
      end)

    assert log =~ "current_span_mode is :activate_unsafe"
    assert span(name: "jido.agent.foreign") = assert_exported_span()

    Process.exit(foreign_pid, :kill)
  end

  test "with_span_scope activates a sync parent span and restores caller context" do
    before_span_ctx = OTelTracer.current_span_ctx()

    result =
      Tracer.with_span_scope([:jido, :scope, :parent], %{component: :test}, fn ->
        parent_span_ctx = OTelTracer.current_span_ctx()
        refute parent_span_ctx == before_span_ctx

        child_span_ctx =
          OTelTracer.start_span("jido.scope.child", %{attributes: %{child: true}})

        OpenTelemetry.Span.end_span(child_span_ctx)

        assert parent_span_ctx == OTelTracer.current_span_ctx()
        :scoped_result
      end)

    assert result == :scoped_result
    assert before_span_ctx == OTelTracer.current_span_ctx()

    exported_spans = collect_exported_spans(1_000)
    parent_span = span_by_name(exported_spans, "jido.scope.parent")
    child_span = span_by_name(exported_spans, "jido.scope.child")

    assert status(code: :ok) = span(parent_span, :status)
    assert span(child_span, :trace_id) == span(parent_span, :trace_id)
    assert span(child_span, :parent_span_id) == span(parent_span, :span_id)
  end

  test "with_span_scope records escaped exceptions and restores caller context" do
    before_span_ctx = OTelTracer.current_span_ctx()

    assert_raise RuntimeError, "scoped failure", fn ->
      Tracer.with_span_scope([:jido, :scope, :failure], %{}, fn ->
        raise "scoped failure"
      end)
    end

    assert before_span_ctx == OTelTracer.current_span_ctx()

    exported_span = assert_exported_span()

    assert span(name: "jido.scope.failure") = exported_span
    assert status(code: :error) = span(exported_span, :status)
    assert span_attributes(exported_span)["error.kind"] == "error"
    assert Enum.any?(span_events(exported_span), &(event(&1, :name) == :exception))
  end

  test "span_stop and span_exception ignore invalid tracer contexts" do
    assert :ok = Tracer.span_stop(:invalid_ctx, %{duration: 1})
    assert :ok = Tracer.span_exception(:invalid_ctx, :error, :boom, [])

    refute_receive {:span, _exported_span}, 50
  end

  test "Jido.Observe uses Jido.Otel.Tracer in safe mode when configured in jido observability config" do
    previous_observability = Application.get_env(:jido, :observability, [])
    before_span_ctx = OTelTracer.current_span_ctx()

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
    assert before_span_ctx == OTelTracer.current_span_ctx()
  end

  test "Jido.Observe async span finish does not leak caller context in safe mode" do
    previous_observability = Application.get_env(:jido, :observability, [])
    before_span_ctx = OTelTracer.current_span_ctx()

    Application.put_env(
      :jido,
      :observability,
      Keyword.put(previous_observability, :tracer, Tracer)
    )

    on_exit(fn ->
      Application.put_env(:jido, :observability, previous_observability)
    end)

    span_ctx = Jido.Observe.start_span([:jido, :observe, :async], %{component: :test})

    assert :ok =
             Task.async(fn ->
               Jido.Observe.finish_span(span_ctx, %{duration: 42})
             end)
             |> Task.await()

    assert before_span_ctx == OTelTracer.current_span_ctx()

    exported_span = assert_exported_span()
    assert span(name: "jido.observe.async") = exported_span
    assert status(code: :ok) = span(exported_span, :status)
    assert span_attributes(exported_span)["duration"] == 42
  end

  test "Jido.Observe.with_span uses scoped callback for nested OpenTelemetry spans" do
    previous_observability = Application.get_env(:jido, :observability, [])
    before_span_ctx = OTelTracer.current_span_ctx()

    Application.put_env(
      :jido,
      :observability,
      Keyword.put(previous_observability, :tracer, Tracer)
    )

    on_exit(fn ->
      Application.put_env(:jido, :observability, previous_observability)
    end)

    assert :ok =
             Jido.Observe.with_span([:jido, :observe, :scoped], %{component: :test}, fn ->
               child_span_ctx =
                 OTelTracer.start_span("jido.observe.scoped.child", %{
                   attributes: %{child: true}
                 })

               OpenTelemetry.Span.end_span(child_span_ctx)
               :ok
             end)

    assert before_span_ctx == OTelTracer.current_span_ctx()

    exported_spans = collect_exported_spans(1_000)
    parent_span = span_by_name(exported_spans, "jido.observe.scoped")
    child_span = span_by_name(exported_spans, "jido.observe.scoped.child")

    assert status(code: :ok) = span(parent_span, :status)
    assert span(child_span, :trace_id) == span(parent_span, :trace_id)
    assert span(child_span, :parent_span_id) == span(parent_span, :span_id)
  end

  defp assert_exported_span do
    assert_receive {:span, exported_span}, 1_000
    exported_span
  end

  defp collect_exported_spans(timeout_ms) do
    deadline_ms = System.monotonic_time(:millisecond) + timeout_ms
    do_collect_exported_spans(deadline_ms, [])
  end

  defp do_collect_exported_spans(deadline_ms, acc) do
    remaining_ms = deadline_ms - System.monotonic_time(:millisecond)

    if remaining_ms > 0 do
      receive do
        {:span, exported_span} -> do_collect_exported_spans(deadline_ms, [exported_span | acc])
      after
        remaining_ms -> Enum.reverse(acc)
      end
    else
      Enum.reverse(acc)
    end
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

  defp span_by_name(exported_spans, name) do
    Enum.find(exported_spans, &(span(&1, :name) == name)) ||
      flunk(
        "expected exported span named #{inspect(name)}, " <>
          "got #{inspect(Enum.map(exported_spans, &span(&1, :name)))}"
      )
  end

  defp get_event_attr(event_attributes, key) do
    Map.get(event_attributes, key) || maybe_get_atom_attr(event_attributes, key)
  end

  defp maybe_get_atom_attr(event_attributes, key) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    if atom_key do
      Map.get(event_attributes, atom_key)
    end
  end

  defp flush_exported_spans do
    receive do
      {:span, _span} -> flush_exported_spans()
    after
      0 -> :ok
    end
  end

  defp restore_env(app, key, :__missing__), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
