defmodule Seven.Sync.ApiRequest do
  @moduledoc false

  defstruct request_id: nil,
            command: nil,
            projection: nil,
            state: nil,
            params: nil,
            wait_for_events: [],
            events: [],
            response: nil,
            query: nil
end
