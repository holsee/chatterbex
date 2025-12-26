#!/usr/bin/env elixir
#
# Multilingual - Text-to-speech in 23+ languages
#
# Usage:
#   mix run examples/multilingual.exs --text "Bonjour" --language fr
#   mix run examples/multilingual.exs --text "Guten Tag" --language de --output german.wav
#   mix run examples/multilingual.exs --list-languages
#
# Supported languages:
#   en (English), fr (French), de (German), es (Spanish), it (Italian),
#   pt (Portuguese), nl (Dutch), pl (Polish), ru (Russian), uk (Ukrainian),
#   cs (Czech), sk (Slovak), hu (Hungarian), ro (Romanian), bg (Bulgarian),
#   hr (Croatian), sl (Slovenian), sr (Serbian), mk (Macedonian), sq (Albanian),
#   tr (Turkish), ar (Arabic), he (Hebrew), zh (Chinese), ja (Japanese),
#   ko (Korean), vi (Vietnamese), th (Thai), id (Indonesian), ms (Malay)
#

#Mix.install([{:chatterbex, path: Path.expand("..", __DIR__)}])

defmodule Multilingual do
  @sample_texts %{
    "en" => "Hello! This is a test of multilingual speech synthesis.",
    "fr" => "Bonjour! Ceci est un test de synthèse vocale multilingue.",
    "de" => "Hallo! Dies ist ein Test der mehrsprachigen Sprachsynthese.",
    "es" => "¡Hola! Esta es una prueba de síntesis de voz multilingüe.",
    "it" => "Ciao! Questo è un test di sintesi vocale multilingue.",
    "pt" => "Olá! Este é um teste de síntese de fala multilíngue.",
    "nl" => "Hallo! Dit is een test van meertalige spraaksynthese.",
    "pl" => "Cześć! To jest test wielojęzycznej syntezy mowy.",
    "ru" => "Привет! Это тест многоязычного синтеза речи.",
    "ja" => "こんにちは！これは多言語音声合成のテストです。",
    "zh" => "你好！这是多语言语音合成的测试。",
    "ko" => "안녕하세요! 다국어 음성 합성 테스트입니다."
  }

  def main(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          text: :string,
          language: :string,
          output: :string,
          device: :string,
          list_languages: :boolean
        ],
        aliases: [l: :language, t: :text, o: :output]
      )

    if Keyword.get(opts, :list_languages) do
      print_languages()
      System.halt(0)
    end

    language = Keyword.get(opts, :language, "en")
    text = Keyword.get(opts, :text) || Map.get(@sample_texts, language, @sample_texts["en"])
    output = Keyword.get(opts, :output, "multilingual_#{language}.wav")
    device = Keyword.get(opts, :device, "cpu")

    unless language in Chatterbex.supported_languages() do
      IO.puts("Error: Unsupported language '#{language}'")
      IO.puts("Run with --list-languages to see supported languages")
      System.halt(1)
    end

    IO.puts("Starting Chatterbex with multilingual model on #{device}...")
    {:ok, pid} = Chatterbex.start_link(model: :multilingual, device: device)

    IO.puts("Loading model (this may take a minute on first run)...")
    :ok = Chatterbex.await_ready(pid)

    IO.puts("Language: #{language}")
    IO.puts("Generating speech: \"#{text}\"")

    {:ok, audio} = Chatterbex.generate(pid, text, language: language)

    IO.puts("Saving audio to #{output}")
    :ok = Chatterbex.save(audio, output)

    IO.puts("Done!")
    Chatterbex.stop(pid)
  end

  defp print_languages do
    IO.puts("Supported languages:\n")

    languages = [
      {"en", "English"},
      {"fr", "French"},
      {"de", "German"},
      {"es", "Spanish"},
      {"it", "Italian"},
      {"pt", "Portuguese"},
      {"nl", "Dutch"},
      {"pl", "Polish"},
      {"ru", "Russian"},
      {"uk", "Ukrainian"},
      {"cs", "Czech"},
      {"sk", "Slovak"},
      {"hu", "Hungarian"},
      {"ro", "Romanian"},
      {"bg", "Bulgarian"},
      {"hr", "Croatian"},
      {"sl", "Slovenian"},
      {"sr", "Serbian"},
      {"mk", "Macedonian"},
      {"sq", "Albanian"},
      {"tr", "Turkish"},
      {"ar", "Arabic"},
      {"he", "Hebrew"},
      {"zh", "Chinese"},
      {"ja", "Japanese"},
      {"ko", "Korean"},
      {"vi", "Vietnamese"},
      {"th", "Thai"},
      {"id", "Indonesian"},
      {"ms", "Malay"}
    ]

    Enum.each(languages, fn {code, name} ->
      IO.puts("  #{code}\t#{name}")
    end)
  end
end

Multilingual.main(System.argv())
