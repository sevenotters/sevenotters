# Remove all events
ExUnit.start()

defmodule Seven.TestHelper do
  @moduledoc false

  def unique_name, do: UUID.uuid4(:hex)
end
