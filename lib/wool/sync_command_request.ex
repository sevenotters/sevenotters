defmodule Seven.SyncCommandRequest do
  @moduledoc false

  defstruct request_id: nil,
            command: nil,
            state: :unmanaged,
            params: nil,
            wait_for_events: [],
            events: [],
            response: nil
end
