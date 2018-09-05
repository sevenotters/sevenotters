defmodule Seven.CommandRequest do
  @moduledoc false

  defstruct id: nil,
            command: nil,
            sender: nil,
            params: nil
end
