defmodule Seven.Data.Persistence do
  @persistence Seven.Data.Storage.Mongo

  @moduledoc false

  @spec current() :: atom
  def current, do: @persistence

  @spec insert(String.t(), Map.t()) :: any
  def insert(collection, %{__struct__: _} = value),
    do: @persistence.insert(collection, value |> Map.from_struct())

  @spec new_id :: Map.t()
  def new_id, do: @persistence.new_id()

  @spec printable_id(any) :: String.t()
  def printable_id(nil), do: ""
  def printable_id(id), do: @persistence.printable_id(id)

  @spec object_id(String.t()) :: map
  def object_id(id), do: @persistence.object_id(id)

  @spec max_in_collection(String.t(), atom) :: Int.t()
  def max_in_collection(collection, field), do: @persistence.max_in_collection(collection, field)

  @spec content_of(String.t(), Map.t(), Map.t()) :: List.t()
  def content_of(collection, filter \\ %{}, sort \\ %{}),
    do: @persistence.content_of(collection, filter, sort)

  @spec drop_collections(List.t()) :: any
  def drop_collections(collections), do: @persistence.drop_collections(collections)

  @spec is_valid_id?(any) :: Boolean.t()
  def is_valid_id?(id), do: @persistence.is_valid_id?(id)
end
