defmodule StreamingDelta.Streaming.ExtractionDiff do
  @derive JSON.Encoder

  @type t :: %__MODULE__{
          idx: non_neg_integer(),
          key: String.t(),
          delta: [Delta.t()]
        }

  defstruct [
    :idx,
    :key,
    :delta
  ]
end
