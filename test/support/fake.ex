defmodule StreamingDelta.Fake do
  def id, do: Ecto.ULID.generate()
end
