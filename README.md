# StreamingDelta

Character-by-character (chunks) conversion of Markdown into a [Delta](https://quilljs.com/docs/delta). 
This is useful when streaming Markdown from an LLM response, as it allows just the delta changes to be sent to the browser.

# Parses

- Italic
- Bold
- Headings
- Unordered List
- Ordered list
- Source refs (Not official Markdown useful when you want an LLM to return citations from the context .eg. some text [1].)
- Follow up questions (Not official Markdown useful when you want to extract text that returned in brackets .eg. <<A follow up question?>>.)
- Extractions (Not official Markdown useful when you want to extract a section of text from the main text)

test/streaming_delta/parser_test.exs has many examples that can be used to understand the text formats you would want to provide to an LLM so the right formats our output.

StreamingDelta.parse_chunk is used to parse a chunk and StreamingDelta.Streaming struct is the accumulateur.
To parse a stream of updates you would pass the next chunk and the returnd StreamingDelta.Streaming struct from the previous chunk in a loop.

To get the difference between two chunks you can use StreamingDelta.Streaming.diffs by passing in the StreamingDelta.Streaming struct for the previous chunk and StreamingDelta.Streaming struct for the latest chunk.

## Installation

```elixir
def deps do
  [
    {:streaming_delta, "~> 0.1.0"}
  ]
end
```

# Todo

- Add finished option to close the buffer and concat on to raw
- Handle white space stars in list that canceled out by white space .eg. 1. * Not italic 
- Links in square brackets
- stripe white space on neasted lists
- stripe white space on orderd list between list and number
- Provied example LLM prompts for the propriety format