defmodule Seven.Mixfile do
  use Mix.Project

  def project do
    [
      app: :seven,
      version: "0.1.0",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger], mod: {Seven.Application, []}]
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
      {:atomic_map, "== 0.9.3"},
      {:bunt, "== 0.2.0"},
      {:cors_plug, "== 1.5.2"},
      {:credo, "== 0.10.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:logger_file_backend, "== 0.0.10"},
      {:mongodb, "== 0.4.6"},
      {:plug, "== 1.6.3"},
      {:poison, "== 4.0.1"},
      {:poolboy, "== 1.5.1"},
      {:timex, "== 3.4.1"},
      {:uuid, "== 1.1.8"},
      {:ve, "== 0.1.9"}
    ]
  end
end
