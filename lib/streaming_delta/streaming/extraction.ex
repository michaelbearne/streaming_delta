defmodule StreamingDelta.Streaming.Extraction do
  @derive JSON.Encoder

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          key: String.t(),
          raw: String.t(),
          delta: [Delta.t()]
        }

  defstruct [
    :id,
    :key,
    raw: "",
    delta: []
  ]
end
