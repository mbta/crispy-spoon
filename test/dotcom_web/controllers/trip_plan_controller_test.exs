defmodule DotcomWeb.TripPlanControllerTest do
  use DotcomWeb.ConnCase, async: true

  import Mox
  import Test.Support.Factories.LocationService.LocationService

  alias Dotcom.TripPlan.{Itinerary, PersonalDetail, Query, TransitDetail}
  alias Fares.Fare

  doctest DotcomWeb.TripPlanController

  @system_time "2017-01-01T12:20:00-05:00"
  @morning %{
    "year" => "2017",
    "month" => "1",
    "day" => "2",
    "hour" => "9",
    "minute" => "30",
    "am_pm" => "AM"
  }
  @afternoon %{
    "year" => "2017",
    "month" => "1",
    "day" => "2",
    "hour" => "5",
    "minute" => "30",
    "am_pm" => "PM"
  }
  @after_hours %{
    "year" => "2017",
    "month" => "1",
    "day" => "2",
    "hour" => "3",
    "minute" => "00",
    "am_pm" => "AM"
  }
  @modes %{"subway" => "true", "commuter_rail" => "true", "bus" => "false", "ferry" => "false"}

  @good_params %{
    "date_time" => @system_time,
    "plan" => %{
      "from" => "from address",
      "to" => "to address",
      "date_time" => @afternoon,
      "time" => "depart",
      "modes" => @modes,
      "wheelchair" => "true"
    }
  }

  @bad_params %{
    "date_time" => @system_time,
    "plan" => %{"from" => "no results", "to" => "too many results", "date_time" => @afternoon}
  }

  setup :verify_on_exit!

  setup do
    stub(MBTA.Api.Mock, :get_json, fn "/schedules/", [route: "Red", date: "1970-01-01"] ->
      {:error,
       [
         %JsonApi.Error{
           code: "no_service",
           source: %{
             "parameter" => "date"
           },
           detail: "The current rating does not describe service on that date.",
           meta: %{
             "end_date" => "2024-06-15",
             "start_date" => "2024-05-10",
             "version" => "Spring 2024, 2024-05-17T21:10:15+00:00, version D"
           }
         }
       ]}
    end)

    stub(OpenTripPlannerClient.Mock, :plan, fn _from, _to, _opts ->
      {:ok, %OpenTripPlannerClient.Plan{itineraries: []}}
    end)

    stub(LocationService.Mock, :geocode, fn name ->
      {:ok, build_list(2, :address, %{formatted: name})}
    end)

    stub(Stops.Repo.Mock, :get_parent, fn _ ->
      %Stops.Stop{}
    end)

    cache = Application.get_env(:dotcom, :cache)
    cache.flush()

    conn = default_conn()

    end_of_rating =
      @system_time
      |> Timex.parse!("{ISO:Extended}")
      |> Timex.shift(months: 3)
      |> DateTime.to_date()

    {:ok, conn: assign(conn, :end_of_rating, end_of_rating)}
  end

  describe "index without params" do
    test "renders index.html", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index))
      assert html_response(conn, 200) =~ "Trip Planner"
    end

    test "assigns initial map data", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index))
      assert conn.assigns.map_data
    end

    test "sets a custom meta description", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index))
      assert conn.assigns.meta_description
    end
  end

  describe "index with params" do
    test "renders the query plan", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @good_params))
      response = html_response(conn, 200)
      assert response =~ "Trip Planner"
      assert %Query{} = conn.assigns.query
      assert conn.assigns.itineraries
      assert conn.assigns.routes
      assert conn.assigns.itinerary_maps
      assert conn.assigns.related_links
    end

    test "uses current location to render a query plan", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "Your current location",
          "from_latitude" => "42.3428",
          "from_longitude" => "-71.0857",
          "to" => "to address",
          "to_latitude" => "",
          "to_longitude" => "",
          "date_time" => @morning,
          "modes" => @modes
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))

      assert html_response(conn, 200) =~ "Trip Planner"
      assert %Query{} = conn.assigns.query
    end

    test "sets hidden inputs for lat/lng", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "from_latitude" => "1",
          "from_longitude" => "2",
          "to" => "to address",
          "to_latitude" => "3",
          "to_longitude" => "4",
          "date_time" => @morning,
          "modes" => @modes
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))

      resp = html_response(conn, 200)
      assert from_latitude = Floki.find(resp, "#from_latitude")
      assert from_longitude = Floki.find(resp, "#from_longitude")
      assert to_latitude = Floki.find(resp, "#to_latitude")
      assert to_longitude = Floki.find(resp, "#to_longitude")
      assert List.first(Floki.attribute(from_latitude, "value")) == "1.0"
      assert List.first(Floki.attribute(from_longitude, "value")) == "2.0"
      assert List.first(Floki.attribute(to_latitude, "value")) == "3.0"
      assert List.first(Floki.attribute(to_longitude, "value")) == "4.0"
    end

    test "assigns.mode is a map of parsed mode state", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "Your current location",
          "from_latitude" => "42.3428",
          "from_longitude" => "-71.0857",
          "to" => "to address",
          "to_latitude" => "",
          "to_longitude" => "",
          "date_time" => @morning,
          "modes" => @modes
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))

      assert html_response(conn, 200) =~ "Trip Planner"
      assert conn.assigns.modes == %{subway: true, commuter_rail: true, bus: false, ferry: false}
      assert %Query{} = conn.assigns.query
    end

    test "assigns.wheelchair uses value provided in params", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "Your current location",
          "from_latitude" => "42.3428",
          "from_longitude" => "-71.0857",
          "to" => "to address",
          "to_latitude" => "",
          "to_longitude" => "",
          "date_time" => @morning,
          "modes" => @modes,
          "wheelchair" => "true"
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))

      assert html_response(conn, 200) =~ "Trip Planner"
      assert conn.assigns.wheelchair == true
    end

    test "can use the old date time format", %{conn: conn} do
      old_dt_format = Map.delete(@afternoon, "am_pm")

      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from_address",
          "from_latitude" => "",
          "from_longitude" => "",
          "to" => "to address",
          "to_latitude" => "",
          "to_longitude" => "",
          "date_time" => old_dt_format,
          "mode" => @modes
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert html_response(conn, 200)
    end

    test "each map url has a path color", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @good_params))

      for {map_data, static_map} <- conn.assigns.itinerary_maps do
        assert static_map =~ "color"

        for path <- map_data.polylines do
          assert path.color
        end
      end
    end

    test "renders a geocoding error", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @bad_params))
      response = html_response(conn, 200)
      assert response =~ "Trip Planner"
      # shows error styling on location input with "required" label
      assert response =~ "(Required)"
      assert %Query{} = conn.assigns.query
    end

    test "assigns maps for each itinerary", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @good_params))
      assert conn.assigns.itinerary_maps
    end

    test "gets routes from each itinerary", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @good_params))
      assert conn.assigns.routes

      for routes_for_itinerary <- conn.assigns.routes do
        assert length(routes_for_itinerary) > 0
      end
    end

    test "assigns an ItineraryRowList for each itinerary", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @good_params))
      assert conn.assigns.itinerary_row_lists
    end

    test "adds fare data to each transit leg of each itinerary", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @good_params))

      assert Enum.all?(conn.assigns.itineraries, fn itinerary ->
               Enum.all?(itinerary.legs, fn leg ->
                 match?(%PersonalDetail{}, leg.mode) ||
                   match?(
                     %TransitDetail{
                       fares: %{
                         highest_one_way_fare: %Fares.Fare{},
                         lowest_one_way_fare: %Fares.Fare{},
                         reduced_one_way_fare: %Fares.Fare{}
                       }
                     },
                     leg.mode
                   )
               end)
             end)
    end

    test "returns all nil fares when there is not enough information", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @good_params))

      for itinerary <- conn.assigns.itineraries do
        for leg <- itinerary.legs do
          if Dotcom.TripPlan.Leg.transit?(leg) do
            assert leg.mode.fares == %{
                     highest_one_way_fare: nil,
                     lowest_one_way_fare: nil,
                     reduced_one_way_fare: nil
                   }
          end
        end
      end
    end

    test "adds monthly pass data to each itinerary", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :index, @good_params))

      assert Enum.all?(conn.assigns.itineraries, fn itinerary ->
               %Itinerary{passes: %{base_month_pass: %Fare{}, recommended_month_pass: %Fare{}}} =
                 itinerary
             end)
    end

    test "renders an error if longitude and latitude from both addresses are the same", %{
      conn: conn
    } do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from_latitude" => "90",
          "to_latitude" => "90",
          "from_longitude" => "50",
          "to_longitude" => "50",
          "date_time" => @afternoon,
          "from" => "from St",
          "to" => "from Street"
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert conn.assigns.plan_error == [:same_address]
      assert html_response(conn, 200)
      assert html_response(conn, 200) =~ "two different locations"
    end

    test "doesn't render an error if longitudes and latitudes are unique", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from_latitude" => "90",
          "to_latitude" => "90.5",
          "from_longitude" => "50.5",
          "to_longitude" => "50",
          "date_time" => @afternoon,
          "from" => "from St",
          "to" => "from Street"
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert conn.assigns.plan_error == []
      assert html_response(conn, 200)
    end

    test "renders an error if to and from address are the same", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from",
          "to" => "from",
          "date_time" => @afternoon
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert conn.assigns.plan_error == [:same_address]
      assert html_response(conn, 200)
      assert html_response(conn, 200) =~ "two different locations"
    end

    test "doesn't render an error if to and from address are unique", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from",
          "to" => "to",
          "date_time" => @afternoon
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert conn.assigns.plan_error == []
      assert html_response(conn, 200)
    end

    test "handles empty lat/lng", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from",
          "to" => "from",
          "to_latitude" => "",
          "to_longitude" => "",
          "from_latitude" => "",
          "from_longitude" => "",
          "date_time" => @afternoon
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert conn.assigns.plan_error == [:same_address]
      assert html_response(conn, 200)
      assert html_response(conn, 200) =~ "two different locations"
    end

    test "bad date input: fictional day", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "to" => "to address",
          "date_time" => %{@morning | "month" => "6", "day" => "31"}
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      response = html_response(conn, 200)
      assert response =~ "Date is not valid"
    end

    test "bad date input: partial input", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "to" => "to address",
          "date_time" => %{@morning | "month" => ""}
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      response = html_response(conn, 200)
      assert response =~ "Date is not valid"
    end

    test "bad date input: corrupt day", %{conn: conn} do
      date_input = %{
        "year" => "A",
        "month" => "B",
        "day" => "C",
        "hour" => "D",
        "minute" => "E",
        "am_pm" => "PM"
      }

      params = %{
        "date_time" => @system_time,
        "plan" => %{"from" => "from address", "to" => "to address", "date_time" => date_input}
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      response = html_response(conn, 200)
      assert response =~ "Date is not valid"
    end

    test "bad date input: too far in future", %{conn: conn} do
      end_date = Timex.shift(Schedules.Repo.end_of_rating(), days: 1)

      end_date_as_params = %{
        "month" => Integer.to_string(end_date.month),
        "day" => Integer.to_string(end_date.day),
        "year" => Integer.to_string(end_date.year),
        "hour" => "12",
        "minute" => "15",
        "am_pm" => "PM"
      }

      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "to" => "to address",
          "date_time" => end_date_as_params,
          "time" => "depart"
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      response = html_response(conn, 200)
      assert Map.get(conn.assigns, :plan_error) == [:too_future]
      assert response =~ "Date is too far in the future"

      expected =
        [:too_future]
        |> DotcomWeb.TripPlanView.plan_error_description()
        |> IO.iodata_to_binary()

      assert response =~ expected
    end

    test "bad date input: date in past", %{conn: conn} do
      past_date =
        @system_time
        |> Timex.parse!("{ISO:Extended}")
        |> Timex.shift(days: -10)

      past_date_as_params = %{
        "month" => Integer.to_string(past_date.month),
        "day" => Integer.to_string(past_date.day),
        "year" => Integer.to_string(past_date.year),
        "hour" => "12",
        "minute" => "15",
        "am_pm" => "PM"
      }

      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "to" => "to address",
          "date_time" => past_date_as_params,
          "time" => "depart"
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      response = html_response(conn, 200)
      assert Map.get(conn.assigns, :plan_error) == [:past]
      assert response =~ "Date is in the past"
    end

    test "handles missing date and time params, using today's values if they are missing",
         %{conn: conn} do
      wrong_datetime_params = %{
        "year" => "2017",
        "day" => "2",
        "hour" => "9",
        "am_pm" => "AM"
      }

      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "to" => "to address",
          "date_time" => wrong_datetime_params
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert html_response(conn, 200)
    end

    test "handles non-existing date and time params, using today's values",
         %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "to" => "to address",
          "date_time" => %{}
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert html_response(conn, 200)
    end

    test "does not need to default date and time params as they are present",
         %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "to" => "to address",
          "date_time" => @morning
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      assert html_response(conn, 200)
    end

    test "good date input: date within service date of end of rating", %{conn: conn} do
      # after midnight but before end of service on last day of rating
      # should still be inside of the rating

      date = Timex.shift(conn.assigns.end_of_rating, days: 1)

      date_params = %{
        "month" => Integer.to_string(date.month),
        "day" => Integer.to_string(date.day),
        "year" => Integer.to_string(date.year),
        "hour" => "12",
        "minute" => "15",
        "am_pm" => "AM"
      }

      params = %{
        "date_time" => @system_time,
        "plan" => %{"from" => "from address", "to" => "to address", "date_time" => date_params}
      }

      conn = get(conn, trip_plan_path(conn, :index, params))

      response = html_response(conn, 200)
      assert Map.get(conn.assigns, :plan_error) == []
      refute response =~ "Date is too far in the future"
      refute response =~ "Date is not valid"
    end

    test "hour and minute are processed correctly when provided as single digits", %{conn: conn} do
      params = %{
        "date_time" => @system_time,
        "plan" => %{
          "from" => "from address",
          "to" => "to address",
          "date_time" => %{@after_hours | "hour" => "1", "minute" => "1"},
          "time" => "depart"
        }
      }

      conn = get(conn, trip_plan_path(conn, :index, params))
      response = html_response(conn, 200)
      assert Map.get(conn.assigns, :plan_error) == []
      refute response =~ "Date is not valid"
    end
  end

  describe "/from/ address path" do
    test "gets a valid address in the 'from' field", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :from, "Boston Common"))

      assert conn.assigns.query.from.name == "Boston Common"
    end

    test "uses expected values when addres is formatted latitutde,longitude,stopName", %{
      conn: conn
    } do
      conn = get(conn, trip_plan_path(conn, :from, "42.395428,-71.142483,Cobbs Corner, Canton"))

      assert html_response(conn, 200)
      assert conn.assigns.query.from.name == "Cobbs Corner, Canton"
      assert conn.assigns.query.from.latitude == 42.395428
      assert conn.assigns.query.from.longitude == -71.142483
    end

    test "is unable to get address so it redirects to index", %{conn: conn} do
      expect(LocationService.Mock, :geocode, fn _ ->
        {:error, :something}
      end)

      conn = get(conn, trip_plan_path(conn, :from, "Atlantis"))
      assert html_response(conn, 302) =~ "/trip-planner"
    end

    test "when 'plan' is part of the parameters, it redirects to the usual trip planner", %{
      conn: conn
    } do
      plan_params = %{"plan" => %{"from" => "from address", "to" => "to address"}}

      conn =
        get(
          conn,
          trip_plan_path(conn, :from, "Address", plan_params)
        )

      assert redirected_to(conn) == trip_plan_path(conn, :index, plan_params)
    end
  end

  describe "/to/ address path" do
    test "gets a valid address in the 'to' field", %{conn: conn} do
      conn = get(conn, trip_plan_path(conn, :to, "Boston Common"))
      assert conn.assigns.query.to.name == "Boston Common"
    end

    test "uses expected values when address is formatted latitutde,longitude,stopName", %{
      conn: conn
    } do
      conn = get(conn, trip_plan_path(conn, :to, "42.395428,-71.142483,Cobbs Corner, Canton"))

      assert html_response(conn, 200)
      assert conn.assigns.query.to.name == "Cobbs Corner, Canton"
      assert conn.assigns.query.to.latitude == 42.395428
      assert conn.assigns.query.to.longitude == -71.142483
    end

    test "is unable to get address so it redirects to index", %{conn: conn} do
      expect(LocationService.Mock, :geocode, fn _ ->
        {:error, :something}
      end)

      conn = get(conn, trip_plan_path(conn, :to, "Atlantis"))
      assert html_response(conn, 302) =~ "/trip-planner"
    end

    test "when 'plan' is part of the parameters, it redirects to the usual trip planner", %{
      conn: conn
    } do
      plan_params = %{"plan" => %{"from" => "from address", "to" => "to address"}}

      conn =
        get(
          conn,
          trip_plan_path(conn, :to, "Address", plan_params)
        )

      assert redirected_to(conn) == trip_plan_path(conn, :index, plan_params)
    end
  end
end
