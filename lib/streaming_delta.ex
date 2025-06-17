defmodule StreamingDelta do
  @external_resource readme = Path.join([__DIR__, "../README.md"])
  @doc_readme File.read!(readme)

  @moduledoc """

  #{@doc_readme}

  ## Examples

      iex> StreamingDelta.parse_chunk("word", %StreamingDelta.Streaming{})
      %StreamingDelta.Streaming{delta: [%{"insert" => "word"}], raw: "word"}

      iex> StreamingDelta.parse_chunk("*word*\\n", %StreamingDelta.Streaming{})
      %StreamingDelta.Streaming{delta: [%{"insert" => "word", "attributes" => %{"italic" => true}}], raw: "*word*", buffer: ["\\n"]}

  """

  alias StreamingDelta.{Parser, Streaming}

  defdelegate parse_chunks(chunks, streaming \\ %Streaming{}, sources \\ []), to: Parser
  defdelegate parse_chunk(chunk, streaming \\ %Streaming{}, sources \\ []), to: Parser
end
