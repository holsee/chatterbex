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
      logo: "chatterbex_logo.png",
      extras: [
        "README.md",
        "LICENSE",
        "examples/README.md",
        "docs/adr/README.md",
        "docs/adr/template.md",
        "docs/adr/0001-erlang-ports-for-python-interop.md",
        "docs/adr/0002-genserver-per-model-instance.md",
        "docs/adr/0003-json-base64-ipc-protocol.md",
        "docs/adr/0004-mix-task-for-python-setup.md",
        "docs/adr/0005-apple-silicon-mps-support.md"
      ],
      groups_for_extras: [
        Examples: ~r/examples\//,
        "Architecture Decisions": ~r/docs\/adr\//
      ]
    ]
  end
end
