defmodule Dotcom.Components.Register do
  @moduledoc """
    Registers an @components attribute on a controller.
    Only used by style_guide_controller at the moment -- perhaps doesn't need to be its own module...
  """

  import Dotcom.Components.Helpers

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Dotcom.Components.Helpers
      Module.register_attribute(__MODULE__, :components, persist: true)

      @components unquote(build_component_list())
    end
  end

  @doc """
    Finds all folders within libdotcom/components, and returns a tuple {:section, [:component...]} for each
  """
  @spec build_component_list :: [{atom, [atom]}]
  def build_component_list do
    components_folder_path()
    |> File.ls!()
    |> Enum.filter(&File.dir?(Path.join(components_folder_path(), &1)))
    |> Enum.map(&{String.to_atom(&1), list_component_names(&1)})
  end

  @doc """
    Finds all folders within a section folder, and returns each folder's name as an atom
  """
  @spec list_component_names(String.t()) :: [atom]
  def list_component_names(section) do
    # path var needs to be defined here because it's used again in Enum.filter
    path = Path.join(components_folder_path(), section)

    path
    |> File.ls!()
    |> Enum.filter(&File.dir?(Path.join(path, &1)))
    |> Enum.map(&String.to_atom(&1))
  end
end
