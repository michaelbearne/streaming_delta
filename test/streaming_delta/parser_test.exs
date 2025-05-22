defmodule StreamingDelta.ParserTest do
  use ExUnit.Case

  alias StreamingDelta.Fake

  alias StreamingDelta.{Streaming, Parser}
  alias StreamingDelta.Streaming.{Extraction, Source, DeltaDiff}

  setup do: %{response: %Streaming{}}

  describe "parse_chunks/2 sentence" do
    test "plan text", %{response: response} do
      ai_resp = "A sentence."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp
      assert delta == [%{"insert" => "A sentence."}]
    end

    test "append second sentence to first sentence", %{response: response} do
      ai_resp = "Fist sentence."

      assert %Streaming{raw: raw, delta: delta} =
               first_response =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp
      assert delta == [%{"insert" => ai_resp}]

      next_ai_resp = "\nsecond sentence."

      assert %Streaming{raw: raw, delta: delta} =
               second_response =
               next_ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(first_response)

      assert raw == ai_resp <> next_ai_resp
      assert delta == [%{"insert" => "Fist sentence.\nsecond sentence."}]

      assert Streaming.diffs(first_response, second_response) == [
               %DeltaDiff{
                 delta: [%{"retain" => 14}, %{"insert" => "\nsecond sentence."}],
                 new_cited_source_ids: [],
                 new_follow_up_questions: []
               }
             ]
    end

    test "with italic", %{response: response} do
      ai_resp = "A sentence with *italic*."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "A sentence with "},
               %{"attributes" => %{"italic" => true}, "insert" => "italic"},
               %{"insert" => "."}
             ]
    end

    test "with bold", %{response: response} do
      ai_resp = "A sentence with **bold**."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "A sentence with "},
               %{"attributes" => %{"bold" => true}, "insert" => "bold"},
               %{"insert" => "."}
             ]
    end

    test "with colon stright after the bold close also make colon bold", %{response: response} do
      ai_resp = "A sentence with **bold**: Important"

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "A sentence with "},
               %{"attributes" => %{"bold" => true}, "insert" => "bold:"},
               %{"insert" => " Important"}
             ]
    end

    test "with colon stright after the italic and bold close also make colon italic and bold", %{
      response: response
    } do
      ai_resp = "A sentence with ***bold***: Important"

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "A sentence with "},
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "bold:"},
               %{"insert" => " Important"}
             ]
    end

    test "with italic and bold", %{response: response} do
      ai_resp = "A sentence with ***italic and bold***."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "A sentence with "},
               %{
                 "attributes" => %{"bold" => true, "italic" => true},
                 "insert" => "italic and bold"
               },
               %{"insert" => "."}
             ]
    end

    test "with white space suffix", %{response: response} do
      ai_resp = "    A sentence white space suffix."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [%{"insert" => "    A sentence white space suffix."}]
    end

    test "no italic due to white space", %{response: response} do
      ai_resp = "A sentence with white space * not italic * ."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [%{"insert" => "A sentence with white space * not italic * ."}]
    end

    test "no bold due to white space", %{response: response} do
      ai_resp = "A sentence with white space ** not bold ** ."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp
      assert delta == [%{"insert" => "A sentence with white space ** not bold ** ."}]
    end

    test "no bold or italic due to white space", %{response: response} do
      ai_resp = "A sentence with white space *** not bold or italic *** ."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp
      assert delta == [%{"insert" => "A sentence with white space *** not bold or italic *** ."}]
    end

    test "only italic", %{response: response} do
      ai_resp = "*italic sentence.*"

      assert %Streaming{buffer: [["*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "*italic sentence."

      assert delta == [%{"attributes" => %{"italic" => true}, "insert" => "italic sentence."}]
    end

    test "only bold", %{response: response} do
      ai_resp = "**bold sentence.**"

      assert %Streaming{buffer: [["*", "*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "**bold sentence."

      assert delta == [%{"attributes" => %{"bold" => true}, "insert" => "bold sentence."}]
    end

    test "only bold and italic", %{response: response} do
      ai_resp = "***bold italic sentence.***"

      assert %Streaming{buffer: [["*", "*", "*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "***bold italic sentence."

      assert delta == [
               %{
                 "attributes" => %{"bold" => true, "italic" => true},
                 "insert" => "bold italic sentence."
               }
             ]
    end

    test "only not bold", %{response: response} do
      ai_resp = "** not bold sentence.**"

      assert %Streaming{buffer: [["*", "*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "** not bold sentence."

      assert delta == [%{"insert" => "** not bold sentence."}]
    end

    test "only not bold and italic", %{response: response} do
      ai_resp = "*** not bold and italic sentence.***"

      assert %Streaming{buffer: [["*", "*", "*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "*** not bold and italic sentence."

      assert delta == [%{"insert" => "*** not bold and italic sentence."}]
    end

    test "just stars", %{response: response} do
      ai_resp = "****stars****"

      # todo could unbuffer the starts when over 3 as know won't match
      assert %Streaming{buffer: [["*", "*", "*", "*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "****stars"

      assert delta == [%{"insert" => "****stars"}]
    end

    test "multiple only italic", %{response: response} do
      ai_resp = """
      *one.*
      *two.*
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "one."},
               %{"insert" => "\n"},
               %{"attributes" => %{"italic" => true}, "insert" => "two."}
             ]
    end

    test "multiple header then only bold", %{response: response} do
      ai_resp = """
      # Header
      **bold**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Header"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "bold"}
             ]
    end

    test "multiple header then only bold and italic", %{response: response} do
      ai_resp = """
      # Header
      ***bold italic***
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Header"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"},
               %{
                 "attributes" => %{"bold" => true, "italic" => true},
                 "insert" => "bold italic"
               }
             ]
    end
  end

  describe "parse_chunks/2 heading" do
    test "first line heading 1", %{response: response} do
      ai_resp = "# Heading"

      assert %Streaming{buffer: [], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "Heading"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "first line heading 1 Italic", %{response: response} do
      ai_resp = "# *Heading*"

      assert %Streaming{buffer: [["*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "# *Heading"

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "Heading"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "first line heading 1 Bold", %{response: response} do
      ai_resp = "# **Heading**"

      assert %Streaming{buffer: [["*", "*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "# **Heading"

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Heading"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "first line heading 1 Bold and italic", %{response: response} do
      ai_resp = "# ***Heading***"

      assert %Streaming{buffer: [["*", "*", "*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "# ***Heading"

      assert delta == [
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "Heading"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "first line heading 1 with white space", %{response: response} do
      ai_resp = """
      # Heading
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Heading"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "first line heading 1 Italic with white space", %{response: response} do
      ai_resp = """
      # *Heading*
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "Heading"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "first line heading 1 Bold with white space", %{response: response} do
      ai_resp = """
      # **Heading**
      """

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Heading"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "first line heading 1 Bold and italic with white space", %{response: response} do
      ai_resp = """
      # ***Heading***
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "Heading"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "first line heading 2  with white space", %{response: response} do
      ai_resp = """
      ## Heading
      """

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Heading"},
               %{"attributes" => %{"header" => 2}, "insert" => "\n"}
             ]
    end

    test "heading 1 not on first line", %{response: response} do
      ai_resp = """
      Text
      # Heading 1
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Text\nHeading 1"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"}
             ]
    end

    test "heading 2 not on first line", %{response: response} do
      ai_resp = """
      Text
      ## Heading 2
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Text\nHeading 2"},
               %{"attributes" => %{"header" => 2}, "insert" => "\n"}
             ]
    end

    test "mutiple headings", %{response: response} do
      ai_resp = """
      # Heading 1
      ## Heading 2
      ### Heading 3
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Heading 1"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"},
               %{"insert" => "Heading 2"},
               %{"attributes" => %{"header" => 2}, "insert" => "\n"},
               %{"insert" => "Heading 3"},
               %{"attributes" => %{"header" => 3}, "insert" => "\n"}
             ]
    end

    test "mutiple headings with text in between", %{response: response} do
      ai_resp = """
      # Heading 1

      Text

      ## Heading 2

      More text

      ### Heading 3

      Even more text
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Heading 1"},
               %{"attributes" => %{"header" => 1}, "insert" => "\n"},
               %{"insert" => "Text\nHeading 2"},
               %{"attributes" => %{"header" => 2}, "insert" => "\n"},
               %{"insert" => "More text\nHeading 3"},
               %{"attributes" => %{"header" => 3}, "insert" => "\n"},
               %{"insert" => "Even more text"}
             ]
    end
  end

  describe "parse_chunks/2 unordered list" do
    test "single item dash (-)", %{response: response} do
      ai_resp = "- One."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) white space", %{response: response} do
      ai_resp = """
      - One.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    # I think these still should be buffering raw as no code point to close of the emphasis

    test "single item dash (-) with italic text", %{response: response} do
      ai_resp = "- *One*"

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "- *One"

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) with bold text", %{response: response} do
      ai_resp = "- **One**"

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "- **One"

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) with bold and italic text", %{response: response} do
      ai_resp = "- ***One***"

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "- ***One"

      assert delta == [
               %{"attributes" => %{"bold" => true, "italic" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) italic text white space", %{response: response} do
      ai_resp = """
      - *One*
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) bold text white space", %{response: response} do
      ai_resp = """
      - **One**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) bold and italic text white space", %{response: response} do
      ai_resp = """
      - ***One***
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true, "italic" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) some italic text white space", %{response: response} do
      ai_resp = """
      - *One* text
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "One"},
               %{"insert" => " text"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) some bold text white space", %{response: response} do
      ai_resp = """
      - **One** text
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"insert" => " text"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item dash (-) some bold and italic text white space", %{response: response} do
      ai_resp = """
      - ***One*** text
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "One"},
               %{"insert" => " text"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "indented single item dash (-)", %{response: response} do
      ai_resp = """
          - One
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One"},
               %{"attributes" => %{"indent" => 1, "list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item star (*) no white space", %{response: response} do
      ai_resp = "* One."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item star (*)", %{response: response} do
      ai_resp = """
      * One.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item star (*) with bold text", %{response: response} do
      ai_resp = """
      * **One**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "single item star (*) with bold and italic text", %{response: response} do
      ai_resp = """
      * ***One***
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true, "italic" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "indented single item star (*)", %{response: response} do
      ai_resp = """
          * One
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One"},
               %{"attributes" => %{"indent" => 1, "list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items -", %{response: response} do
      ai_resp = """
      - One.
      - Two.
      - Three.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Two."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Three."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items *", %{response: response} do
      ai_resp = """
      * One.
      * Two.
      * Three.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Two."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Three."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "not unordered list", %{response: response} do
      ai_resp = """
      -One.
      -Two.
      -Three.
      """

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)
      assert delta == [%{"insert" => "-One.\n-Two.\n-Three."}]
    end

    test "multiple items with title", %{response: response} do
      ai_resp = """
      Title
      - One.
      - Two.
      - Three.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Title\nOne."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Two."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Three."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items with title with removed blank lines", %{response: response} do
      ai_resp = """
      Title

      - One.
      - Two.
      - Three.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Title\nOne."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Two."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Three."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items with all italic text", %{response: response} do
      ai_resp = """
      - *italic*
      - *italic*
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "italic"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"italic" => true}, "insert" => "italic"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items with all bold text", %{response: response} do
      ai_resp = """
      - **Bold**
      - **Bold**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items with all italic and bold text", %{response: response} do
      ai_resp = """
      - ***Bold***
      - ***Bold***
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "Bold"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "Bold"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items with some bold text", %{response: response} do
      ai_resp = """
      - **Bold** one.
      - **Bold** two.
      - **Bold** three.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " one."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " two."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " three."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items with bold text with removed blank lines", %{response: response} do
      ai_resp = """
      - **Bold** one.

      - **Bold** two.

      - **Bold** three.

      Footer
      """

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " one."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " two."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " three."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "Footer"}
             ]
    end

    # # todo this should not be italic should remove italic when it hit the new line
    # test "multiple items with stars", %{response: response} do
    #   ai_resp = """
    #   - *one.
    #   - * two.
    #   - *
    #   """

    #   assert %Streaming{raw: raw, delta: delta} =
    #            ai_resp
    #            |> to_chunks()
    #            |> Parser.parse_chunks(response)

    #   assert raw == ai_resp

    #   # assert delta == [
    #   #          %{"insert" => "*one."},
    #   #          %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
    #   #          %{"insert" => "* two."},
    #   #          %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
    #   #          %{"insert" => "*"},
    #   #          %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"}
    #   #        ]
    # end

    test "multiple items nested dash (-)", %{response: response} do
      ai_resp = """
      - one.
          - two.
              - three
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "one."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "two."},
               %{"attributes" => %{"indent" => 1, "list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "three"},
               %{"attributes" => %{"indent" => 2, "list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items nested star (*)", %{response: response} do
      ai_resp = """
      * one.
          * two.
              * three
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "one."},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "two."},
               %{"attributes" => %{"indent" => 1, "list" => "bullet"}, "insert" => "\n"},
               %{"insert" => "three"},
               %{"attributes" => %{"indent" => 2, "list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items nested star (*) italic", %{response: response} do
      ai_resp = """
      * *one*
          * *two*
              * *three*
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "one"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"italic" => true}, "insert" => "two"},
               %{"attributes" => %{"indent" => 1, "list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"italic" => true}, "insert" => "three"},
               %{"attributes" => %{"indent" => 2, "list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items nested star (*) bold", %{response: response} do
      ai_resp = """
      * **one**
          * **two**
              * **three**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "one"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "two"},
               %{"attributes" => %{"indent" => 1, "list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "three"},
               %{"attributes" => %{"indent" => 2, "list" => "bullet"}, "insert" => "\n"}
             ]
    end

    test "multiple items nested star (*) italic and bold", %{response: response} do
      ai_resp = """
      * ***one***
          * ***two***
              * ***three***
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "one"},
               %{"attributes" => %{"list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "two"},
               %{"attributes" => %{"indent" => 1, "list" => "bullet"}, "insert" => "\n"},
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "three"},
               %{"attributes" => %{"indent" => 2, "list" => "bullet"}, "insert" => "\n"}
             ]
    end
  end

  describe "parse_chunks/2 ordered list" do
    test "one item", %{response: response} do
      ai_resp = "1. One."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "one item italic", %{response: response} do
      ai_resp = "1. *One*"

      assert %Streaming{buffer: [["*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "1. *One"

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "one item bold", %{response: response} do
      ai_resp = "1. **One**"

      assert %Streaming{buffer: [["*", "*"]], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "1. **One"

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "one item bold and italic", %{response: response} do
      ai_resp = "1. ***One***"

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == "1. ***One"

      assert delta == [
               %{"attributes" => %{"bold" => true, "italic" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    # # todo
    # test "one item not italic", %{response: response} do
    #   ai_resp = "1. * One *"

    #   assert %Streaming{buffer: [["*"]], raw: raw, delta: delta} =
    #            ai_resp
    #            |> to_chunks()
    #            |> Parser.parse_chunks(response)

    #   dbg(delta)

    #   # assert raw == "1. *One"

    #   # assert delta == [
    #   #          %{"attributes" => %{"italic" => true}, "insert" => "One"},
    #   #          %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
    #   #        ]
    # end

    test "one item with white space", %{response: response} do
      ai_resp = """
      1. One.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    # todo not sure if should remove white space
    test "one item additional white space between digit and text", %{response: response} do
      ai_resp = """
      1.  One.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      # dbg(delta)

      assert delta == [
               %{"insert" => " One."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "one item bold with white space", %{response: response} do
      ai_resp = """
      1. **One**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "one item bold additional white space between digit and text", %{response: response} do
      ai_resp = """
      1.  **One**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => " "},
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "one item with major miner digits with white space", %{response: response} do
      ai_resp = """
      1.1. One
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"insert" => "One"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "one item with major miner miner digits with white space", %{
      response: response
    } do
      ai_resp = """
      1.11.1. **One**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "multiple items", %{response: response} do
      ai_resp = """
      1. One.
      02. Two.
      003. Three.
      4.1. Four
      5.12.3. Five
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Two."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Three."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Four"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Five"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "multiple items with title", %{response: response} do
      ai_resp = """
      Title
      1. One.
      02. Two.
      003. Three.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Title\nOne."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Two."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Three."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "multiple items with title with removed blank lines", %{response: response} do
      ai_resp = """
      Title

      1. One.
      02. Two.
      003. Three.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "Title\nOne."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Two."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Three."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "multiple items with some bold text", %{response: response} do
      ai_resp = """
      1. **Bold** one.
      02. **Bold** two.
      003. **Bold** three.
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " one."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " two."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " three."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "multiple items with only italic text", %{response: response} do
      ai_resp = """
      1. *Introduction*
      2. *Background and Context*
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"attributes" => %{"italic" => true}, "insert" => "Introduction"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"italic" => true}, "insert" => "Background and Context"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "multiple items with only bold text", %{response: response} do
      ai_resp = """
      1. **Introduction**
      2. **Background and Context**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Introduction"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Background and Context"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "multiple items with only bold and italic text", %{response: response} do
      ai_resp = """
      1. ***Introduction***
      2. ***Background and Context***
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"attributes" => %{"italic" => true, "bold" => true}, "insert" => "Introduction"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{
                 "attributes" => %{"italic" => true, "bold" => true},
                 "insert" => "Background and Context"
               },
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "indented single item", %{response: response} do
      ai_resp = """
          1. One
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"insert" => "One"},
               %{"attributes" => %{"indent" => 1, "list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "indented single item bold text", %{response: response} do
      ai_resp = """
          1. **One**
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"attributes" => %{"list" => "ordered", "indent" => 1}, "insert" => "\n"}
             ]
    end

    test "indented single item some bold", %{response: response} do
      ai_resp = """
          1. **One** text
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"insert" => " text"},
               %{"attributes" => %{"list" => "ordered", "indent" => 1}, "insert" => "\n"}
             ]
    end

    test "indented single item major miner digits", %{response: response} do
      ai_resp = """
          1.1. One
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"insert" => "One"},
               %{"attributes" => %{"indent" => 1, "list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "indented single item major miner miner digits", %{
      response: response
    } do
      ai_resp = """
          1.11.1. One
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"insert" => "One"},
               %{"attributes" => %{"indent" => 1, "list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "multiple items some bold text with removed blank lines", %{response: response} do
      ai_resp = """
      1. **Bold** one.

      02. **Bold** two.

      003. **Bold** three.

      Footer
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " one."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " two."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Bold"},
               %{"insert" => " three."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Footer"}
             ]
    end

    # todo when implement stars canceled out by white space
    # test "multiple items with stars", %{response: response} do
    #   ai_resp = """
    #   1. *one.
    #   02. * two.
    #   003. *
    #   4. *
    #   """

    #   # buffer: ["\n"],

    #   assert %Streaming{raw: raw, delta: delta} =
    #            s =
    #            ai_resp
    #            |> to_chunks()
    #            |> Parser.parse_chunks(response)

    #   # assert raw == String.trim_trailing(ai_resp)

    #   dbg(delta)

    #   # assert delta == [
    #   #          %{"insert" => "*one."},
    #   #          %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
    #   #          %{"insert" => "* two."},
    #   #          %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
    #   #          %{"insert" => "*"},
    #   #          %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
    #   #        ]
    # end

    test "nested list", %{response: response} do
      ai_resp = """
      1. Purpose
          1. Introduction
              2. Details
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"insert" => "Purpose"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Introduction"},
               %{"attributes" => %{"indent" => 1, "list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Details"},
               %{"attributes" => %{"indent" => 2, "list" => "ordered"}, "insert" => "\n"}
             ]
    end

    test "nested list with major miner digits", %{response: response} do
      ai_resp = """
      1. **Introduction**
          1.11. Background and Context
          1.2. **Purpose**
          1.2. **Evaluation** Types
      """

      assert %Streaming{buffer: ["\n"], raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp |> String.trim_trailing()

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "Introduction"},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Background and Context"},
               %{"attributes" => %{"indent" => 1, "list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Purpose"},
               %{"attributes" => %{"indent" => 1, "list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Evaluation"},
               %{"insert" => " Types"},
               %{"attributes" => %{"indent" => 1, "list" => "ordered"}, "insert" => "\n"}
             ]
    end
  end

  describe "parse_chunks/2 source refs" do
    test "sentence with single digit ref at end when source not found", %{response: response} do
      ai_resp = "sentence [1]."

      assert %Streaming{raw: raw, delta: delta} =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp

      assert delta == [%{"insert" => "sentence [1]."}]
    end

    test "sentence with single digit ref at end with cited source", %{response: response} do
      source = build_source(1)
      ai_resp = "sentence [#{source.num}]."
      response = %{response | source_ids: source_ids(source)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{
               raw: raw,
               delta: delta,
               cited_source_ids: cited_source_ids
             } =
               Parser.parse_chunks(chunks, response, [source])

      assert cited_source_ids == [source.id]

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source.id,
                     "num" => source.num,
                     "pageNum" => source.page_num,
                     "publicationId" => source.publication_id,
                     "publicationType" => to_enum(source.publication_type),
                     "srcFileId" => source.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with double digit ref at end with cited source", %{response: response} do
      source = build_source(24)
      ai_resp = "sentence [#{source.num}]."
      response = %{response | source_ids: source_ids(source)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, [source])

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source.id,
                     "num" => source.num,
                     "pageNum" => source.page_num,
                     "publicationId" => source.publication_id,
                     "publicationType" => to_enum(source.publication_type),
                     "srcFileId" => source.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[24]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with triple digit ref at end with cited source", %{response: response} do
      source = build_source(123)
      ai_resp = "sentence [#{source.num}]."
      response = %{response | source_ids: source_ids(source)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, [source])

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source.id,
                     "num" => source.num,
                     "pageNum" => source.page_num,
                     "publicationId" => source.publication_id,
                     "publicationType" => to_enum(source.publication_type),
                     "srcFileId" => source.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[123]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with two refs at end with cited source", %{response: response} do
      source_1 = build_source(1)
      source_2 = build_source(89)
      sources = [source_1, source_2]

      ai_resp = "sentence [#{source_1.num}][#{source_2.num}]."
      response = %{response | source_ids: source_ids(sources)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{
               raw: raw,
               delta: delta,
               cited_source_ids: cited_source_ids
             } =
               Parser.parse_chunks(chunks, response, sources)

      assert raw == ai_resp
      assert cited_source_ids == [source_1.id, source_2.id]

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_1.id,
                     "num" => source_1.num,
                     "pageNum" => source_1.page_num,
                     "publicationId" => source_1.publication_id,
                     "publicationType" => to_enum(source_1.publication_type),
                     "srcFileId" => source_1.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_2.id,
                     "num" => source_2.num,
                     "pageNum" => source_2.page_num,
                     "publicationId" => source_2.publication_id,
                     "publicationType" => to_enum(source_2.publication_type),
                     "srcFileId" => source_2.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[89]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with two comma separated refs at end with cited source", %{response: response} do
      source_1 = build_source(1)
      source_2 = build_source(89)
      sources = [source_1, source_2]

      ai_resp = "sentence [#{source_1.num},#{source_2.num}]."
      response = %{response | source_ids: source_ids(sources)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, sources)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_1.id,
                     "num" => source_1.num,
                     "pageNum" => source_1.page_num,
                     "publicationId" => source_1.publication_id,
                     "publicationType" => to_enum(source_1.publication_type),
                     "srcFileId" => source_1.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_2.id,
                     "num" => source_2.num,
                     "pageNum" => source_2.page_num,
                     "publicationId" => source_2.publication_id,
                     "publicationType" => to_enum(source_2.publication_type),
                     "srcFileId" => source_2.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[89]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with two comma separated refs with white space at end with cited source", %{
      response: response
    } do
      source_1 = build_source(1)
      source_2 = build_source(89)
      sources = [source_1, source_2]

      ai_resp = "sentence [#{source_1.num}, #{source_2.num}]."
      response = %{response | source_ids: source_ids(sources)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, sources)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_1.id,
                     "num" => source_1.num,
                     "pageNum" => source_1.page_num,
                     "publicationId" => source_1.publication_id,
                     "publicationType" => to_enum(source_1.publication_type),
                     "srcFileId" => source_1.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_2.id,
                     "num" => source_2.num,
                     "pageNum" => source_2.page_num,
                     "publicationId" => source_2.publication_id,
                     "publicationType" => to_enum(source_2.publication_type),
                     "srcFileId" => source_2.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[89]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with two separat refs comma separated at end with cited source", %{
      response: response
    } do
      source_1 = build_source(1)
      source_2 = build_source(89)
      sources = [source_1, source_2]

      ai_resp = "sentence [#{source_1.num}],[#{source_2.num}]."
      response = %{response | source_ids: source_ids(sources)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, sources)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_1.id,
                     "num" => source_1.num,
                     "pageNum" => source_1.page_num,
                     "publicationId" => source_1.publication_id,
                     "publicationType" => to_enum(source_1.publication_type),
                     "srcFileId" => source_1.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_2.id,
                     "num" => source_2.num,
                     "pageNum" => source_2.page_num,
                     "publicationId" => source_2.publication_id,
                     "publicationType" => to_enum(source_2.publication_type),
                     "srcFileId" => source_2.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[89]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with two separat refs comma separated with white space at end with cited source",
         %{
           response: response
         } do
      source_1 = build_source(1)
      source_2 = build_source(89)
      sources = [source_1, source_2]

      ai_resp = "sentence [#{source_1.num}], [#{source_2.num}]."
      response = %{response | source_ids: source_ids(sources)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, sources)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_1.id,
                     "num" => source_1.num,
                     "pageNum" => source_1.page_num,
                     "publicationId" => source_1.publication_id,
                     "publicationType" => to_enum(source_1.publication_type),
                     "srcFileId" => source_1.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_2.id,
                     "num" => source_2.num,
                     "pageNum" => source_2.page_num,
                     "publicationId" => source_2.publication_id,
                     "publicationType" => to_enum(source_2.publication_type),
                     "srcFileId" => source_2.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[89]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with refs below",
         %{
           response: response
         } do
      source_1 = build_source(1)
      source_2 = build_source(89)
      sources = [source_1, source_2]

      ai_resp = """
      a sentence

      [#{source_1.num}], [#{source_2.num}].
      """

      response = %{response | source_ids: source_ids(sources)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, sources)

      assert raw == ai_resp

      assert delta == [
               %{"insert" => "a sentence\n"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_1.id,
                     "num" => source_1.num,
                     "pageNum" => source_1.page_num,
                     "publicationId" => source_1.publication_id,
                     "publicationType" => to_enum(source_1.publication_type),
                     "srcFileId" => source_1.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_2.id,
                     "num" => source_2.num,
                     "pageNum" => source_2.page_num,
                     "publicationId" => source_2.publication_id,
                     "publicationType" => to_enum(source_2.publication_type),
                     "srcFileId" => source_2.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[89]"
               },
               %{"insert" => "."}
             ]
    end

    test "sentence with a range of refs comma",
         %{
           response: response
         } do
      src_file_id = Fake.id()
      extracted_txt_file_id = Fake.id()
      study_id = Fake.id()

      sources =
        Enum.map(1..13, fn id ->
          %Source{
            id: Fake.id(),
            num: id,
            type: :page,
            text: "blah blah #{id}",
            page_num: 1,
            src_file_id: src_file_id,
            publication_id: study_id,
            thumbnails: [],
            publication_type: :study,
            src_file_name: "ebook_mit-cio-generative-ai-report.pdf",
            extracted_txt_file_id: extracted_txt_file_id
          }
        end)

      ai_resp = "sentence [9-12]."
      response = %{response | source_ids: source_ids(sources)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, sources)

      assert raw == ai_resp

      source_9 = Enum.at(sources, 8)
      source_10 = Enum.at(sources, 9)
      source_11 = Enum.at(sources, 10)
      source_12 = Enum.at(sources, 11)

      assert delta == [
               %{"insert" => "sentence"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_9.id,
                     "num" => source_9.num,
                     "pageNum" => source_9.page_num,
                     "publicationId" => source_9.publication_id,
                     "publicationType" => to_enum(source_9.publication_type),
                     "srcFileId" => source_9.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[9]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_10.id,
                     "num" => source_10.num,
                     "pageNum" => source_10.page_num,
                     "publicationId" => source_10.publication_id,
                     "publicationType" => to_enum(source_10.publication_type),
                     "srcFileId" => source_10.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[10]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_11.id,
                     "num" => source_11.num,
                     "pageNum" => source_11.page_num,
                     "publicationId" => source_11.publication_id,
                     "publicationType" => to_enum(source_11.publication_type),
                     "srcFileId" => source_11.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[11]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_12.id,
                     "num" => source_12.num,
                     "pageNum" => source_12.page_num,
                     "publicationId" => source_12.publication_id,
                     "publicationType" => to_enum(source_12.publication_type),
                     "srcFileId" => source_12.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[12]"
               },
               %{"insert" => "."}
             ]
    end

    test "orderd list with cited sources", %{
      response: response
    } do
      source_1 = build_source(1)
      source_2 = build_source(89)
      sources = [source_1, source_2]

      ai_resp = """
      1. **One** source [#{source_1.num}].
      2. **Two**: source [#{source_2.num}]."
      3. Three: mutiple [#{source_1.num}][#{source_2.num}] sources.
      """

      response = %{response | source_ids: source_ids(sources)}

      chunks = to_chunks(ai_resp)

      assert %Streaming{raw: raw, delta: delta} =
               Parser.parse_chunks(chunks, response, sources)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [
               %{"attributes" => %{"bold" => true}, "insert" => "One"},
               %{"insert" => " source"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_1.id,
                     "num" => source_1.num,
                     "pageNum" => source_1.page_num,
                     "publicationId" => source_1.publication_id,
                     "publicationType" => to_enum(source_1.publication_type),
                     "srcFileId" => source_1.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{"insert" => "."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"attributes" => %{"bold" => true}, "insert" => "Two:"},
               %{"insert" => " source"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_2.id,
                     "num" => source_2.num,
                     "pageNum" => source_2.page_num,
                     "publicationId" => source_2.publication_id,
                     "publicationType" => to_enum(source_2.publication_type),
                     "srcFileId" => source_2.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[89]"
               },
               %{"insert" => ".\""},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"},
               %{"insert" => "Three: mutiple"},
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_1.id,
                     "num" => source_1.num,
                     "pageNum" => source_1.page_num,
                     "publicationId" => source_1.publication_id,
                     "publicationType" => to_enum(source_1.publication_type),
                     "srcFileId" => source_1.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[1]"
               },
               %{
                 "attributes" => %{
                   "source" => %{
                     "id" => source_2.id,
                     "num" => source_2.num,
                     "pageNum" => source_2.page_num,
                     "publicationId" => source_2.publication_id,
                     "publicationType" => to_enum(source_2.publication_type),
                     "srcFileId" => source_2.src_file_id,
                     "type" => "PAGE"
                   }
                 },
                 "insert" => "[89]"
               },
               %{"insert" => " sources."},
               %{"attributes" => %{"list" => "ordered"}, "insert" => "\n"}
             ]
    end
  end

  describe "parse_chunks/2 follow up question" do
    test "follow up question", %{response: response} do
      ai_resp = "<<A follow up question?>>"

      assert %Streaming{
               raw: raw,
               delta: delta,
               follow_up_questions: follow_up_questions
             } =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == ai_resp
      assert delta == []
      assert follow_up_questions == ["A follow up question?"]
    end

    test "follow up question after reponse", %{response: response} do
      ai_resp = """
      Resp
      <<A follow up question?>>
      """

      assert %Streaming{
               raw: raw,
               delta: delta,
               follow_up_questions: follow_up_questions
             } =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)
      assert delta == [%{"insert" => "Resp"}]
      assert follow_up_questions == ["A follow up question?"]
    end

    test "mutiple follow up questions", %{response: response} do
      ai_resp = """
      <<Follow up question a?>>
      <<Follow up question b?>>
      <<Follow up question c?>>
      """

      assert %Streaming{
               raw: raw,
               delta: delta,
               follow_up_questions: follow_up_questions
             } =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)
      assert delta == []

      assert follow_up_questions == [
               "Follow up question c?",
               "Follow up question b?",
               "Follow up question a?"
             ]
    end

    test "follow up questions with white space in between follow ups", %{response: response} do
      ai_resp =
        "I'm sorry, but the information provided does not include the current President of the United States. \n\n<<Can you provide information on recent U.S. economic trends?>> \n<<What are the latest developments in U.S. technology sectors?>> \n<<How does advertising impact sales in different industries?>>"

      assert %Streaming{
               raw: raw,
               delta: delta,
               follow_up_questions: follow_up_questions
             } =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      # todo might be able to strip this white space
      assert delta == [
               %{
                 "insert" =>
                   "I'm sorry, but the information provided does not include the current President of the United States. \n"
               }
             ]

      assert follow_up_questions == [
               "How does advertising impact sales in different industries?",
               "What are the latest developments in U.S. technology sectors?",
               "Can you provide information on recent U.S. economic trends?"
             ]
    end
  end

  describe "parse_chunks/2 extractions" do
    test "extraction", %{response: response} do
      response = %{response | extraction_keys: ["OUTLINE"]}

      ai_resp = """
      Before

      @OUTLINE
      A extraction
      @OUTLINE

      After
      """

      assert %Streaming{
               raw: raw,
               delta: delta,
               extractions: extractions
             } =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)

      assert delta == [%{"insert" => "Before\n\n\nAfter"}]

      assert %{
               1 => %Extraction{
                 id: 1,
                 key: "OUTLINE",
                 raw: "\nA extraction",
                 delta: [%{"insert" => "\nA extraction"}]
               }
             } = extractions
    end

    test "multiple extractions", %{response: response} do
      response = %{response | extraction_keys: ["OUTLINE"]}

      ai_resp = """
      Before

      @OUTLINE
      Extraction 1
      @OUTLINE

      Middle

      @OUTLINE
      Extraction 2
      @OUTLINE

      After
      """

      assert %Streaming{
               raw: raw,
               delta: delta,
               extractions: extractions
             } =
               ai_resp
               |> to_chunks()
               |> Parser.parse_chunks(response)

      assert raw == String.trim_trailing(ai_resp)
      assert delta == [%{"insert" => "Before\n\n\nMiddle\n\n\nAfter"}]

      assert %{
               1 => %Extraction{
                 id: 1,
                 key: "OUTLINE",
                 raw: "\nExtraction 1",
                 delta: [%{"insert" => "\nExtraction 1"}]
               },
               2 => %Extraction{
                 id: 2,
                 key: "OUTLINE",
                 raw: "\nExtraction 2",
                 delta: [%{"insert" => "\nExtraction 2"}]
               }
             } = extractions
    end
  end

  defp to_chunks(resp) do
    resp |> String.codepoints() |> Enum.chunk_every(2) |> Enum.map(&Enum.join/1)
    # resp |> String.codepoints() |> Enum.chunk_every(3) |> Enum.map(&Enum.join/1)
  end

  defp build_source(num) do
    src_file_id = Fake.id()
    extracted_txt_file_id = Fake.id()
    study_id = Fake.id()

    %Source{
      id: Fake.id(),
      num: num,
      type: :page,
      text: "blah blah #{num}",
      page_num: 1,
      src_file_id: src_file_id,
      publication_id: study_id,
      thumbnails: [],
      publication_type: :study,
      src_file_name: "ebook_mit-cio-generative-ai-report.pdf",
      extracted_txt_file_id: extracted_txt_file_id
    }
  end

  defp source_ids(%Source{id: id}), do: [id]
  defp source_ids(sources), do: Enum.map(sources, & &1.id)

  defp to_enum(value), do: value |> Atom.to_string() |> String.upcase()
end
