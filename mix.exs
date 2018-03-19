defmodule Sparql.MixProject do
  use Mix.Project

  def project do
    [
      app: :sparql,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      package: package(),
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
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package do
    [
      maintainers: ["Langens Jonathan"],
      licenses: ["MIT"],
      links: ["https://github.com/langens-jonathan/ebnf.git"]
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
