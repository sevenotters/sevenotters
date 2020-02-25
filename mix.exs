defmodule Seven.Mixfile do
  use Mix.Project

  def project do
    [
      app: :seven,
      version: "0.1.1",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Seven Otters",
      source_url: "https://github.com/sevenotters",
      homepage_url: "https://www.sevenotters.org",
      docs: docs(),

      # Package
      description: "Seven Otters is a set of facilities (macroes, functions, modules, etc.) developed to create CQRS/ES solutions in Elixir on BEAM virtual machine.",
      package: package()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger], mod: {Seven.Application, []}]
  end

  defp docs do
    [
      main: "getting_started",
      logo: "markdown/icon.png",
      extras: ["markdown/getting_started.md"]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Nicola Fiorillo"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sevenotters/sevenotters"}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:atomic_map, "~> 0.9.3"},
      {:bunt, "~> 0.2.0"},
      {:cors_plug, "~> 2.0"},
      {:credo, "~> 1.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:mongodb, "~> 0.5"},
      {:plug, "~> 1.9"},
      {:poison, "~> 4.0"},
      {:poolboy, "~> 1.5"},
      {:timex, "~> 3.6"},
      {:uuid, "~> 1.1.8"},
      {:ve, "~> 0.1"}
    ]
  end
end
