defmodule ChatterbexTest do
  use ExUnit.Case
  doctest Chatterbex

  describe "sample_rate/1" do
    test "returns 24000 for all models" do
      assert Chatterbex.sample_rate(:turbo) == 24_000
      assert Chatterbex.sample_rate(:english) == 24_000
      assert Chatterbex.sample_rate(:multilingual) == 24_000
    end
  end

  describe "supported_languages/0" do
    test "returns a list of language codes" do
      languages = Chatterbex.supported_languages()

      assert is_list(languages)
      assert "en" in languages
      assert "fr" in languages
      assert "de" in languages
      assert "zh" in languages
    end
  end

  describe "paralinguistic_tags/0" do
    test "returns supported tags" do
      tags = Chatterbex.paralinguistic_tags()

      assert is_list(tags)
      assert "[laugh]" in tags
      assert "[chuckle]" in tags
      assert "[sigh]" in tags
    end
  end

  describe "save/2" do
    test "writes binary data to file" do
      audio = <<0, 1, 2, 3, 4, 5>>
      path = Path.join(System.tmp_dir!(), "test_audio_#{:rand.uniform(10000)}.wav")

      assert :ok = Chatterbex.save(audio, path)
      assert File.read!(path) == audio

      File.rm!(path)
    end
  end
end
