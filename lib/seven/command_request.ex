defmodule Seven.CommandRequest do
  @moduledoc false

  defstruct id: nil,
            process_id: nil,
            command: nil,
            sender: nil,
            params: nil
end
