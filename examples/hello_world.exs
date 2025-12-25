#!/usr/bin/env elixir
#
# Hello World - Basic text-to-speech example
#
# Usage:
#   mix run examples/hello_world.exs
#   mix run examples/hello_world.exs --text "Custom message"
#   mix run examples/hello_world.exs --text "Hello!" --output my_audio.wav
#   mix run examples/hello_world.exs --device mps
#

Mix.install([{:chatterbex, path: Path.expand("..", __DIR__)}])

defmodule HelloWorld do
  def main(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          text: :string,
          output: :string,
          device: :string,
          model: :string
        ]
      )

    text = Keyword.get(opts, :text, "Hello, world! This is Chatterbex speaking.")
    output = Keyword.get(opts, :output, "hello_world.wav")
    device = Keyword.get(opts, :device, "cpu")
    model = opts |> Keyword.get(:model, "turbo") |> String.to_atom()

    IO.puts("Starting Chatterbex with #{model} model on #{device}...")
    {:ok, pid} = Chatterbex.start_link(model: model, device: device)

    IO.puts("Generating speech: \"#{text}\"")
    {:ok, audio} = Chatterbex.generate(pid, text)

    IO.puts("Saving audio to #{output}")
    :ok = Chatterbex.save(audio, output)

    IO.puts("Done!")
    Chatterbex.stop(pid)
  end
end

HelloWorld.main(System.argv())
