defmodule Sparql.MixProject do
  use Mix.Project

  @github_url "https://github.com/langens-jonathan/sparql"

  def project do
    [
      app: :"sparqlex",
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
      name: "sparqlex",
      description: "An elixir library for parsing and handling SPARQL queries.",
      source_url: @github_url,
      homepage_url: @github_url,
      files: ~w(mix.exs lib LICENSE.md README.md CHANGELOG.md),
      package: [
        maintainers: ["Langens Jonathan"],
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:junit_formatter, "~> 2.1", only: :test},
      {:credo, "~> 0.8", only: [:dev, :test]},
      {:excoveralls, "~> 0.8", only: :test}
    ]
  end
end
