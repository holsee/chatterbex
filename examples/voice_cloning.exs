#!/usr/bin/env elixir
#
# Voice Cloning - Clone a voice from a reference audio sample
#
# Usage:
#   mix run examples/voice_cloning.exs --reference path/to/voice.wav
#   mix run examples/voice_cloning.exs --reference voice.wav --text "Clone this!"
#   mix run examples/voice_cloning.exs --reference voice.wav --output cloned.wav
#
# Tips:
#   - Reference audio should be 6-10 seconds of clear speech
#   - Use WAV format for best results
#   - Background noise in reference will affect output quality
#

Mix.install([{:chatterbex, path: Path.expand("..", __DIR__)}])

defmodule VoiceCloning do
  def main(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          reference: :string,
          text: :string,
          output: :string,
          device: :string,
          exaggeration: :float
        ]
      )

    reference = Keyword.get(opts, :reference)

    unless reference do
      IO.puts("""
      Error: --reference is required

      Usage:
        mix run examples/voice_cloning.exs --reference path/to/voice.wav

      Options:
        --reference   Path to reference audio file (required, 6-10 seconds recommended)
        --text        Text to synthesize (default: sample text)
        --output      Output file path (default: cloned_voice.wav)
        --device      Device to use: cpu, cuda, mps (default: cpu)
        --exaggeration  Voice exaggeration 0.0-1.0 (default: 0.5)
      """)

      System.halt(1)
    end

    unless File.exists?(reference) do
      IO.puts("Error: Reference file not found: #{reference}")
      System.halt(1)
    end

    text = Keyword.get(opts, :text, "This is my cloned voice. Pretty cool, right?")
    output = Keyword.get(opts, :output, "cloned_voice.wav")
    device = Keyword.get(opts, :device, "cpu")
    exaggeration = Keyword.get(opts, :exaggeration, 0.5)

    IO.puts("Starting Chatterbex with english model on #{device}...")
    {:ok, pid} = Chatterbex.start_link(model: :english, device: device)

    IO.puts("Loading model (this may take a minute on first run)...")
    :ok = Chatterbex.await_ready(pid)

    IO.puts("Cloning voice from: #{reference}")
    IO.puts("Generating speech: \"#{text}\"")

    {:ok, audio} =
      Chatterbex.generate(pid, text,
        audio_prompt: reference,
        exaggeration: exaggeration
      )

    IO.puts("Saving audio to #{output}")
    :ok = Chatterbex.save(audio, output)

    IO.puts("Done! Voice cloned successfully.")
    Chatterbex.stop(pid)
  end
end

VoiceCloning.main(System.argv())
