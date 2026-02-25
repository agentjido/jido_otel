import Config

config :logger,
  level: :info

# Keep the SDK active without requiring an external collector by default.
config :opentelemetry,
  traces_exporter: :none

# OTP-safe default for async span lifecycles.
config :jido_otel,
  current_span_mode: :safe

import_config "#{config_env()}.exs"
