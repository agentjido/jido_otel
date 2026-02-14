import Config

config :logger,
  level: :warning

config :opentelemetry,
  span_processor: :simple,
  traces_exporter: {:otel_exporter_pid, :otel_test_exporter}
