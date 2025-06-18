defmodule StreamingDelta.Parser do
  alias StreamingDelta.Streaming
  alias StreamingDelta.Streaming.{Extraction, Source}

  @digits ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
  defguardp is_digit(codepoint) when codepoint in @digits

  defguardp ref_start(codepoint) when codepoint in ["[", "("]
  defguardp ref_end(codepoint) when codepoint in ["]", ")"]

  @spec parse_chunks([String.t()], Streaming.t(), [Source.t()]) :: Streaming.t()
  def parse_chunks(chunks, resp \\ %Streaming{}, sources \\ [])

  def parse_chunks([chunk | rest] = _chunks, %Streaming{} = resp, sources) do
    resp = parse_chunk(chunk, resp, sources)
    parse_chunks(rest, resp, sources)
  end

  def parse_chunks([], resp, _sources) do
    resp
  end

  @spec parse_chunk(String.t(), Streaming.t(), [Source.t()]) :: Streaming.t()
  def parse_chunk(chunk, resp \\ %Streaming{}, sources \\ [])

  def parse_chunk(chunk, %Streaming{buffer: buffer} = resp, sources) when is_binary(chunk) do
    {buffer, resp} = parse(buffer, String.codepoints(chunk), resp, sources)
    %{resp | buffer: buffer}
  end

  # -= follow up questions
  # parings follow up questions so no chars falls though to form buffers

  # strip the white space in between follow ups (trends?>> \n<<What)
  defp parse(
         [],
         [" " | rest],
         %Streaming{
           active_extraction: active_ext,
           follow_up_question_buffer: nil,
           follow_up_questions: fup
         } = resp,
         sources
       )
       when length(fup) > 0 do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      # %{resp | raw: concat_raw_resp(resp, " ")},
      update(resp, ext, {:concat, []}, {:concat, " "}),
      sources
    )
  end

  # start match first line only
  defp parse([], ["<" | rest], %{raw: "", delta: []} = resp, sources) do
    parse(["<"], rest, resp, sources)
  end

  defp parse(["<"], ["<" | rest], %{raw: "", delta: []} = resp, sources) do
    parse(["<", "<"], rest, resp, sources)
  end

  # start match subsequent lines
  defp parse(["\n"], ["<" | rest], resp, sources) do
    parse(["\n", "<"], rest, resp, sources)
  end

  defp parse(["\n", "<"], ["<" | rest], resp, sources) do
    parse(["\n", "<", "<"], rest, resp, sources)
  end

  # start of next follow up
  defp parse([], ["\n" | rest], %{follow_up_questions: follow_up_questions} = resp, sources)
       when length(follow_up_questions) > 0 do
    parse(["\n"], rest, resp, sources)
  end

  defp parse(
         ["<", "<"] = b,
         [codepoint | rest],
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      %{
        update(resp, ext, {:concat, []}, {:concat, b ++ [codepoint]})
        | follow_up_question_buffer: codepoint
      },
      sources
    )
  end

  defp parse(
         ["\n", "<", "<"] = b,
         [codepoint | rest],
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      %{
        update(resp, ext, {:concat, []}, {:concat, b ++ [codepoint]})
        | follow_up_question_buffer: codepoint
      },
      sources
    )
  end

  # end match
  defp parse([], [">" | rest], %Streaming{follow_up_question_buffer: buffer} = resp, sources)
       when not is_nil(buffer) do
    parse([">"], rest, resp, sources)
  end

  defp parse(
         [">"],
         [">" | rest],
         %Streaming{active_extraction: active_ext, follow_up_question_buffer: buffer} = resp,
         sources
       )
       when not is_nil(buffer) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    %{follow_up_questions: follow_up_questions} = resp

    parse(
      [],
      rest,
      %{
        update(resp, ext, {:concat, []}, {:concat, ">>"})
        | follow_up_questions: [buffer | follow_up_questions],
          follow_up_question_buffer: nil
      },
      sources
    )
  end

  # fall through follow up questions when follow up question buffering
  defp parse(
         [],
         [codepoint | rest],
         %Streaming{active_extraction: active_ext, follow_up_question_buffer: buffer} = resp,
         sources
       )
       when not is_nil(buffer) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      %{
        update(resp, ext, {:concat, []}, {:concat, codepoint})
        | follow_up_question_buffer: resp.follow_up_question_buffer <> codepoint
      },
      sources
    )
  end

  # heading

  # heading first line only
  defp parse([], ["#" | rest], %{raw: "", delta: []} = resp, sources) do
    parse([["#"]], rest, resp, sources)
  end

  defp parse(
         [["#" | _rest_headings] = headings],
         ["#" | rest],
         %{raw: "", delta: []} = resp,
         sources
       ) do
    parse([headings ++ ["#"]], rest, resp, sources)
  end

  defp parse([["#" | _rest_headings]] = b, [" " | rest], %{raw: "", delta: []} = resp, sources) do
    parse(b ++ [" "], rest, resp, sources)
  end

  defp parse(
         [["#" | _rest_headings], " "] = b,
         ["*" | rest],
         %{raw: "", delta: []} = resp,
         sources
       ) do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         [["#" | _rest_headings] = headings, " ", ["*" | _rest_stars] = stars],
         ["*" | rest],
         %{raw: "", delta: []} = resp,
         sources
       ) do
    parse([headings, " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse(
         [["#" | _rest_headings], " "] = b,
         [codepoint | rest],
         %{raw: "", delta: []} = resp,
         sources
       ) do
    parse_heading(b, codepoint, rest, resp, sources)
  end

  defp parse(
         [["#" | _rest_headings], " ", ["*" | _rest_stars]] = b,
         [codepoint | rest],
         %{raw: "", delta: []} = resp,
         sources
       ) do
    parse_heading(b, codepoint, rest, resp, sources)
  end

  # heading subsequent lines
  defp parse(["\n"], ["#" | rest], resp, sources) do
    parse(["\n", ["#"]], rest, resp, sources)
  end

  defp parse(["\n", ["#" | _rest_headings] = headings], ["#" | rest], resp, sources) do
    parse(["\n", headings ++ ["#"]], rest, resp, sources)
  end

  defp parse(["\n", ["#" | _rest_headings]] = b, [" " | rest], resp, sources) do
    parse(b ++ [" "], rest, resp, sources)
  end

  defp parse(
         ["\n", ["#" | _rest_headings], " "] = b,
         ["*" | rest],
         resp,
         sources
       ) do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         ["\n", ["#" | _rest_headings] = headings, " ", ["*" | _rest_stars] = stars],
         ["*" | rest],
         resp,
         sources
       ) do
    parse([headings, " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse(
         ["\n", ["#" | _rest_headings], " "] = b,
         [codepoint | rest],
         resp,
         sources
       ) do
    parse_heading(b, codepoint, rest, resp, sources)
  end

  defp parse(
         ["\n", ["#" | _rest_headings], " ", ["*" | _rest_stars]] = b,
         [codepoint | rest],
         resp,
         sources
       ) do
    parse_heading(b, codepoint, rest, resp, sources)
  end

  # -= extraction =-

  # buffer for key lookup
  defp parse(["\n"] = b, [delimiter | rest], %{extraction_delimiter: delimiter} = resp, sources) do
    parse(
      [delimiter],
      rest,
      %{
        resp
        | delta: concat_delta(resp, b),
          raw: concat_raw_resp(resp, b)
      },
      sources
    )
  end

  defp parse([], [delimiter | rest], %{extraction_delimiter: delimiter} = resp, sources) do
    parse([delimiter], rest, resp, sources)
  end

  defp parse(
         [delimiter | buffered_rest] = buffered,
         [codepoint | rest],
         %{extraction_delimiter: delimiter, extraction_keys: [_f | _r] = keys} = resp,
         sources
       ) do
    parsed_key = IO.iodata_to_binary(buffered_rest ++ [codepoint])

    match =
      for key <- keys, reduce: nil do
        nil ->
          match_parsed_key_to_key(parsed_key, key)

        {:matched, _key} = previous_match ->
          new_match = match_parsed_key_to_key(parsed_key, key)

          if new_match do
            raise "Invalid multiple extraction keys match #{inspect([previous_match, new_match])}"
          else
            previous_match
          end

        {:matching, _key} = previous_match ->
          case match_parsed_key_to_key(parsed_key, key) do
            {:matched, _key} = new_match ->
              raise "Invalid multiple extraction keys match #{inspect([previous_match, new_match])}"

            _ ->
              previous_match
          end
      end

    case match do
      {:matched, key} ->
        if resp.active_extraction do
          parse(
            [],
            rest,
            %{
              resp
              | active_extraction: nil,
                raw: concat_raw_resp(resp, buffered ++ [codepoint])
            },
            sources
          )
        else
          active_extraction = map_size(resp.extractions) + 1

          parse(
            [],
            rest,
            %{
              resp
              | active_extraction: active_extraction,
                raw: concat_raw_resp(resp, buffered ++ [codepoint]),
                extractions:
                  Map.put(resp.extractions, active_extraction, %Extraction{
                    id: active_extraction,
                    key: key
                  })
            },
            sources
          )
        end

      {:matching, _key} ->
        parse(buffered ++ [codepoint], rest, resp, sources)

      nil ->
        parse(
          [],
          rest,
          %{
            resp
            | delta: concat_delta(resp, buffered ++ [codepoint]),
              raw: concat_raw_resp(resp, buffered ++ [codepoint])
          },
          sources
        )
    end
  end

  # -= source ref =-

  # buffer maybe start of source ref
  defp parse(
         [],
         [" " | rest],
         %{follow_up_question_buffer: nil, follow_up_questions: [], raw: raw} = resp,
         sources
       )
       when raw != "" do
    parse([" "], rest, resp, sources)
  end

  # buffer start [ or (
  defp parse(["\n"], [codepoint | rest], resp, sources) when ref_start(codepoint) do
    parse(["\n", codepoint], rest, resp, sources)
  end

  defp parse([], [codepoint | rest], resp, sources) when ref_start(codepoint) do
    parse([codepoint], rest, resp, sources)
  end

  defp parse([" "], [codepoint | rest], resp, sources) when ref_start(codepoint) do
    parse([" ", codepoint], rest, resp, sources)
  end

  # # maybe start of a subsequent ref .e.g. [1],[2]
  defp parse([], ["," | rest], resp, sources) do
    parse([","], rest, resp, sources)
  end

  # buffer ref num with leading comma (,)
  defp parse([","], [codepoint | rest], resp, sources)
       when ref_start(codepoint) do
    parse([",", codepoint], rest, resp, sources)
  end

  defp parse([",", start] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and is_digit(codepoint) do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  defp parse([",", start | _buffer_rest] = b, [codepoint | rest], resp, sources)
       when (ref_start(start) and is_digit(codepoint)) or codepoint == "-" do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  defp parse(["\n", start] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and is_digit(codepoint) do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  defp parse(["\n", start | _buffer_rest] = b, [codepoint | rest], resp, sources)
       when (ref_start(start) and is_digit(codepoint)) or codepoint == "-" do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  # buffer ref num with leading comma and white space (, )
  defp parse([","], [" " | rest], resp, sources) do
    parse([",", " "], rest, resp, sources)
  end

  defp parse([",", " "] = b, [codepoint | rest], resp, sources)
       when ref_start(codepoint) do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  defp parse([",", " ", start] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and is_digit(codepoint) do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  defp parse([",", " ", start | _buffer_rest] = b, [codepoint | rest], resp, sources)
       when (ref_start(start) and is_digit(codepoint)) or codepoint == "-" do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  # buffer ref num
  defp parse([start], [codepoint | rest], resp, sources)
       when ref_start(start) and is_digit(codepoint) do
    parse([start, codepoint], rest, resp, sources)
  end

  defp parse([" ", start], [codepoint | rest], resp, sources)
       when ref_start(start) and is_digit(codepoint) do
    parse([" ", start, codepoint], rest, resp, sources)
  end

  defp parse([start | _buffer_rest] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and (is_digit(codepoint) or codepoint in [",", " ", "-"]) do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  defp parse([" ", start | _buffer_rest] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and (is_digit(codepoint) or codepoint in [",", " ", "-"]) do
    parse(b ++ [codepoint], rest, resp, sources)
  end

  # leading (, [)
  defp parse([",", " ", start | refs] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and ref_end(codepoint) do
    parse_source_ref_end(b, refs, codepoint, rest, resp, sources)
  end

  # leading (,[])
  defp parse([",", start | refs] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and ref_end(codepoint) do
    parse_source_ref_end(b, refs, codepoint, rest, resp, sources)
  end

  defp parse([start | refs] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and ref_end(codepoint) do
    parse_source_ref_end(b, refs, codepoint, rest, resp, sources)
  end

  defp parse([" ", start | refs] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and ref_end(codepoint) do
    parse_source_ref_end(b, refs, codepoint, rest, resp, sources)
  end

  defp parse(["\n", start | refs] = b, [codepoint | rest], resp, sources)
       when ref_start(start) and ref_end(codepoint) do
    parse_source_ref_end(b, refs, codepoint, rest, resp, sources)
  end

  # -= Unordered list =-

  # Unordered list dash (-) first line only
  defp parse([], ["-" | rest], %{raw: "", delta: []} = resp, sources) do
    parse(["-"], rest, resp, sources)
  end

  defp parse(["-"], [" " | rest], %{raw: "", delta: []} = resp, sources) do
    parse(["-", " "], rest, resp, sources)
  end

  defp parse(["-", " "] = b, ["*" | rest], %{raw: "", delta: []} = resp, sources) do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         ["-", " ", ["*" | _rest_stars] = stars],
         ["*" | rest],
         %{raw: "", delta: []} = resp,
         sources
       ) do
    parse(["-", " ", stars ++ ["*"]], rest, resp, sources)
  end

  # Unordered list star (*) first line only
  defp parse([], ["*" | rest], %{raw: "", delta: []} = resp, sources) do
    parse(["*"], rest, resp, sources)
  end

  defp parse(["*"], [" " | rest], %{raw: "", delta: []} = resp, sources) do
    parse(["*", " "], rest, resp, sources)
  end

  defp parse(["*", " "] = b, ["*" | rest], %{raw: "", delta: []} = resp, sources) do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         ["*", " ", ["*" | _rest_stars] = stars],
         ["*" | rest],
         %{raw: "", delta: []} = resp,
         sources
       ) do
    parse(["*", " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse([delimiter, " "] = b, [codepoint | rest], %{raw: "", delta: []} = resp, sources)
       when delimiter in ["-", "*"] do
    parse_unordered_list(b, codepoint, rest, resp, sources)
  end

  defp parse([delimiter, " ", ["*" | _rest_stars]] = b, [codepoint | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse_unordered_list(b, codepoint, rest, resp, sources)
  end

  # Unordered list indented dash (-) or star (*) first line only
  defp parse(
         [[" " | _white_space] = white_space],
         [delimiter | rest],
         %{raw: "", delta: []} = resp,
         sources
       )
       when delimiter in ["-", "*"] do
    parse([white_space, delimiter], rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space] = white_space, delimiter],
         [" " | rest],
         %{raw: "", delta: []} = resp,
         sources
       )
       when delimiter in ["-", "*"] do
    parse([white_space, delimiter, " "], rest, resp, sources)
  end

  defp parse([[" " | _white_space], delimiter, " "] = b, ["*" | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space] = white_space, delimiter, " ", ["*" | _rest_stars] = stars],
         ["*" | rest],
         resp,
         sources
       )
       when delimiter in ["-", "*"] do
    parse([white_space, delimiter, " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space], delimiter, " "] = b,
         [codepoint | rest],
         resp,
         sources
       )
       when delimiter in ["-", "*"] do
    parse_unordered_list(b, codepoint, rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space], delimiter, " ", ["*" | _rest_stars]] = b,
         [codepoint | rest],
         resp,
         sources
       )
       when delimiter in ["-", "*"] do
    parse_unordered_list(b, codepoint, rest, resp, sources)
  end

  # Unordered list subsequent lines dash (-) or star (*)
  defp parse(["\n"], [delimiter | rest], resp, sources) when delimiter in ["-", "*"] do
    parse(["\n", delimiter], rest, resp, sources)
  end

  defp parse(["\n", delimiter] = b, [" " | rest], resp, sources) when delimiter in ["-", "*"] do
    parse(b ++ [" "], rest, resp, sources)
  end

  defp parse(["\n", delimiter, " "] = b, ["*" | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(["\n", delimiter, " ", ["*" | _rest_stars] = stars], ["*" | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse(["\n", delimiter, " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse(["\n", delimiter, " "] = b, [codepoint | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse_unordered_list(b, codepoint, rest, resp, sources)
  end

  defp parse(["\n", delimiter, " ", ["*" | _rest_stars]] = b, [codepoint | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse_unordered_list(b, codepoint, rest, resp, sources)
  end

  # Unordered list indented subsequent lines dash (-) or star (*)
  defp parse(["\n", [" " | _white_space] = white_space], [delimiter | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse(["\n", white_space, delimiter], rest, resp, sources)
  end

  defp parse(["\n", [" " | _white_space], delimiter] = b, [" " | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse(b ++ [" "], rest, resp, sources)
  end

  defp parse(["\n", [" " | _white_space], delimiter, " "] = b, ["*" | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _white_space] = white_space, delimiter, " ", ["*" | _rest_stars] = stars],
         ["*" | rest],
         resp,
         sources
       )
       when delimiter in ["-", "*"] do
    parse(["\n", white_space, delimiter, " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse(["\n", [" " | _white_space], delimiter, " "] = b, [codepoint | rest], resp, sources)
       when delimiter in ["-", "*"] do
    parse_unordered_list(b, codepoint, rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _white_space], delimiter, " ", ["*" | _rest_stars]] = b,
         [codepoint | rest],
         resp,
         sources
       )
       when delimiter in ["-", "*"] do
    parse_unordered_list(b, codepoint, rest, resp, sources)
  end

  # -= Order list =-

  # Order list first line

  defp parse([], [digit | rest], %{raw: "", delta: []} = resp, sources)
       when is_digit(digit) do
    parse([[digit]], rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space] = white_space],
         [digit | rest],
         %{raw: "", delta: []} = resp,
         sources
       )
       when is_digit(digit) do
    parse([white_space, [digit]], rest, resp, sources)
  end

  defp parse([[digit | _rest_digits]] = b, ["." | rest], resp, sources) when is_digit(digit) do
    parse(b ++ ["."], rest, resp, sources)
  end

  defp parse([[digit | _rest_digits] = digits], [next_digit | rest], resp, sources)
       when is_digit(digit) and is_digit(next_digit) do
    parse([digits ++ [next_digit]], rest, resp, sources)
  end

  defp parse(
         [[digit | _rest_digits] = digits, "."],
         [next_digit | rest],
         resp,
         sources
       )
       when is_digit(digit) and is_digit(next_digit) do
    parse([digits ++ [".", next_digit]], rest, resp, sources)
  end

  defp parse([[digit | _rest_digits], "."] = b, [" " | rest], resp, sources)
       when is_digit(digit) do
    parse(b ++ [" "], rest, resp, sources)
  end

  defp parse([[digit | _rest_digits], ".", " "] = b, ["*" | rest], resp, sources)
       when is_digit(digit) do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         [[digit | _rest_digits] = digits, ".", " ", ["*" | _rest_stars] = stars],
         ["*" | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse([digits, ".", " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse([[digit | _rest_digits], ".", " "] = b, [codepoint | rest], resp, sources)
       when is_digit(digit) do
    parse_order_list(b, codepoint, rest, resp, sources)
  end

  defp parse(
         [[digit | _rest_digits], ".", " ", ["*" | _rest_stars]] = b,
         [codepoint | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse_order_list(b, codepoint, rest, resp, sources)
  end

  # Order list first line with white space suffix
  defp parse([[" " | _white_space], [digit | _rest_digits]] = b, ["." | rest], resp, sources)
       when is_digit(digit) do
    parse(b ++ ["."], rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space] = white_space, [digit | _rest_digits] = digits],
         [next_digit | rest],
         resp,
         sources
       )
       when is_digit(digit) and is_digit(next_digit) do
    parse([white_space, digits ++ [next_digit]], rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space] = white_space, [digit | _rest_digits] = digits, "."],
         [next_digit | rest],
         resp,
         sources
       )
       when is_digit(digit) and is_digit(next_digit) do
    parse([white_space, digits ++ [".", next_digit]], rest, resp, sources)
  end

  defp parse([[" " | _white_space], [digit | _rest_digits], "."] = b, [" " | rest], resp, sources)
       when is_digit(digit) do
    parse(b ++ [" "], rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space], [digit | _rest_digits], ".", " "] = b,
         ["*" | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         [
           [" " | _white_space] = white_space,
           [digit | _rest_digits] = digits,
           ".",
           " ",
           ["*" | _rest_stars] = stars
         ],
         ["*" | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse([white_space, digits, ".", " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space], [digit | _rest_digits], ".", " "] = b,
         [codepoint | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse_order_list(b, codepoint, rest, resp, sources)
  end

  defp parse(
         [[" " | _white_space], [digit | _rest_digits], ".", " ", ["*" | _rest_stars]] = b,
         [codepoint | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse_order_list(b, codepoint, rest, resp, sources)
  end

  # Order list subsequent lines

  defp parse(["\n"], [digit | rest], resp, sources) when is_digit(digit) do
    parse(["\n", [digit]], rest, resp, sources)
  end

  defp parse(["\n", [digit | _rest_digits] = digits], [next_digit | rest], resp, sources)
       when is_digit(digit) and is_digit(next_digit) do
    parse(["\n" | [digits ++ [next_digit]]], rest, resp, sources)
  end

  defp parse(
         ["\n", [digit | _rest_digits] = digits, "."],
         [next_digit | rest],
         resp,
         sources
       )
       when is_digit(digit) and is_digit(next_digit) do
    parse(["\n", digits ++ [".", next_digit]], rest, resp, sources)
  end

  defp parse(["\n", [digit | _rest_digits]] = b, ["." | rest], resp, sources)
       when is_digit(digit) do
    parse(b ++ ["."], rest, resp, sources)
  end

  defp parse(["\n", [digit | _rest_digits], "."] = b, [" " | rest], resp, sources)
       when is_digit(digit) do
    parse(b ++ [" "], rest, resp, sources)
  end

  defp parse(
         ["\n", [digit | _rest_digits], ".", " "] = b,
         ["*" | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         ["\n", [digit | _rest_digits] = digits, ".", " ", ["*" | _rest_stars] = stars],
         ["*" | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse(["\n", digits, ".", " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse(["\n", [digit | _rest_digits], ".", " "] = b, [codepoint | rest], resp, sources)
       when is_digit(digit) do
    parse_order_list(b, codepoint, rest, resp, sources)
  end

  defp parse(
         ["\n", [digit | _rest_digits], ".", " ", ["*" | _rest_stars]] = b,
         [codepoint | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse_order_list(b, codepoint, rest, resp, sources)
  end

  # Order list subsequent lines with white space suffix

  defp parse(["\n", [" " | _rest_white_space] = white_space], [digit | rest], resp, sources)
       when is_digit(digit) do
    parse(["\n", white_space, [digit]], rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _rest_white_space] = white_space, [digit | _rest_digits] = digits],
         [next_digit | rest],
         resp,
         sources
       )
       when is_digit(digit) and is_digit(next_digit) do
    parse(["\n", white_space | [digits ++ [next_digit]]], rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _rest_white_space] = white_space, [digit | _rest_digits] = digits, "."],
         [next_digit | rest],
         resp,
         sources
       )
       when is_digit(digit) and is_digit(next_digit) do
    parse(["\n", white_space, digits ++ [".", next_digit]], rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _rest_white_space], [digit | _rest_digits]] = b,
         ["." | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse(b ++ ["."], rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _rest_white_space], [digit | _rest_digits], "."] = b,
         [" " | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse(b ++ [" "], rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _rest_white_space], [digit | _rest_digits], ".", " "] = b,
         ["*" | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse(b ++ [["*"]], rest, resp, sources)
  end

  defp parse(
         [
           "\n",
           [" " | _rest_white_space] = white_space,
           [digit | _rest_digits] = digits,
           ".",
           " ",
           ["*" | _rest_stars] = stars
         ],
         ["*" | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse(["\n", white_space, digits, ".", " ", stars ++ ["*"]], rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _rest_white_space], [digit | _rest_digits], ".", " "] = b,
         [codepoint | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse_order_list(b, codepoint, rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _rest_white_space], [digit | _rest_digits], ".", " ", ["*" | _rest_stars]] =
           b,
         [codepoint | rest],
         resp,
         sources
       )
       when is_digit(digit) do
    parse_order_list(b, codepoint, rest, resp, sources)
  end

  # Emphasis stars * italic,  ** bold, *** italic & bold

  # Emphasis start of fist line only

  defp parse([["*" | _rest_stars] = stars], ["*" | rest], %Streaming{raw: ""} = resp, sources) do
    parse([stars ++ ["*"]], rest, resp, sources)
  end

  # convert form unorderd list match to emphasis match
  defp parse(["*"], ["*" | rest], %Streaming{raw: ""} = resp, sources) do
    parse([["*", "*"]], rest, resp, sources)
  end

  # convert form unorderd list match to emphasis match
  defp parse(["*"], [codepoint | rest], %Streaming{raw: ""} = resp, sources) do
    parse_emphasis([["*"]], codepoint, rest, resp, sources)
  end

  defp parse([["*" | _rest_stars]] = b, [codepoint | rest], %Streaming{raw: ""} = resp, sources) do
    parse_emphasis(b, codepoint, rest, resp, sources)
  end

  # Emphasis start of sentence after a heading or a list

  defp parse(
         ["\n", ["*" | _rest_stars] = stars],
         ["*" | rest],
         resp,
         sources
       ) do
    parse(["\n", stars ++ ["*"]], rest, resp, sources)
  end

  # convert form unorderd list match to emphasis match
  defp parse(["\n", "*"], ["*" | rest], resp, sources) do
    parse(["\n", ["*", "*"]], rest, resp, sources)
  end

  # # convert form unorderd list match to emphasis match
  defp parse(
         ["\n", "*"],
         [codepoint | rest],
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    case List.last(resp.delta) do
      %{"insert" => "\n", "attributes" => attrs} when map_size(attrs) > 0 ->
        parse_emphasis(
          [["*"]],
          codepoint,
          rest,
          %{update(resp, ext, {:concat, []}, {:concat, "\n"}) | streaming: nil},
          sources
        )

      _ ->
        parse_emphasis(
          [["*"]],
          codepoint,
          rest,
          update(resp, ext, {:concat, "\n"}),
          sources
        )
    end
  end

  defp parse(
         ["\n", ["*" | _rest_stars] = stars],
         [codepoint | rest],
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    case List.last(resp.delta) do
      %{"insert" => "\n", "attributes" => attrs} when map_size(attrs) > 0 ->
        parse_emphasis(
          [stars],
          codepoint,
          rest,
          %{update(resp, ext, {:concat, []}, {:concat, "\n"}) | streaming: nil},
          sources
        )

      _ ->
        parse_emphasis(
          [stars],
          codepoint,
          rest,
          update(resp, ext, {:concat, "\n"}),
          sources
        )
    end
  end

  # Emphasis in sentence unbuffer white space and buffer *
  defp parse([" "], ["*" | rest], %Streaming{active_extraction: active_ext} = resp, sources) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    parse([["*"]], rest, update(resp, ext, {:concat, " "}), sources)
  end

  defp parse([], ["*" | rest], resp, sources) do
    parse([["*"]], rest, resp, sources)
  end

  defp parse([["*" | _rest_stars] = stars], ["*" | rest], resp, sources) do
    parse([stars ++ ["*"]], rest, resp, sources)
  end

  defp parse([["*" | _rest_stars]] = b, [codepoint | rest], resp, sources) do
    parse_emphasis(b, codepoint, rest, resp, sources)
  end

  # -= common

  # buffer maybe start of list or heading
  defp parse([], ["\n" | rest], resp, sources) do
    parse(["\n"], rest, resp, sources)
  end

  # end of streaming list or heading line strip blank line
  defp parse(
         ["\n"],
         ["\n" | rest],
         %Streaming{streaming: streaming, active_extraction: active_ext} = resp,
         sources
       )
       when not is_nil(streaming) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      ["\n"],
      rest,
      %{update(resp, ext, {:concat, []}, {:concat, "\n"}) | streaming: nil},
      sources
    )
  end

  # end of streaming ordered list line
  defp parse(["\n"] = b, rest, %Streaming{streaming: streaming} = resp, sources)
       when not is_nil(streaming) do
    parse(b, rest, %{resp | streaming: nil}, sources)
  end

  # remove blank line
  defp parse(["\n"], ["\n" | rest], %Streaming{active_extraction: active_ext} = resp, sources) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      ["\n"],
      rest,
      update(resp, ext, {:concat, []}, {:concat, "\n"}),
      sources
    )
  end

  # buffer white space at start
  defp parse(
         [],
         [" " | rest],
         %Streaming{active_extraction: _active_ext, raw: ""} = resp,
         sources
       ) do
    parse([[" "]], rest, resp, sources)
  end

  defp parse(
         [[" " | _rest] = white_space],
         [" " | rest],
         %Streaming{active_extraction: _active_ext} = resp,
         sources
       ) do
    parse([white_space ++ [" "]], rest, resp, sources)
  end

  # buffer white space after a new line and remove if not needed
  defp parse(["\n"], [" " | rest], %Streaming{active_extraction: _active_ext} = resp, sources) do
    parse(["\n", [" "]], rest, resp, sources)
  end

  defp parse(
         ["\n", [" " | _rest] = white_space],
         [" " | rest],
         %Streaming{active_extraction: _active_ext} = resp,
         sources
       ) do
    parse(["\n", white_space ++ [" "]], rest, resp, sources)
  end

  defp parse(
         ["\n" | buffer_rest],
         [codepoint | rest],
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    case List.last(resp.delta) do
      # remove blank line
      %{"insert" => "\n", "attributes" => attrs} when map_size(attrs) > 0 ->
        parse(
          [],
          rest,
          update(
            resp,
            ext,
            {:concat, [buffer_rest, codepoint]},
            {:concat, ["\n", buffer_rest, codepoint]}
          ),
          sources
        )

      _ ->
        parse(
          [],
          rest,
          update(resp, ext, {:concat, ["\n", buffer_rest, codepoint]}),
          sources
        )
    end
  end

  # If a source was referenced just before a full stop inject a new line
  # if there is already a new line it will be striped as a blank line
  defp parse([], ["." | rest], %Streaming{active_extraction: active_ext} = resp, sources) do
    %{delta: delta_resp} = resp
    delta_size = Delta.size(delta_resp)
    ext = active_ext && Map.get(resp.extractions, active_ext)

    rest =
      if delta_size > 2 &&
           (delta_resp |> Delta.slice(delta_size - 1, 1) |> List.first())["attributes"]["source"] do
        ["\n" | rest]
      else
        rest
      end

    parse(
      [],
      rest,
      update(resp, ext, {:concat, "."}),
      sources
    )
  end

  # -= fall through =-

  defp parse(
         buffer,
         [codepoint | rest],
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      update(resp, ext, {:concat, buffer ++ [codepoint]}),
      sources
    )
  end

  defp parse(buffer, [], resp, _sources) do
    {buffer, resp}
  end

  defp parse_heading(
         buffer,
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    delta_resp = Map.get(ext || %{}, :delta, resp.delta)

    resp =
      case buffer do
        [["#" | _rest_headings], " ", ["*", "*", "*"]] ->
          %{resp | streaming_bold: true, streaming_italic: true}

        [["#" | _rest_headings], " ", ["*", "*"]] ->
          %{resp | streaming_bold: true}

        [["#" | _rest_headings], " ", ["*"]] ->
          %{resp | streaming_italic: true}

        [["#" | _rest_headings], " ", ["*", "*", "*" | _rest_stars]] ->
          resp

        [["#" | _rest_headings], " "] ->
          resp

        ["\n", ["#" | _rest_headings], " ", ["*", "*", "*"]] ->
          %{resp | streaming_bold: true, streaming_italic: true}

        ["\n", ["#" | _rest_headings], " ", ["*", "*"]] ->
          %{resp | streaming_bold: true}

        ["\n", ["#" | _rest_headings], " ", ["*"]] ->
          %{resp | streaming_italic: true}

        ["\n", ["#" | _rest_headings], " ", ["*", "*", "*" | _rest_stars]] ->
          resp

        ["\n", ["#" | _rest_headings], " "] ->
          resp
      end

    header =
      case buffer do
        [["#" | _rest_headings] = headings | _rest] ->
          length(headings)

        ["\n", ["#" | _rest_headings] = headings | _rest] ->
          length(headings)

        _ ->
          1
      end

    new_delta_resp =
      case List.last(delta_resp) do
        nil ->
          Delta.concat(delta_resp, [
            Delta.Op.insert(codepoint, delta_attrs(resp)),
            Delta.Op.insert("\n", %{"header" => header})
          ])

        # below a line new line already applied
        %{"insert" => "\n", "attributes" => previous_line_attrs}
        when map_size(previous_line_attrs) > 0 ->
          Delta.concat(delta_resp, [
            Delta.Op.insert(codepoint, delta_attrs(resp)),
            Delta.Op.insert("\n", %{"header" => header})
          ])

        _ ->
          Delta.concat(delta_resp, [
            Delta.Op.insert("\n", delta_attrs(resp)),
            Delta.Op.insert(codepoint, delta_attrs(resp)),
            Delta.Op.insert("\n", %{"header" => header})
          ])
      end

    parse(
      [],
      rest,
      %{
        update(resp, ext, {:replace, new_delta_resp}, {:concat, buffer ++ [codepoint]})
        | streaming: :header
      },
      sources
    )
  end

  defp parse_emphasis(
         [["*", "*", "*"]],
         "\n",
         rest,
         %Streaming{
           active_extraction: active_ext,
           streaming_bold: true,
           streaming_italic: true
         } =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      ["\n"],
      rest,
      update(
        %{resp | streaming_bold: false, streaming_italic: false, streaming: nil},
        ext,
        {:concat, []},
        {:concat, "***"}
      ),
      sources
    )
  end

  # not a emphasis due to white space after *
  defp parse_emphasis(
         [["*", "*", "*"]],
         " ",
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: false, streaming_italic: false} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    parse([], rest, update(resp, ext, {:concat, "*** "}), sources)
  end

  defp parse_emphasis(
         [["*", "*", "*"]],
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: false, streaming_italic: false} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      update(
        %{resp | streaming_bold: true, streaming_italic: true},
        ext,
        {:concat, codepoint},
        {:concat, "***" <> codepoint}
      ),
      sources
    )
  end

  # when a colon stright after the bold,italic close also make colon bold
  defp parse_emphasis(
         [["*", "*", "*"]],
         ":",
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: true, streaming_italic: true} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      %{
        update(
          resp,
          ext,
          {:concat, ":"},
          {:concat, "***:"}
        )
        | streaming_bold: false,
          streaming_italic: false
      },
      sources
    )
  end

  defp parse_emphasis(
         [["*", "*", "*"]],
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: true, streaming_italic: true} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      update(
        %{resp | streaming_bold: false, streaming_italic: false},
        ext,
        {:concat, codepoint},
        {:concat, "***" <> codepoint}
      ),
      sources
    )
  end

  # not a bold due to white space after *
  defp parse_emphasis(
         [["*", "*"]],
         " ",
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: false} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    parse([], rest, update(resp, ext, {:concat, "** "}), sources)
  end

  defp parse_emphasis(
         [["*", "*"]],
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: false} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      update(
        %{resp | streaming_bold: true},
        ext,
        {:concat, codepoint},
        {:concat, "**" <> codepoint}
      ),
      sources
    )
  end

  # remove the new line
  defp parse_emphasis(
         [["*", "*"]],
         "\n",
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: true} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      ["\n"],
      rest,
      update(
        %{resp | streaming_bold: false, streaming: nil},
        ext,
        {:concat, []},
        {:concat, "**"}
      ),
      sources
    )
  end

  # when a colon stright after the bold close also make bold
  defp parse_emphasis(
         [["*", "*"]],
         ":",
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: true} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      %{
        update(
          resp,
          ext,
          {:concat, ":"},
          {:concat, "**:"}
        )
        | streaming_bold: false
      },
      sources
    )
  end

  defp parse_emphasis(
         [["*", "*"]],
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext, streaming_bold: true} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      update(
        %{resp | streaming_bold: false},
        ext,
        {:concat, codepoint},
        {:concat, "**" <> codepoint}
      ),
      sources
    )
  end

  # not italic due to white space
  defp parse_emphasis(
         [["*"]],
         " ",
         rest,
         %Streaming{active_extraction: active_ext, streaming_italic: false} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    parse([], rest, update(resp, ext, {:concat, "* "}), sources)
  end

  defp parse_emphasis(
         [["*"]],
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext, streaming_italic: false} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      update(
        %{resp | streaming_italic: true},
        ext,
        {:concat, codepoint},
        {:concat, "*" <> codepoint}
      ),
      sources
    )
  end

  # remove new line
  defp parse_emphasis(
         [["*"]],
         "\n",
         rest,
         %Streaming{active_extraction: active_ext, streaming_italic: true} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      ["\n"],
      rest,
      update(
        %{resp | streaming_italic: false, streaming: nil},
        ext,
        {:concat, []},
        {:concat, "*"}
      ),
      sources
    )
  end

  defp parse_emphasis(
         [["*"]],
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext, streaming_italic: true} =
           resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      update(
        %{resp | streaming_italic: false},
        ext,
        {:concat, codepoint},
        {:concat, "*" <> codepoint}
      ),
      sources
    )
  end

  # emphasis fall through more than 3 stars
  defp parse_emphasis(
         [["*", "*", "*" | _rest]] = b,
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)

    parse(
      [],
      rest,
      update(resp, ext, {:concat, b ++ codepoint}),
      sources
    )
  end

  defp parse_unordered_list(
         buffer,
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    delta_resp = Map.get(ext || %{}, :delta, resp.delta)

    indent =
      case buffer do
        [[" " | _white_space_rest] = white_space | _rest] ->
          div(length(white_space), 4)

        ["\n", [" " | _white_space_rest] = white_space | _rest] ->
          div(length(white_space), 4)

        _ ->
          nil
      end

    emphasised_buffer =
      case buffer do
        [delimiter, " "] when delimiter in ["-", "*"] ->
          []

        [delimiter, " ", ["*" | _rest_stars] = stars] when delimiter in ["-", "*"] ->
          stars

        ["\n", delimiter, " "] when delimiter in ["-", "*"] ->
          []

        ["\n", delimiter, " ", ["*" | _rest_stars] = stars] when delimiter in ["-", "*"] ->
          stars

        [[" " | _white_space_rest], delimiter, " "] when delimiter in ["-", "*"] ->
          []

        [[" " | _white_space_rest], delimiter, " ", ["*" | _rest_stars] = stars]
        when delimiter in ["-", "*"] ->
          stars

        ["\n", [" " | _white_space_rest], delimiter, " "] when delimiter in ["-", "*"] ->
          []

        ["\n", [" " | _white_space_rest], delimiter, " ", ["*" | _rest_stars] = stars]
        when delimiter in ["-", "*"] ->
          stars
      end

    attrs =
      if indent do
        %{"list" => "bullet", "indent" => indent}
      else
        %{"list" => "bullet"}
      end

    emphasised_resp =
      case emphasised_buffer do
        ["*", "*", "*"] ->
          %{resp | streaming_bold: true, streaming_italic: true}

        ["*", "*"] ->
          %{resp | streaming_bold: true}

        ["*"] ->
          %{resp | streaming_italic: true}

        _ ->
          resp
      end

    new_delta_resp =
      case List.last(delta_resp) do
        nil ->
          Delta.concat(delta_resp, [
            Delta.Op.insert(codepoint, delta_attrs(emphasised_resp)),
            Delta.Op.insert("\n", attrs)
          ])

        # below a line new line already applied
        %{"insert" => "\n", "attributes" => previous_line_attrs}
        when map_size(previous_line_attrs) > 0 ->
          Delta.concat(delta_resp, [
            Delta.Op.insert(codepoint, delta_attrs(emphasised_resp)),
            Delta.Op.insert("\n", attrs)
          ])

        _ ->
          Delta.concat(delta_resp, [
            Delta.Op.insert("\n", delta_attrs(resp)),
            Delta.Op.insert(codepoint, delta_attrs(emphasised_resp)),
            Delta.Op.insert("\n", attrs)
          ])
      end

    parse(
      [],
      rest,
      %{
        update(emphasised_resp, ext, {:replace, new_delta_resp}, {:concat, buffer ++ [codepoint]})
        | streaming: :unordered_list
      },
      sources
    )
  end

  defp parse_order_list(
         buffer,
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    delta_resp = Map.get(ext || %{}, :delta, resp.delta)

    indent =
      case buffer do
        [[" " | _white_space_rest] = white_space | _rest] ->
          div(length(white_space), 4)

        ["\n", [" " | _white_space_rest] = white_space | _rest] ->
          div(length(white_space), 4)

        _ ->
          nil
      end

    emphasised_stars =
      case buffer do
        [[digit | _rest_digits], ".", " "] when is_digit(digit) ->
          []

        [[digit | _rest_digits], ".", " ", ["*" | _rest_stars] = stars] when is_digit(digit) ->
          stars

        [[" " | _white_space], [digit | _rest_digits], ".", " "] when is_digit(digit) ->
          []

        [[" " | _white_space], [digit | _rest_digits], ".", " ", ["*" | _rest_stars] = stars]
        when is_digit(digit) ->
          stars

        ["\n", [digit | _rest_digits], ".", " "] when is_digit(digit) ->
          []

        ["\n", [digit | _rest_digits], ".", " ", ["*" | _rest_stars] = stars]
        when is_digit(digit) ->
          stars

        ["\n", [" " | _rest_white_space], [digit | _rest_digits], ".", " "]
        when is_digit(digit) ->
          []

        [
          "\n",
          [" " | _rest_white_space],
          [digit | _rest_digits],
          ".",
          " ",
          ["*" | _rest_stars] = stars
        ]
        when is_digit(digit) ->
          stars
      end

    attrs =
      if indent do
        %{"list" => "ordered", "indent" => indent}
      else
        %{"list" => "ordered"}
      end

    emphasised_resp =
      case emphasised_stars do
        ["*", "*", "*"] ->
          %{resp | streaming_bold: true, streaming_italic: true}

        ["*", "*"] ->
          %{resp | streaming_bold: true}

        ["*"] ->
          %{resp | streaming_italic: true}

        _ ->
          resp
      end

    new_delta_resp =
      case List.last(delta_resp) do
        nil ->
          Delta.concat(delta_resp, [
            Delta.Op.insert(codepoint, delta_attrs(emphasised_resp)),
            Delta.Op.insert("\n", attrs)
          ])

        # below a line new line already applied
        %{"insert" => "\n", "attributes" => previous_line_attrs}
        when map_size(previous_line_attrs) > 0 ->
          Delta.concat(delta_resp, [
            Delta.Op.insert(codepoint, delta_attrs(emphasised_resp)),
            Delta.Op.insert("\n", attrs)
          ])

        _ ->
          Delta.concat(delta_resp, [
            Delta.Op.insert("\n", delta_attrs(resp)),
            Delta.Op.insert(codepoint, delta_attrs(emphasised_resp)),
            Delta.Op.insert("\n", attrs)
          ])
      end

    parse(
      [],
      rest,
      %{
        update(
          emphasised_resp,
          ext,
          {:replace, new_delta_resp},
          {:concat, buffer ++ [codepoint]}
        )
        | streaming: :ordered_list
      },
      sources
    )
  end

  defp parse_source_ref_end(
         buffer,
         refs,
         codepoint,
         rest,
         %Streaming{active_extraction: active_ext} = resp,
         sources
       ) do
    ext = active_ext && Map.get(resp.extractions, active_ext)
    delta_resp = Map.get(ext || %{}, :delta, resp.delta)

    refs_text = Enum.join(refs)

    cited_sources =
      case String.split(refs_text, "-") do
        [from, to] ->
          from_source =
            case Integer.parse(from) do
              {num, ""} -> Enum.find(sources, &(&1.num == num))
              _error -> nil
            end

          to_source =
            case Integer.parse(to) do
              {num, ""} -> Enum.find(sources, &(&1.num == num))
              _error -> nil
            end

          if from_source && to_source do
            for num <- from_source.num..to_source.num do
              Enum.find(sources, &(&1.num == num))
            end
          else
            []
          end

        _ ->
          source_nums = refs_text |> String.replace(~r/(?:,\s)/, ",") |> String.split(",")

          Enum.map(source_nums, fn num ->
            case Integer.parse(num) do
              {num, ""} -> Enum.find(sources, &(&1.num == num))
              _error -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)
      end

    cited_sources_ids = Enum.map(cited_sources, & &1.id)

    new_delta_resp =
      if Enum.empty?(cited_sources) do
        concat_delta(resp, buffer ++ [codepoint])
      else
        Delta.compose(
          delta_resp,
          [
            # traling white space removed removed as in the buffer
            delta_retain_to_insertion_point(resp),
            if(List.first(buffer) == "\n",
              do: Delta.Op.insert("\n", delta_attrs(resp)),
              else: []
            ),
            Enum.map(cited_sources, fn cited_source ->
              Delta.Op.insert("[#{cited_source.num}]", delta_attrs(resp, cited_source))
            end)
          ]
          |> List.flatten()
        )
      end

    parse(
      [],
      rest,
      %{
        update(resp, ext, {:replace, new_delta_resp}, {:concat, buffer ++ [codepoint]})
        | cited_source_ids: Enum.uniq(resp.cited_source_ids ++ cited_sources_ids)
      },
      sources
    )
  end

  @delta_actions [:concat, :replace]

  defp update(%Streaming{} = s, nil, delta) when is_tuple(delta) do
    update(s, delta, delta)
  end

  defp update(%Streaming{} = s, {delta_action, delta}, {raw_action, raw_delta})
       when delta_action in @delta_actions and raw_action in @delta_actions do
    %{
      s
      | delta:
          case delta_action do
            :concat -> concat_delta(s, delta)
            :replace -> delta
          end,
        raw:
          case raw_action do
            :concat -> concat_raw_resp(s, raw_delta)
            :replace -> raw_delta
          end
    }
  end

  defp update(%Streaming{} = s, %Extraction{} = ext, delta)
       when is_tuple(delta) do
    update(s, ext, delta, delta)
  end

  defp update(%Streaming{} = s, nil, delta, raw_delta)
       when is_tuple(delta) and is_tuple(raw_delta) do
    update(s, delta, raw_delta)
  end

  defp update(
         %Streaming{} = s,
         %Extraction{} = ext,
         {delta_action, delta},
         {raw_action, raw_delta}
       )
       when delta_action in @delta_actions and raw_action in @delta_actions do
    new_ext = %{
      ext
      | delta:
          case delta_action do
            :concat -> concat_delta(s, ext, delta)
            :replace -> delta
          end,
        raw:
          case raw_action do
            :concat -> concat_raw_resp(ext, raw_delta)
            :replace -> raw_delta
          end
    }

    %{
      s
      | extractions: Map.put(s.extractions, new_ext.id, new_ext),
        raw:
          case raw_action do
            :concat -> concat_raw_resp(s, raw_delta)
            :replace -> raw_delta
          end
    }
  end

  defp delta_attrs(%Streaming{streaming_bold: true, streaming_italic: true}) do
    %{"bold" => true, "italic" => true}
  end

  defp delta_attrs(%Streaming{streaming_italic: true}) do
    %{"italic" => true}
  end

  defp delta_attrs(%Streaming{streaming_bold: true}) do
    %{"bold" => true}
  end

  defp delta_attrs(_resp) do
    %{}
  end

  defp delta_attrs(%Streaming{streaming_bold: true}, %Source{} = source) do
    %{"bold" => true, "source" => build_delta_attr_source(source)}
  end

  defp delta_attrs(_resp, %Source{} = source) do
    %{"source" => build_delta_attr_source(source)}
  end

  defp build_delta_attr_source(%Source{} = source) do
    %{
      "id" => source.id,
      "num" => source.num,
      "pageNum" => source.page_num,
      "publicationId" => source.publication_id,
      "publicationType" => to_enum(source.publication_type),
      "srcFileId" => source.src_file_id,
      "type" => "PAGE"
    }
  end

  defp concat_raw_resp(%Streaming{raw: raw_resp}, text) when is_binary(text) do
    raw_resp <> text
  end

  defp concat_raw_resp(%Streaming{raw: raw_resp}, text) when is_list(text) do
    raw_resp <> IO.iodata_to_binary(text)
  end

  defp concat_raw_resp(%Extraction{raw: raw_resp}, text) when is_binary(text) do
    raw_resp <> text
  end

  defp concat_raw_resp(%Extraction{raw: raw_resp}, text) when is_list(text) do
    raw_resp <> IO.iodata_to_binary(text)
  end

  defp concat_delta(resp, []), do: resp.delta

  defp concat_delta(resp, text) when is_list(text) do
    concat_delta(resp, IO.iodata_to_binary(text))
  end

  defp concat_delta(%Streaming{delta: delta_resp, streaming: nil} = resp, text)
       when is_binary(text) do
    Delta.concat(delta_resp, [Delta.Op.insert(text, delta_attrs(resp))])
  end

  defp concat_delta(%Streaming{delta: delta_resp, streaming: _streaming} = resp, text)
       when is_binary(text) do
    delta_resp_size = Delta.size(delta_resp)

    Delta.compose(delta_resp, [
      Delta.Op.retain(delta_resp_size - 1),
      Delta.Op.insert(text, delta_attrs(resp))
    ])
  end

  defp concat_delta(%Streaming{}, %Extraction{} = extraction, []) do
    extraction.delta
  end

  defp concat_delta(%Streaming{} = resp, %Extraction{} = extraction, text)
       when is_list(text) do
    concat_delta(resp, extraction, IO.iodata_to_binary(text))
  end

  defp concat_delta(
         %Streaming{streaming: nil} = resp,
         %Extraction{delta: delta_resp},
         text
       )
       when is_binary(text) do
    Delta.concat(delta_resp, [Delta.Op.insert(text, delta_attrs(resp))])
  end

  defp concat_delta(
         %Streaming{streaming: _streaming} = resp,
         %Extraction{delta: delta_resp},
         text
       )
       when is_binary(text) do
    delta_resp_size = Delta.size(delta_resp)

    Delta.compose(delta_resp, [
      Delta.Op.retain(delta_resp_size - 1),
      Delta.Op.insert(text, delta_attrs(resp))
    ])
  end

  defp delta_retain_to_insertion_point(%Streaming{delta: delta_resp, streaming: nil}) do
    Delta.Op.retain(Delta.size(delta_resp))
  end

  defp delta_retain_to_insertion_point(%Streaming{
         delta: delta_resp,
         streaming: _streaming
       }) do
    Delta.Op.retain(Delta.size(delta_resp) - 1)
  end

  defp to_enum(value), do: value |> Atom.to_string() |> String.upcase()

  defp match_parsed_key_to_key(parsed_key, key) do
    cond do
      parsed_key == key ->
        {:matched, key}

      String.starts_with?(key, parsed_key) ->
        {:matching, key}

      :no ->
        nil
    end
  end
end
