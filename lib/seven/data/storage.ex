defmodule Seven.Data.Storage do
  @callback insert(String.t(), Map.t()) :: {:ok, any}
  @callback new_id :: Map.t()
  @callback printable_id(any) :: String.t()
  @callback object_id(String.t()) :: any
  @callback is_valid_id?(any) :: Boolean.t()
  @callback max_in_collection(String.t(), atom) :: Int.t()
  @callback content_of(String.t(), Map.t(), Map.t()) :: List.t()
  @callback drop_collections(List.t()) :: any
end
