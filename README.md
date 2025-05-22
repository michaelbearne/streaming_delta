# StreamingDelta

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `markdown_to_delta` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:streaming_delta, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/markdown_to_delta>.


# Todo

- Add finished option to close the buffer and concat on to raw
- Handle white space stars in list that canceled out by white space .eg. 1. * Not italic 
- Links in square brackets
- TODO stripe white space on neasted lists
- TODO stripe white space on orderd list between list and number