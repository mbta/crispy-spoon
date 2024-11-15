defmodule OneWayTest do
  use ExUnit.Case, async: true

  import Fares.OneWay
  import Mox

  alias Routes.Route

  @default_filters [duration: :single_trip]

  setup :verify_on_exit!

  setup do
    stub(Routes.Repo.Mock, :get, fn id -> %Route{id: id} end)
    stub(Stops.Repo.Mock, :get, fn id -> %Stops.Stop{id: id} end)

    :ok
  end

  test "returns nil if no route is provided for all fare types" do
    refute recommended_fare(nil, nil, nil)
    refute base_fare(nil, nil, nil)
    refute reduced_fare(nil, nil, nil)
  end

  describe "subway" do
    @route %Route{type: 0}

    @subway_fares [
      %Fares.Fare{
        additional_valid_modes: [:bus],
        cents: 225,
        media: [:charlie_card],
        mode: :subway,
        name: :subway,
        reduced: nil
      },
      %Fares.Fare{
        additional_valid_modes: [:bus],
        cents: 275,
        media: [:charlie_ticket, :cash],
        mode: :subway,
        name: :subway,
        reduced: nil
      }
    ]

    test "returns the lowest and highest one-way trip fare that is not discounted" do
      fare_fn = fn @default_filters ++ [mode: :subway] ->
        @subway_fares
      end

      assert %Fares.Fare{cents: 225} = recommended_fare(@route, nil, nil, fare_fn)
      assert %Fares.Fare{cents: 275} = base_fare(@route, nil, nil, fare_fn)
    end

    test "returns the reduced fares for subway" do
      reduced_subway_fare = %Fares.Fare{
        additional_valid_modes: [],
        cents: 110,
        duration: :single_trip,
        media: [:senior_card],
        mode: :subway,
        name: :subway,
        price_label: nil,
        reduced: :senior_disabled
      }

      fare_fn = fn @default_filters ++ [mode: :subway] ->
        @subway_fares ++ [reduced_subway_fare]
      end

      assert reduced_subway_fare == reduced_fare(@route, nil, nil, fare_fn)
    end

    test "returns no reduced fare for subway" do
      fare_fn = fn @default_filters ++ [mode: :subway] ->
        @subway_fares
      end

      assert nil == reduced_fare(@route, nil, nil, fare_fn)
    end
  end

  describe "local bus" do
    @bus_fares [
      %Fares.Fare{
        additional_valid_modes: [],
        cents: 170,
        media: [:charlie_card],
        mode: :bus,
        name: :local_bus,
        reduced: nil
      },
      %Fares.Fare{
        additional_valid_modes: [],
        cents: 200,
        media: [:charlie_ticket, :cash],
        mode: :bus,
        name: :local_bus,
        reduced: nil
      },
      %Fares.Fare{
        additional_valid_modes: [],
        cents: 400,
        media: [:charlie_card],
        mode: :bus,
        name: :express_bus,
        reduced: nil
      },
      %Fares.Fare{
        additional_valid_modes: [],
        cents: 500,
        media: [:charlie_ticket, :cash],
        mode: :bus,
        name: :express_bus,
        reduced: nil
      }
    ]

    test "returns the lowest and highest one-way trip fare that is not discounted for the local bus" do
      local_route = %Route{type: 3, id: "1"}

      fare_fn = fn @default_filters ++ [name: :local_bus] ->
        Enum.filter(@bus_fares, &(&1.name == :local_bus))
      end

      assert %Fares.Fare{cents: 170} = recommended_fare(local_route, nil, nil, fare_fn)
      assert %Fares.Fare{cents: 200} = base_fare(local_route, nil, nil, fare_fn)
    end

    test "returns the lowest and highest one-way trip fare that is not discounted for the express bus" do
      express_route = %Route{type: 3, id: "170"}

      fare_fn = fn @default_filters ++ [name: :express_bus] ->
        Enum.filter(@bus_fares, &(&1.name == :express_bus))
      end

      assert %Fares.Fare{cents: 400} = recommended_fare(express_route, nil, nil, fare_fn)

      assert %Fares.Fare{cents: 500} = base_fare(express_route, nil, nil, fare_fn)
    end

    test "returns the lowest and highest subway fare for for SL1 route (id=741)" do
      sl1 = %Route{type: 3, id: "741"}

      fare_fn = fn @default_filters ++ [name: :subway] ->
        Enum.filter(@subway_fares, &(&1.name == :subway))
      end

      assert %Fares.Fare{cents: 225} = recommended_fare(sl1, nil, nil, fare_fn)
      assert %Fares.Fare{cents: 275} = base_fare(sl1, nil, nil, fare_fn)
    end

    test "returns the lowest and highest subway fare for for SL2 route (id=742)" do
      sl2 = %Route{type: 3, id: "742"}

      fare_fn = fn @default_filters ++ [name: :subway] ->
        Enum.filter(@subway_fares, &(&1.name == :subway))
      end

      assert %Fares.Fare{cents: 225} = recommended_fare(sl2, nil, nil, fare_fn)
      assert %Fares.Fare{cents: 275} = base_fare(sl2, nil, nil, fare_fn)
    end

    test "returns lowest and highest the subway fare for for SL3 route (id=743)" do
      sl3 = %Route{type: 3, id: "743"}

      fare_fn = fn @default_filters ++ [name: :subway] ->
        Enum.filter(@subway_fares, &(&1.name == :subway))
      end

      assert %Fares.Fare{cents: 225} = recommended_fare(sl3, nil, nil, fare_fn)
      assert %Fares.Fare{cents: 275} = base_fare(sl3, nil, nil, fare_fn)
    end

    test "returns the lowest and highest bus fare for for SL4 route (id=751)" do
      sl4 = %Route{type: 3, id: "751"}

      fare_fn = fn @default_filters ++ [name: :local_bus] ->
        Enum.filter(@bus_fares, &(&1.name == :local_bus))
      end

      assert %Fares.Fare{cents: 170} = recommended_fare(sl4, nil, nil, fare_fn)
      assert %Fares.Fare{cents: 200} = base_fare(sl4, nil, nil, fare_fn)
    end

    test "returns the reduced fares for local bus" do
      reduced_local_bus_fare = %Fares.Fare{
        additional_valid_modes: [],
        cents: 85,
        duration: :single_trip,
        media: [:senior_card],
        mode: :bus,
        name: :local_bus,
        price_label: nil,
        reduced: :senior_disabled
      }

      local_route = %Route{type: 3, id: "1"}

      fare_fn = fn @default_filters ++ [name: :local_bus] ->
        Enum.filter(@bus_fares ++ [reduced_local_bus_fare], &(&1.name == :local_bus))
      end

      assert reduced_local_bus_fare == reduced_fare(local_route, nil, nil, fare_fn)
    end
  end

  describe "commuter rail" do
    test "returns the lowest and highest one-way fare that is not discounted for a trip originating in Zone 1A" do
      route = %Route{type: 2}
      origin_id = Faker.Internet.slug()
      destination_id = Faker.Internet.slug()

      fare_fn = fn @default_filters ++ [name: {:zone, "7"}] ->
        [
          %Fares.Fare{
            additional_valid_modes: [],
            cents: 1050,
            media: [:commuter_ticket, :cash],
            mode: :commuter_rail,
            name: {:zone, "7"},
            reduced: nil
          }
        ]
      end

      Stops.Repo.Mock
      |> expect(:get, fn ^origin_id -> %Stops.Stop{zone: "1A"} end)
      |> expect(:get, fn ^destination_id -> %Stops.Stop{zone: "7"} end)

      assert %Fares.Fare{cents: 1050} =
               recommended_fare(route, origin_id, destination_id, fare_fn)

      Stops.Repo.Mock
      |> expect(:get, fn ^origin_id -> %Stops.Stop{zone: "1A"} end)
      |> expect(:get, fn ^destination_id -> %Stops.Stop{zone: "7"} end)

      assert %Fares.Fare{cents: 1050} = base_fare(route, origin_id, destination_id, fare_fn)
    end

    test "returns the lowest and highest one-way fare that is not discounted for a trip terminating in Zone 1A" do
      route = %Route{type: 2}
      origin_id = Faker.Internet.slug()
      destination_id = Faker.Internet.slug()

      fare_fn = fn @default_filters ++ [name: {:zone, "4"}] ->
        [
          %Fares.Fare{
            additional_valid_modes: [],
            cents: 825,
            media: [:commuter_ticket, :cash],
            mode: :commuter_rail,
            name: {:zone, "4"},
            reduced: nil
          }
        ]
      end

      Stops.Repo.Mock
      |> expect(:get, fn ^origin_id -> %Stops.Stop{zone: "4"} end)
      |> expect(:get, fn ^destination_id -> %Stops.Stop{zone: "1A"} end)

      assert %Fares.Fare{cents: 825} =
               recommended_fare(route, origin_id, destination_id, fare_fn)

      Stops.Repo.Mock
      |> expect(:get, fn ^origin_id -> %Stops.Stop{zone: "4"} end)
      |> expect(:get, fn ^destination_id -> %Stops.Stop{zone: "1A"} end)

      assert %Fares.Fare{cents: 825} = base_fare(route, origin_id, destination_id, fare_fn)
    end

    test "returns an interzone fare that is not discounted for a trip that does not originate/terminate in Zone 1A" do
      route = %Route{type: 2}
      origin_id = Faker.Internet.slug()
      destination_id = Faker.Internet.slug()

      fare_fn = fn @default_filters ++ [name: {:interzone, "4"}] ->
        [
          %Fares.Fare{
            additional_valid_modes: [],
            cents: 401,
            media: [:commuter_ticket, :cash],
            mode: :commuter_rail,
            name: {:interzone, "4"},
            reduced: nil
          }
        ]
      end

      Stops.Repo.Mock
      |> expect(:get, fn ^origin_id -> %Stops.Stop{zone: "4"} end)
      |> expect(:get, fn ^destination_id -> %Stops.Stop{zone: "7"} end)

      assert %Fares.Fare{cents: 401} =
               recommended_fare(route, origin_id, destination_id, fare_fn)

      Stops.Repo.Mock
      |> expect(:get, fn ^origin_id -> %Stops.Stop{zone: "4"} end)
      |> expect(:get, fn ^destination_id -> %Stops.Stop{zone: "7"} end)

      assert %Fares.Fare{cents: 401} = base_fare(route, origin_id, destination_id, fare_fn)
    end

    test "excludes weekend commuter rail rates" do
      route = %Route{type: 2}
      origin_id = Faker.Internet.slug()
      destination_id = Faker.Internet.slug()

      Stops.Repo.Mock
      |> expect(:get, fn ^origin_id -> %Stops.Stop{zone: "1A"} end)
      |> expect(:get, fn ^destination_id -> %Stops.Stop{zone: "7"} end)

      assert %Fares.Fare{cents: 1100, duration: :single_trip} =
               recommended_fare(route, origin_id, destination_id)
    end

    test "returns the appropriate fare for Foxboro Special Events" do
      route = %Route{type: 2, id: "CR-Foxboro"}
      south_station_id = "place-sstat"
      foxboro_id = "place-PB-0194"

      assert %Fares.Fare{cents: 2000, duration: :round_trip} =
               recommended_fare(route, south_station_id, foxboro_id)

      assert %Fares.Fare{cents: 2000, duration: :round_trip} =
               base_fare(route, south_station_id, foxboro_id)

      assert %Fares.Fare{cents: 2000, duration: :round_trip} =
               recommended_fare(route, foxboro_id, south_station_id)

      assert %Fares.Fare{cents: 2000, duration: :round_trip} =
               base_fare(route, foxboro_id, south_station_id)
    end

    test "returns nil if no matching fares found" do
      route = %Route{type: 2, id: "CapeFlyer"}
      origin_id = "place-sstat"
      destination_id = "Hyannis"

      fare_fn = fn _ -> [] end

      assert recommended_fare(route, origin_id, destination_id, fare_fn) == nil
    end

    test "returns a free fare for any bus shuttle rail replacements" do
      route = %Route{
        description: :rail_replacement_bus,
        id: "Shuttle-BallardvaleMaldenCenter",
        name: "Haverhill Line Shuttle",
        type: 3
      }

      origin_id = "place-mlmnl"
      destination_id = "place-WR-0099"

      assert %Fares.Fare{cents: 0, name: :free_fare} =
               recommended_fare(route, origin_id, destination_id)

      assert %Fares.Fare{cents: 0, name: :free_fare} =
               base_fare(route, origin_id, destination_id)
    end

    test "returns the reduced fares for commuter rail" do
      route = %Route{type: 2}
      origin_id = Faker.Internet.slug()
      destination_id = Faker.Internet.slug()

      reduced_cr_fare = %Fares.Fare{
        additional_valid_modes: [],
        cents: 350,
        duration: :single_trip,
        media: [:senior_card],
        mode: :commuter_rail,
        name: {:interzone, "10"},
        price_label: nil,
        reduced: :senior_disabled
      }

      fare_fn = fn @default_filters ++ [name: {:zone, "7"}] ->
        [
          %Fares.Fare{
            additional_valid_modes: [],
            cents: 1050,
            media: [:commuter_ticket, :cash],
            mode: :commuter_rail,
            name: {:zone, "7"},
            reduced: nil
          },
          reduced_cr_fare
        ]
      end

      Stops.Repo.Mock
      |> expect(:get, fn ^origin_id -> %Stops.Stop{zone: "1A"} end)
      |> expect(:get, fn ^destination_id -> %Stops.Stop{zone: "7"} end)

      assert reduced_cr_fare == reduced_fare(route, origin_id, destination_id, fare_fn)
    end
  end

  describe "ferry" do
    test "returns the fare that is not discounted for the correct ferry trip" do
      route = %Route{type: 4}
      origin_id = "Boat-Charlestown"
      destination_id = "Boat-Long-South"

      fare_fn = fn @default_filters ++ [name: :ferry_inner_harbor] ->
        [
          %Fares.Fare{
            additional_valid_modes: [],
            cents: 350,
            media: [:charlie_ticket],
            mode: :ferry,
            name: :ferry_inner_harbor,
            reduced: nil
          }
        ]
      end

      assert %Fares.Fare{cents: 350} =
               recommended_fare(route, origin_id, destination_id, fare_fn)

      assert %Fares.Fare{cents: 350} = base_fare(route, origin_id, destination_id, fare_fn)
    end

    test "returns the reduced fares for ferry" do
      route = %Route{type: 4}
      origin_id = "Boat-Charlestown"
      destination_id = "Boat-Long-South"

      reduced_ferry_fare = %Fares.Fare{
        additional_valid_modes: [],
        cents: 350,
        duration: nil,
        media: [:charlie_ticket],
        mode: :ferry,
        name: :ferry_inner_harbor,
        price_label: nil,
        reduced: :senior_disabled
      }

      fare_fn = fn @default_filters ++ [name: :ferry_inner_harbor] ->
        [
          %Fares.Fare{
            additional_valid_modes: [],
            cents: 350,
            media: [:charlie_ticket],
            mode: :ferry,
            name: :ferry_inner_harbor,
            reduced: nil
          },
          reduced_ferry_fare
        ]
      end

      assert reduced_ferry_fare == reduced_fare(route, origin_id, destination_id, fare_fn)
    end
  end
end
