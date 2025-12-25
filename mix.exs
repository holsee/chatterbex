defmodule Chatterbex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/holsee/chatterbex"

  def project do
    [
      app: :chatterbex,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Chatterbex",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Chatterbex.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Elixir wrapper for Chatterbox TTS - state-of-the-art text-to-speech
    models from Resemble AI with zero-shot voice cloning capabilities.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Chatterbox" => "https://github.com/resemble-ai/chatterbox"
      }
    ]
  end

  defp docs do
    [
      main: "Chatterbex",
      extras: ["README.md"]
    ]
  end
end
