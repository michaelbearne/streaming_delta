defmodule StreamingDelta.Fake do
  def id, do: Enum.random(1..9_999_999)
end
