defmodule StreamingDelta.StreamingTest do
  use ExUnit.Case

  alias Delta.Op

  alias StreamingDelta.Streaming
  alias StreamingDelta.Streaming.{DeltaDiff, Extraction, ExtractionDiff}

  describe "diffs/2" do
    test "the same" do
      current = %Streaming{delta: [Op.insert("abc")]}
      next = %Streaming{delta: [Op.insert("abc")]}

      assert Streaming.diffs(current, next) == []
    end

    test "simple delta change" do
      current = %Streaming{delta: [Op.insert("abc")]}
      next = %Streaming{delta: [Op.insert("abcefg")]}

      assert [
               %Streaming.DeltaDiff{
                 delta: [%{"retain" => 3}, %{"insert" => "efg"}],
                 new_cited_source_ids: [],
                 new_follow_up_questions: []
               }
             ] =
               Streaming.diffs(current, next)
    end

    test "delta change with extraction start" do
      current = %Streaming{delta: [Op.insert("abc")]}

      next = %Streaming{
        delta: [Op.insert("abcefg")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1")]}}
      }

      assert [
               %DeltaDiff{
                 delta: [%{"retain" => 3}, %{"insert" => "efg"}],
                 new_cited_source_ids: [],
                 new_follow_up_questions: []
               },
               %ExtractionDiff{
                 idx: 1,
                 key: "KEY",
                 delta: [%{"insert" => "Ext 1"}]
               }
             ] =
               Streaming.diffs(current, next)
    end

    test "extraction change" do
      current = %Streaming{
        delta: [Op.insert("abc")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1")]}}
      }

      next = %Streaming{
        delta: [Op.insert("abc")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1 change")]}}
      }

      assert [
               %ExtractionDiff{
                 idx: 1,
                 key: "KEY",
                 delta: [%{"retain" => 5}, %{"insert" => " change"}]
               }
             ] =
               Streaming.diffs(current, next)
    end

    test "delta change and extraction change" do
      current = %Streaming{
        delta: [Op.insert("abc")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1")]}}
      }

      next = %Streaming{
        delta: [Op.insert("abc change")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1 change")]}}
      }

      assert [
               %DeltaDiff{
                 delta: [%{"retain" => 3}, %{"insert" => " change"}],
                 new_cited_source_ids: [],
                 new_follow_up_questions: []
               },
               %ExtractionDiff{
                 idx: 1,
                 key: "KEY",
                 delta: [%{"retain" => 5}, %{"insert" => " change"}]
               }
             ] =
               Streaming.diffs(current, next)
    end

    test "new extraction" do
      current = %Streaming{
        delta: [Op.insert("abc")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1")]}}
      }

      next = %Streaming{
        delta: [Op.insert("abc")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{
          1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1")]},
          2 => %Extraction{id: 2, key: "KEY", delta: [Op.insert("Ext 2")]}
        }
      }

      assert [
               %ExtractionDiff{
                 idx: 2,
                 key: "KEY",
                 delta: [%{"insert" => "Ext 2"}]
               }
             ] =
               Streaming.diffs(current, next)
    end

    test "new extraction with delta change" do
      current = %Streaming{
        delta: [Op.insert("abc")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1")]}}
      }

      next = %Streaming{
        delta: [Op.insert("abc change")],
        extraction_keys: ["KEY"],
        active_extraction: 1,
        extractions: %{
          1 => %Extraction{id: 1, key: "KEY", delta: [Op.insert("Ext 1")]},
          2 => %Extraction{id: 2, key: "KEY", delta: [Op.insert("Ext 2")]}
        }
      }

      assert [
               %Streaming.DeltaDiff{
                 delta: [%{"retain" => 3}, %{"insert" => " change"}],
                 new_cited_source_ids: [],
                 new_follow_up_questions: []
               },
               %Streaming.ExtractionDiff{
                 idx: 2,
                 key: "KEY",
                 delta: [%{"insert" => "Ext 2"}]
               }
             ] =
               Streaming.diffs(current, next)
    end
  end
end
