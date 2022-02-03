defmodule Fares.ProposedLocations do
  @moduledoc """
    Gets information from the existing ArcGIS data related to proposed sales locations, parses the json and returns it.
  """

  alias Fares.ProposedLocations.Location
  require Logger

  @base_url "https://services1.arcgis.com/ceiitspzDAHrdGO1/ArcGIS/rest/services/ProposedSalesNetworkSpringOutreach/FeatureServer/0/query?f=json&outFields=*&inSR=4326&outSR=4326&returnGeometry=true"

  @distance_in_miles 100

  @spec by_lat_lon(%LocationService.Geocode.Address{}) :: [Location.t()] | nil
  def by_lat_lon(%{latitude: lat, longitude: lon}) do
    url =
      "#{@base_url}&where=1%3D1&geometry=#{lon}%2C+#{lat}&geometryType=esriGeometryPoint&distance=#{
        @distance_in_miles
      }&units=esriSRUnit_StatuteMile"

    get_parsed_proposed_locations(url)
  end

  def by_lat_lon(_) do
    nil
  end

  @spec get_parsed_proposed_locations(String.t()) :: [Location.t()] | nil
  defp get_parsed_proposed_locations(url) do
    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body, headers: _headers}} ->
        case Poison.decode(body) do
          {:ok, json} ->
            Enum.map(json["features"], &parse_proposed_location(&1))

          {:error, _} ->
            Logger.warn("error decoding json -> original_request=#{url}")
            nil
        end

      {:error, _} ->
        Logger.warn("error in http request -> original_request=#{url}")
        nil
    end
  end

  @spec parse_proposed_location(map) :: Location.t()
  defp parse_proposed_location(json) do
    attributes = json["attributes"]
    routes = attributes["Routes"]

    list_of_routes =
      if routes == " " do
        []
      else
        String.split(routes, ", ", trim: true)
      end

    %Location{
      fid: attributes["FID"],
      stop_id: attributes["stop_id"],
      name: attributes["stop_name"],
      municipality: attributes["municipali"],
      line: attributes["Line"],
      retail_fvm: attributes["RetailFVM"],
      routes: list_of_routes,
      latitude: json["geometry"]["y"],
      longitude: json["geometry"]["x"]
    }
  end
end
