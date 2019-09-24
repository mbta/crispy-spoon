defmodule Leaflet.MapData do
  @moduledoc """
  Represents leaflet map data.
  """
  alias GoogleMaps.MapData, as: GoogleMapData
  alias GoogleMaps.MapData.Marker, as: GoogleMapsMarker
  alias GoogleMaps.MapData.Path, as: GoogleMapsPath

  alias Leaflet.MapData.{
    Marker,
    Polyline
  }

  @type lat_lng :: %{latitude: float, longitude: float}

  defstruct default_center: %{latitude: 42.360718, longitude: -71.05891},
            height: 0,
            markers: [],
            stop_markers: [],
            polylines: [],
            tile_server_url: "",
            width: 0,
            zoom: nil,
            id: ""

  @type t :: %__MODULE__{
          default_center: lat_lng,
          height: integer,
          markers: [Marker.t()],
          stop_markers: [Marker.t()],
          polylines: [Polyline.t()],
          tile_server_url: String.t(),
          width: integer,
          zoom: integer | nil,
          id: String.t()
        }

  @spec new({integer, integer}, integer | nil) :: t
  def new({width, height}, zoom \\ nil) do
    %__MODULE__{
      width: width,
      height: height,
      zoom: zoom
    }
  end

  @spec add_marker(t, Marker.t()) :: t
  def add_marker(map_data, marker) do
    %{map_data | markers: [marker | map_data.markers]}
  end

  @spec add_stop_marker(t, Marker.t()) :: t
  def add_stop_marker(map_data, marker) do
    %{map_data | stop_markers: [marker | map_data.stop_markers]}
  end

  @spec add_markers(t, [Marker.t()]) :: t
  def add_markers(map_data, markers) do
    Enum.reduce(markers, map_data, &add_marker(&2, &1))
  end

  @spec add_stop_markers(t, [Marker.t()]) :: t
  def add_stop_markers(map_data, markers) do
    Enum.reduce(markers, map_data, &add_stop_marker(&2, &1))
  end

  @spec add_polyline(t, Polyline.t()) :: t
  def add_polyline(map_data, %Polyline{} = polyline) do
    %{map_data | polylines: [polyline | map_data.polylines]}
  end

  @spec add_polylines(t, [Polyline.t()]) :: t
  def add_polylines(map_data, polylines) do
    Enum.reduce(polylines, map_data, &add_polyline(&2, &1))
  end

  def to_google_map_data(%{
        default_center: default_center,
        width: width,
        height: height,
        zoom: zoom,
        markers: markers,
        polylines: polylines
      }) do
    %GoogleMapData{
      default_center: default_center,
      width: width,
      height: height,
      zoom: zoom,
      scale: 2,
      markers:
        Enum.map(markers, fn %{latitude: latitude, longitude: longitude} ->
          %GoogleMapsMarker{
            longitude: longitude,
            latitude: latitude,
            visible?: false
          }
        end),
      paths:
        Enum.map(polylines, fn %{color: color, weight: weight, dotted?: dotted?} ->
          %GoogleMapsPath{
            color: color,
            weight: weight,
            dotted?: dotted?
          }
        end)
    }
  end
end
