defmodule Seven.Data.Persistence do
  @moduledoc false

  alias Seven.Log

  @spec current() :: atom
  def current do
    Log.info("Using persistence: #{persistence()}")
    persistence()
  end

  @spec initialize(String.t()) :: any
  def initialize(collection), do: persistence().initialize(collection)

  @spec insert(String.t(), Map.t()) :: any
  def insert(collection, %{__struct__: _} = value),
    do: persistence().insert(collection, value |> Map.from_struct())

  @spec new_id :: Map.t()
  def new_id, do: persistence().new_id()

  @spec printable_id(any) :: String.t()
  def printable_id(nil), do: ""
  def printable_id(id), do: persistence().printable_id(id)

  @spec object_id(String.t()) :: any
  def object_id(id), do: persistence().object_id(id)

  @spec max_in_collection(String.t(), atom) :: Int.t()
  def max_in_collection(collection, field), do: persistence().max_in_collection(collection, field)

  @spec content_by_correlation_id(String.t(), String.t(), any) :: List.t()
  def content_by_correlation_id(collection, correlation_id, sort),
    do: persistence().content_by_correlation_id(collection, correlation_id, sort)

  @spec content_by_types(String.t(), [String.t()], any) :: List.t()
  def content_by_types(collection, types, sort),
    do: persistence().content_by_types(collection, types, sort)

  @spec content(String.t()) :: List.t()
  def content(collection), do: persistence().content(collection)

  @spec drop_collections(List.t()) :: any
  def drop_collections(collections), do: persistence().drop_collections(collections)

  @spec is_valid_id?(any) :: Boolean.t()
  def is_valid_id?(id), do: persistence().is_valid_id?(id)

  @spec sort_expression() :: atom()
  def sort_expression(), do: persistence().sort_expression()

  defp persistence, do: Application.get_env(:seven, :persistence) || Seven.Data.InMemory
end
