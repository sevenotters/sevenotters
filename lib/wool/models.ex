defmodule Seven.Models do
  @moduledoc false

  @spec get_model(String.t()) :: {:ok, module} | {:error, :not_found}
  def get_model(model_name) do
    case Seven.Entities.models()[String.to_atom(model_name)] do
      nil -> {:error, :not_found}
      module -> {:ok, module}
    end
  end
end
