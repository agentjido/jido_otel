import Config

config :logger,
  level: :info

# Keep the SDK active without requiring an external collector by default.
config :opentelemetry,
  traces_exporter: :none

import_config "#{config_env()}.exs"
