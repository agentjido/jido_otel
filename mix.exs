defmodule Jido.Otel.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/agentjido/jido_otel"
  @description "OpenTelemetry tracer bridge for Jido.Observe"

  def project do
    [
      app: :jido_otel,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Documentation
      name: "Jido.Otel",
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url,

      # Hex
      package: package(),

      # Testing
      test_coverage: [
        tool: ExCoveralls,
        exclude_lines: [
          "def __info__",
          "case GenServer.info",
          "if is_nil\\(ets",
          "unless ets_mode",
          "Logger.warning",
          "raise.*RuntimeError"
        ]
      ],
      # Dialyzer
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {Jido.Otel.Application, []},
      extra_applications: [:logger, :opentelemetry]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Jido ecosystem
      {:jido, "~> 2.0.0-rc.2"},

      # OpenTelemetry runtime
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_api, "~> 1.5"},

      # Schema validation
      {:zoi, "~> 0.16"},

      # Error handling
      {:splode, "~> 0.3.0"},

      # JSON
      {:jason, "~> 1.4"},

      # Dev/Test
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:doctor, "~> 0.22", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test]},
      {:git_hooks, "~> 0.8", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.9", only: :dev, runtime: false},
      {:mimic, "~> 2.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      quality: [
        "format --check-formatted",
        "credo --strict",
        "dialyzer",
        "doctor --raise"
      ],
      "release.check": [
        "quality",
        "cmd env MIX_ENV=test mix test",
        "docs",
        "cmd mix hex.build"
      ],
      test: ["test --cover"]
    ]
  end

  defp docs do
    guides = Path.wildcard("guides/*.md") |> Enum.sort()

    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE" | guides],
      groups_for_extras: [
        Guides: guides,
        Reference: ["CHANGELOG.md", "CONTRIBUTING.md", "LICENSE"]
      ]
    ]
  end

  defp package do
    [
      description: @description,
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "HexDocs" => "https://hexdocs.pm/jido_otel"
      },
      maintainers: ["Jido Contributors"],
      files: [
        "lib",
        "guides",
        "mix.exs",
        ".formatter.exs",
        "README.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "LICENSE"
      ]
    ]
  end
end
