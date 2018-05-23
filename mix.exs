defmodule MuAuthorization.MixProject do
  use Mix.Project

  @github_url "https://github.com/mu-semtech/mu-authorization"

  def project do
    [
      app: :"mu-authorization",
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      erlc_paths: ["parser-generator"],
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      name: "mu-authorization",
      description: "A proxy server that offers a authorization/delta wrapper for a SPARQL endpoint.",
      source_url: @github_url,
      homepage_url: @github_url,
      files: ~w(mix.exs lib LICENSE.md README.md CHANGELOG.md),
      package: [
        maintainers: ["Versteden Aad", "Langens Jonathan"],
        licenses: ["MIT"],
        links: %{
          "GitHub" => @github_url,
        }
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :httpoison, :poison, :plug, :cowboy],
      mod: {SparqlServer, []},
      env: ["sparql-port": 9980]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:junit_formatter, "~> 2.1", only: :test},
      {:credo, "~> 0.8", only: [:dev, :test]},
      {:excoveralls, "~> 0.8", only: :test},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:httpoison, "~> 1.1"},
      {:poison, "~> 3.1"},
      {:plug, "~> 1.5"},
      {:cowboy, "~> 2.4"}
    ]
  end
end
