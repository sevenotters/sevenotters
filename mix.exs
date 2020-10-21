defmodule Seven.Mixfile do
  use Mix.Project

  def project do
    [
      app: :seven,
      version: "0.7.1",
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

  defp deps do
    [
      {:atomic_map, "~> 0.9"},
      {:bunt, "~> 0.2"},
      {:credo, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:uuid, "~> 1.1.8"}
    ]
  end
end
