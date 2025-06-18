defmodule StreamingDelta.Streaming do
  alias StreamingDelta.Streaming.{DeltaDiff, Extraction, ExtractionDiff}

  @type t :: %__MODULE__{
          buffer: String.t() | [String.t()],
          streaming: nil | :unordered_list | :ordered_list | :header,
          streaming_bold: boolean,
          streaming_italic: boolean,
          raw: String.t(),
          delta: [Delta.t()],
          source_ids: [String.t()],
          cited_source_ids: [String.t()],
          follow_up_questions: [String.t()],
          follow_up_question_buffer: nil | String.t(),
          extractions: %{non_neg_integer() => Extraction.t()},
          extraction_delimiter: String.t(),
          extraction_keys: [String.t()]
        }

  defstruct streaming: nil,
            buffer: [],
            raw: "",
            delta: [],
            follow_up_questions: [],
            follow_up_question_buffer: nil,
            source_ids: [],
            cited_source_ids: [],
            streaming_bold: false,
            streaming_italic: false,
            active_extraction: nil,
            extractions: %{},
            extraction_delimiter: "@",
            extraction_keys: []

  @spec diffs(t(), t()) :: [DeltaDiff.t() | ExtractionDiff.t()]
  def diffs(
        %__MODULE__{
          delta: delta,
          extractions: extractions,
          cited_source_ids: cited_source_ids,
          follow_up_questions: follow_up_questions
        },
        %__MODULE__{
          delta: delta,
          extractions: extractions,
          cited_source_ids: cited_source_ids,
          follow_up_questions: follow_up_questions
        }
      ) do
    []
  end

  def diffs(
        %__MODULE__{extractions: extractions} = current,
        %__MODULE__{extractions: extractions} = next
      ) do
    [delta_diff(current, next)]
  end

  def diffs(
        %__MODULE__{
          delta: delta,
          extractions: current_extractions,
          cited_source_ids: cited_source_ids,
          follow_up_questions: follow_up_questions
        },
        %__MODULE__{
          delta: delta,
          extractions: next_extractions,
          cited_source_ids: cited_source_ids,
          follow_up_questions: follow_up_questions
        }
      ) do
    extraction_diffs(current_extractions, next_extractions)
  end

  def diffs(
        %__MODULE__{extractions: current_extractions} = current,
        %__MODULE__{extractions: next_extractions} = next
      ) do
    [delta_diff(current, next) | extraction_diffs(current_extractions, next_extractions)]
  end

  defp delta_diff(
         %__MODULE__{
           delta: current_delta,
           cited_source_ids: cited_source_ids,
           follow_up_questions: follow_up_questions
         },
         %__MODULE__{
           delta: next_delta,
           cited_source_ids: cited_source_ids,
           follow_up_questions: follow_up_questions
         }
       ) do
    %DeltaDiff{
      delta: Delta.diff(current_delta, next_delta),
      new_cited_source_ids: [],
      new_follow_up_questions: []
    }
  end

  defp delta_diff(
         %__MODULE__{
           delta: current_delta,
           cited_source_ids: current_cited_source_ids,
           follow_up_questions: current_follow_up_questions
         },
         %__MODULE__{
           delta: next_delta,
           cited_source_ids: next_cited_source_ids,
           follow_up_questions: next_follow_up_questions
         }
       ) do
    %DeltaDiff{
      delta: Delta.diff(current_delta, next_delta),
      new_cited_source_ids: next_cited_source_ids -- current_cited_source_ids,
      new_follow_up_questions: next_follow_up_questions -- current_follow_up_questions
    }
  end

  defp extraction_diffs(current_extractions, next_extractions)
       when map_size(current_extractions) == 0 do
    for {_id, ext} <- next_extractions do
      %ExtractionDiff{idx: ext.id, key: ext.key, delta: ext.delta}
    end
  end

  defp extraction_diffs(current_extractions, next_extractions)
       when map_size(current_extractions) == map_size(next_extractions) do
    for {{key, current}, {key, next}} <- Enum.zip(current_extractions, next_extractions) do
      %ExtractionDiff{idx: next.id, key: next.key, delta: Delta.diff(current.delta, next.delta)}
    end
  end

  defp extraction_diffs(current_extractions, next_extractions) do
    for {key, next} <- next_extractions do
      case {Map.get(current_extractions, key), next} do
        {nil, next} ->
          %ExtractionDiff{idx: next.id, key: next.key, delta: next.delta}

        {%Extraction{delta: delta}, %Extraction{delta: delta}} ->
          nil

        {%Extraction{delta: current_delta}, %Extraction{delta: next_delta} = next} ->
          %ExtractionDiff{
            idx: next.id,
            key: next.key,
            delta: Delta.diff(current_delta, next_delta)
          }
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  # ----

  # def diff(
  #       %__MODULE__{active_extraction: current_ext_idx},
  #       %__MODULE__{active_extraction: next_ext_idx} = next_streaming
  #     )
  #     when is_number(next_ext_idx) and current_ext_idx != next_ext_idx do
  #   next_ext = Map.get(next_streaming.extractions, next_ext_idx)

  #   %ExtractionDiff{
  #     idx: next_ext_idx,
  #     key: next_ext.key,
  #     delta: next_ext.delta
  #   }
  # end

  # def diff(
  #       %__MODULE__{active_extraction: ext_idx} = current_streaming,
  #       %__MODULE__{active_extraction: ext_idx} = next_streaming
  #     )
  #     when is_number(ext_idx) do
  #   current_ext = Map.get(current_streaming.extractions, ext_idx)
  #   next_ext = Map.get(next_streaming.extractions, ext_idx)

  #   %ExtractionDiff{
  #     idx: ext_idx,
  #     key: next_ext.key,
  #     delta: Delta.diff(current_ext.delta, next_ext.delta)
  #   }
  # end

  # def diff(%__MODULE__{} = streaming, %__MODULE__{} = next_streaming) do
  #   dbg({streaming, next_streaming, Delta.diff(streaming.delta, next_streaming.delta)})

  #   %StreamingDiff{
  #     delta: Delta.diff(streaming.delta, next_streaming.delta),
  #     new_cited_source_ids: next_streaming.cited_source_ids -- streaming.cited_source_ids,
  #     new_follow_up_questions: next_streaming.follow_up_questions -- streaming.follow_up_questions
  #   }
  # end
end
