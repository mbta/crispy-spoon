defmodule Fares.ProposedLocations do
  @moduledoc """
    Gets information from the existing ArcGIS data related to proposed sales locations, parses the json and returns it.
  """

  require Logger

  alias Fares.ProposedLocations.Location

  @base_url "https://services1.arcgis.com/ceiitspzDAHrdGO1/ArcGIS/rest/services/ProposedSalesNetworkSpringOutreach/FeatureServer/0/query?f=json&outFields=*&inSR=4326&outSR=4326&returnGeometry=true"

  @distance_in_miles 100

  @spec by_lat_lon(LocationService.Address.t()) :: [Location.t()] | nil
  def by_lat_lon(%{latitude: lat, longitude: lon}) do
    url =
      "#{@base_url}&where=1%3D1&geometry=#{lon}%2C+#{lat}&geometryType=esriGeometryPoint&distance=#{@distance_in_miles}&units=esriSRUnit_StatuteMile"

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
            Logger.warning("error decoding json -> original_request=#{url}")
            nil
        end

      {:error, _} ->
        Logger.warning("error in http request -> original_request=#{url}")
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

  @spec get_nearby(Util.Position.t()) :: [{Location.t(), float}]
  def get_nearby(position) do
    nearby_proposed_locations = by_lat_lon(position) || []
    # Return the 10 closest locations, sorted by distance
    nearby_proposed_locations
    |> Util.Distance.sort(position)
    # There are 1178 PSLs. Since we are rendering them as hidden and showing/hiding them based on the filter,
    # we should really narrow down how many we are passing
    |> Enum.slice(0, 50)
    |> Enum.map(fn loc ->
      lat_lon = {loc.latitude, loc.longitude}
      {loc, Util.Distance.haversine(lat_lon, position)}
    end)
  end
end
