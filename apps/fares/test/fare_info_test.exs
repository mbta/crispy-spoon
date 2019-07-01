defmodule Fares.FareInfoTest do
  use ExUnit.Case, async: true
  alias Fares.Fare
  import Fares.FareInfo

  describe "fare_info/0" do
    test "returns a non-empty list of Fare objects" do
      actual = fare_info()
      refute actual == []
      assert Enum.all?(actual, &match?(%Fare{}, &1))
    end

    test "no duplicate fares are present" do
      results = fare_info()
      unique = Enum.uniq(results)
      assert Enum.count(results) == Enum.count(unique)
    end

    test "reduced fares for senior and student media have been broken out" do
      results = fare_info()
      assert Enum.any?(results, &match?(%Fare{reduced: :senior_disabled}, &1))
      assert Enum.any?(results, &match?(%Fare{reduced: :student}, &1))
      assert Enum.any?(results, &match?(%Fare{reduced: :any}, &1))
    end
  end

  describe "mapper/1" do
    test "maps the fares for a zone into one-way, round trip, monthly, mticket, and weekend prices" do
      assert mapper(["commuter", "zone_1a", "2.25", "1.10", "84.50"]) == [
               %Fare{
                 name: {:zone, "1A"},
                 mode: :commuter_rail,
                 duration: :single_trip,
                 media: [:commuter_ticket, :cash, :mticket],
                 reduced: nil,
                 cents: 225
               },
               %Fare{
                 name: {:zone, "1A"},
                 mode: :commuter_rail,
                 duration: :single_trip,
                 media: [:senior_card, :student_card],
                 reduced: :any,
                 cents: 110
               },
               %Fare{
                 name: {:zone, "1A"},
                 mode: :commuter_rail,
                 duration: :round_trip,
                 media: [:commuter_ticket, :cash, :mticket],
                 reduced: nil,
                 cents: 450
               },
               %Fare{
                 name: {:zone, "1A"},
                 mode: :commuter_rail,
                 duration: :round_trip,
                 media: [:senior_card, :student_card],
                 reduced: :any,
                 cents: 220
               },
               %Fare{
                 name: {:zone, "1A"},
                 mode: :commuter_rail,
                 duration: :month,
                 media: [:commuter_ticket],
                 reduced: nil,
                 cents: 8450,
                 additional_valid_modes: [:subway, :bus, :ferry]
               },
               %Fare{
                 name: {:zone, "1A"},
                 mode: :commuter_rail,
                 duration: :month,
                 media: [:mticket],
                 reduced: nil,
                 cents: 7450
               },
               %Fare{
                 name: {:zone, "1A"},
                 mode: :commuter_rail,
                 duration: :weekend,
                 media: [:commuter_ticket, :cash, :mticket],
                 reduced: nil,
                 cents: 1_000
               }
             ]
    end

    test "does not include subway or ferry modes for interzone fares" do
      assert mapper(["commuter", "interzone_5", "4.50", "2.25", "148.00"]) == [
               %Fare{
                 additional_valid_modes: [],
                 cents: 450,
                 duration: :single_trip,
                 media: [:commuter_ticket, :cash, :mticket],
                 mode: :commuter_rail,
                 name: {:interzone, "5"},
                 reduced: nil
               },
               %Fare{
                 additional_valid_modes: [],
                 cents: 225,
                 duration: :single_trip,
                 media: [:senior_card, :student_card],
                 mode: :commuter_rail,
                 name: {:interzone, "5"},
                 reduced: :any
               },
               %Fare{
                 additional_valid_modes: [],
                 cents: 900,
                 duration: :round_trip,
                 media: [:commuter_ticket, :cash, :mticket],
                 mode: :commuter_rail,
                 name: {:interzone, "5"},
                 reduced: nil
               },
               %Fare{
                 additional_valid_modes: [],
                 cents: 450,
                 duration: :round_trip,
                 media: [:senior_card, :student_card],
                 mode: :commuter_rail,
                 name: {:interzone, "5"},
                 reduced: :any
               },
               %Fare{
                 additional_valid_modes: [:bus],
                 cents: 14_800,
                 duration: :month,
                 media: [:commuter_ticket],
                 mode: :commuter_rail,
                 name: {:interzone, "5"},
                 reduced: nil
               },
               %Fare{
                 additional_valid_modes: [],
                 cents: 13_800,
                 duration: :month,
                 media: [:mticket],
                 mode: :commuter_rail,
                 name: {:interzone, "5"},
                 reduced: nil
               },
               %Fare{
                 additional_valid_modes: [],
                 cents: 1000,
                 duration: :weekend,
                 media: [:commuter_ticket, :cash, :mticket],
                 mode: :commuter_rail,
                 name: {:interzone, "5"},
                 price_label: nil,
                 reduced: nil
               }
             ]
    end
  end

  describe "mticket_price/1" do
    test "subtracts 10 dollars from the monthly price" do
      assert mticket_price(2000) == 1000
    end
  end

  describe "georges_island_ferry_fares/0" do
    test "returns 7 Fare structs with name :ferry_george" do
      fares = georges_island_ferry_fares()
      assert length(fares) == 7
      assert Enum.all?(fares, fn %Fare{name: :ferry_george} -> true end)
    end
  end
end
