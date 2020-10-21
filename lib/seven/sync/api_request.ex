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
            query: nil,
            timeout: 5_000

  defdelegate fetch(term, key), to: Map
  defdelegate get(term, key, default), to: Map
  defdelegate get_and_update(term, key, fun), to: Map
end
