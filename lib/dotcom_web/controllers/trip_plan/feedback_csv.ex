defmodule DotcomWeb.TripPlan.FeedbackCSV do
  @moduledoc """
  Handle formatting feedback into a spreadsheet-friendly format.
  """

  require Logger

  alias OpenTripPlannerClient.Schema.Step

  @headers [
    "generated_time",
    "itinerary_index",
    "feedback_vote",
    "feedback_long",
    "mode_subway",
    "mode_commuter_rail",
    "mode_bus",
    "mode_ferry",
    "query_wheelchair",
    "query_time_type",
    "query_date_time",
    "query_from",
    "query_to",
    "itinerary_0_accessible",
    "itinerary_0_tag",
    "itinerary_0_start_stop",
    "itinerary_0_legs",
    "itinerary_1_accessible",
    "itinerary_1_tag",
    "itinerary_1_start_stop",
    "itinerary_1_legs",
    "itinerary_2_accessible",
    "itinerary_2_tag",
    "itinerary_2_start_stop",
    "itinerary_2_legs",
    "itinerary_3_accessible",
    "itinerary_3_tag",
    "itinerary_3_start_stop",
    "itinerary_3_legs",
    "itinerary_4_accessible",
    "itinerary_4_tag",
    "itinerary_4_start_stop",
    "itinerary_4_legs"
  ]

  def rows(data) do
    data
    |> Enum.map(&format_all/1)
    |> CSV.encode(headers: @headers)
    |> Enum.to_list()
  end

  def format_all(data) do
    data_map =
      data
      |> Enum.reduce(%{}, fn
        {key, value}, acc when key in ["feedback_vote", "feedback_long", "itinerary_index"] ->
          Map.put(acc, key, value)

        {"generated_time", time_string}, acc ->
          Map.put(acc, "generated_time", format_time(time_string))

        {"modes", modes}, acc ->
          modes = Enum.map(modes, fn {k, v} -> {"mode_#{k}", v} end) |> Enum.into(%{})
          Map.merge(acc, modes)

        {"query",
         %{
           "from" => from,
           "to" => to,
           "date_time" => date_time,
           "time_type" => time_type,
           "wheelchair" => wheelchair,
           "itineraries" => itineraries
         }},
        acc ->
          acc
          |> Map.merge(%{
            "query_from" => place_description(from),
            "query_to" => place_description(to),
            "query_date_time" => format_time(date_time),
            "query_time_type" => time_type,
            "query_wheelchair" => wheelchair
          })
          |> Map.merge(mapped_itineraries(itineraries))

        _, acc ->
          acc
      end)

    # sometimes fields are empty or not populated, so seed them here
    @headers
    |> Enum.map(&{&1, ""})
    |> Map.new()
    |> Map.merge(data_map)
  end

  defp place_description(%{"name" => name, "stop_id" => stop_id}) when not is_nil(stop_id),
    do: name <> " (id: #{stop_id})"

  defp place_description(%{"name" => name, "latitude" => lat, "longitude" => lon}),
    do: "#{name} (#{lat}, #{lon})"

  defp format_time(t) do
    with {:ok, dt} <- Timex.parse(t, "{ISO:Extended}"),
         {:ok, formatted} <- Timex.format(dt, "{ISOdate} {kitchen}") do
      formatted
    end
  end

  defp mapped_itineraries(itineraries) do
    itineraries
    |> Enum.with_index()
    |> Enum.map(fn {%{
                      "tag" => tag,
                      "accessible?" => accessible,
                      "stop" => stop,
                      "start" => start,
                      "legs" => legs
                    }, index} ->
      prefix = "itinerary_#{index}_"

      %{
        (prefix <> "tag") => tag,
        (prefix <> "accessible") => accessible,
        (prefix <> "start_stop") => "#{format_time(start)}, #{format_time(stop)}",
        (prefix <> "legs") => Enum.map_join(legs, ";\n", &mapped_leg/1)
      }
    end)
    |> Enum.reduce(&Map.merge/2)
  end

  defp mapped_leg(%{"from" => from, "to" => to, "mode" => mode}) do
    "#{place_description(from)} to #{place_description(to)} via #{mode_description(mode)}"
  end

  defp mode_description(%{"route" => %{"id" => route_id}, "trip_id" => trip_id}),
    do: route_id <> " route on trip " <> trip_id

  defp mode_description(%{"steps" => steps, "distance" => distance}) do
    step_description =
      steps
      |> Enum.map(fn step ->
        # since this is happening after data serialization, re-create the atom
        # keys so that Nestru can re-decode it and compute the appropriate text
        # via Step.walk_summary/1
        Enum.map(step, fn {k, v} ->
          {String.to_atom(k), v}
        end)
        |> Enum.into(%{})
      end)
      |> Nestru.decode_from_list!(Step)
      |> Enum.map_join(";\n\t", &Step.walk_summary/1)

    "walking #{distance} meters:\n\t#{step_description}"
  end

  defp mode_description(mode) do
    trip_id = Map.get(mode, "trip_id")
    type = Map.get(mode, "mode")

    Logger.error("#{__MODULE__} error=unknown_mode trip_id=#{trip_id} type=#{type}")

    "unknown"
  end
end
