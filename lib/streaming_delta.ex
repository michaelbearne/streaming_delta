defmodule StreamingDelta do
  @moduledoc """
  Documentation for `StreamingDelta`.
  """

  alias StreamingDelta.{Parser, Streaming}

  defdelegate parse_chunks(chunks, streaming \\ %Streaming{}, sources \\ []), to: Parser
  defdelegate parse_chunk(chunk, streaming \\ %Streaming{}, sources \\ []), to: Parser
end
