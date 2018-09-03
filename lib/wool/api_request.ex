defmodule Seven.ApiRequest do
  @moduledoc false

  defstruct request_id: nil,
            command: nil,
            projection: nil,
            state: :unmanaged,
            req_headers: nil,
            params: nil,
            wait_for_events: [],
            events: [],
            response: nil,
            filter: nil,
            query: nil
end
