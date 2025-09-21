defmodule StreamingDelta.Streaming.DeltaDiff do
  @derive JSON.Encoder

  @type t :: %__MODULE__{
          delta: [Delta.t()],
          new_cited_source_ids: [String.t()],
          new_follow_up_questions: [String.t()]
        }

  defstruct delta: [],
            new_cited_source_ids: [],
            new_follow_up_questions: []
end
