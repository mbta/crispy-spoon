defmodule TripPlan.NamedPosition do
  @moduledoc "Defines a position for a trip plan as a stop and/or lat/lon"

  defstruct name: "",
            stop_id: nil,
            latitude: nil,
            longitude: nil

  @type t :: %__MODULE__{
          name: String.t(),
          stop_id: Stops.Stop.id_t() | nil,
          latitude: float | nil,
          longitude: float | nil
        }

  defimpl Util.Position do
    def latitude(%{latitude: latitude}), do: latitude
    def longitude(%{longitude: longitude}), do: longitude
  end
end
