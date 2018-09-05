defmodule Seven.Projections do
  @moduledoc false

  @spec get_projection(String.t()) :: {:ok, module} | {:error, :not_found}
  def get_projection(projection_name) do
    case Seven.Entities.projections()[String.to_atom(projection_name)] do
      nil -> {:error, :projection_not_found}
      module -> {:ok, module}
    end
  end
end
