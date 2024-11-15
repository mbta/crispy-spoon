defmodule Fares.FormatTest do
  use ExUnit.Case, async: true

  import Fares.Format

  alias Fares.{Fare, Summary}

  describe "price/1" do
    test "gets a string version of the price formatted nicely" do
      assert price(%Fare{cents: 925}) == "$9.25"
      assert price(%Fare{cents: 100}) == "$1.00"
    end

    test "returns empty string when fare is nil" do
      assert price(nil) == ""
    end
  end

  describe "media/1" do
    test "returns generic media message when both student and senior price applies" do
      assert media(%Fare{reduced: :any}) == "reduced fare card"
    end

    test "returns multiple/summary media when more than one media type applies" do
      assert media(%Fare{media: [:charlie_ticket, :cash]}) == ["CharlieTicket", " or ", "cash"]
    end

    test "returns appropriate media type text based on fare" do
      assert media(%Fare{media: [:charlie_card]}) == "CharlieCard"
      assert media(%Fare{media: [:commuter_ticket]}) == "CharlieTicket"
      assert media(%Fare{media: [:mticket]}) == "mTicket App"
      assert media(%Fare{media: [:cash]}) == "cash"
      assert media(%Fare{media: [:senior_card]}) == "Senior CharlieCard or TAP ID"
      assert media(%Fare{media: [:student_card]}) == "Student CharlieCard"
    end
  end

  describe "name/1" do
    test "uses the name of the CR zone" do
      assert name(%Fare{name: {:zone, "2"}}) == "Zone 2"
      assert name(%Fare{name: {:interzone, "3"}}) == "Interzone 3"
    end

    test "gives a printable name when given the name of a fare" do
      assert name({:zone, "6"}) == "Zone 6"
      assert name({:interzone, "4"}) == "Interzone 4"
    end

    test "gives a descriptive name for bus fares" do
      assert name(%Fare{name: :local_bus}) == "Local Bus"
      assert name(%Fare{name: :express_bus}) == "Express Bus"
    end

    test "gives a descriptive name for ferry fares" do
      assert name(%Fare{name: :ferry_inner_harbor}) == "Charlestown Ferry"
      assert name(%Fare{name: :ferry_cross_harbor}) == "Cross Harbor Ferry"
      assert name(%Fare{name: :ferry_east_boston}) == "East Boston Ferry"
      assert name(%Fare{name: :ferry_lynn}) == "Lynn Ferry"
      assert name(%Fare{name: :ferry_winthrop}) == "Winthrop/Quincy Ferry"
      assert name(%Fare{name: :commuter_ferry}) == "Hingham/Hull Ferry"
    end

    test "gives a descriptive name for free fares" do
      assert name(%Fare{name: :free_fare}), do: "Free Fare"
    end
  end

  describe "full_name/1" do
    test "gives a name for monthly Subway passes" do
      assert full_name(%Fare{mode: :subway, duration: :month}) == "Monthly LinkPass"
    end

    test "gives a name for monthly Bus passes" do
      assert full_name(%Fare{mode: :bus, duration: :month}) == "Monthly Local Bus Pass"
    end

    test "gives a name for weekend CR passes" do
      assert full_name(%Fare{mode: :commuter_rail, duration: :weekend}) == "Weekend Pass"
    end

    test "gives a name for week and day passes" do
      assert full_name(%Fare{duration: :week}) == "7-Day Pass"
      assert full_name(%Fare{duration: :day}) == "1-Day Pass"
    end

    test "gives a name for ADA and premium rides" do
      assert full_name(%Fare{name: :ada_ride}) == "ADA Ride Fare"
      assert full_name(%Fare{name: :premium_ride}) == "Premium Ride Fare"
    end

    test "gives a name for a Shuttle which doesn't have an associated fare" do
      assert full_name(nil) == "Shuttle"
    end

    test "gives the name and duration for all other fares" do
      assert full_name(%Fare{name: :commuter_ferry, duration: :month}) ==
               ["Hingham/Hull Ferry", " ", "Monthly Pass"]
    end
  end

  describe "concise_full_name/1" do
    test "returns the full name excluding 'Monthly Pass' for commuter rail and express buses" do
      cr_fare = %Fare{
        mode: :commuter_rail,
        media: [:commuter_ticket],
        duration: :month,
        name: {:zone, "7"}
      }

      express_fare = %Fare{
        name: :express_bus,
        mode: :bus,
        duration: :month
      }

      assert concise_full_name(cr_fare) == "Zone 7"
      assert concise_full_name(express_fare) == "Express Bus"
    end

    test "returns the full_name for other fares" do
      assert concise_full_name(%Fare{mode: :subway, duration: :month}) == "Monthly LinkPass"
      assert concise_full_name(%Fare{duration: :day}) == "1-Day Pass"
    end
  end

  test "duration/1" do
    assert duration(%Fare{duration: :single_trip}) == "One-Way"
    assert duration(%Fare{duration: :round_trip}) == "Round Trip"
    assert duration(%Fare{duration: :month}) == "Monthly Pass"
    assert duration(%Fare{duration: :month, media: [:mticket]}) == "Monthly Pass on mTicket App"
    assert duration(%Fare{mode: :subway, duration: :single_trip}) == "One-Way"
    assert duration(%Fare{mode: :bus, duration: :single_trip}) == "One-Way"
    assert duration(%Fare{name: :ferry_inner_harbor, duration: :day}) == "One-Day Pass"
  end

  describe "summarize/2" do
    test "bus subway groups them by name/duration/modes" do
      base = %Fare{name: :subway, mode: :subway}
      single_trip_cash = %{base | duration: :single_trip, media: [:cash], cents: 100}

      single_trip_charlie_card = %{
        base
        | duration: :single_trip,
          media: [:charlie_card],
          cents: 200
      }

      week_pass = %{
        base
        | duration: :week,
          media: [:charlie_card],
          cents: 300,
          additional_valid_modes: [:bus]
      }

      month_pass = %{base | duration: :month, media: [:charlie_card, :charlie_ticket], cents: 400}

      actual =
        summarize(
          [single_trip_cash, single_trip_charlie_card, week_pass, month_pass],
          :bus_subway
        )

      expected = [
        %Summary{
          name: ["Subway", " ", "One-Way"],
          duration: :single_trip,
          fares: [{"cash", "$1.00"}, {"CharlieCard", "$2.00"}],
          modes: [:subway]
        },
        %Summary{
          name: "7-Day Pass",
          duration: :week,
          fares: [{"CharlieCard", "$3.00"}],
          modes: [:subway, :bus]
        },
        %Summary{
          name: "Monthly LinkPass",
          duration: :month,
          fares: [{["CharlieCard", " or ", "CharlieTicket"], "$4.00"}],
          modes: [:subway]
        }
      ]

      assert actual == expected
    end

    test "commuter rail groups them by single/multiple trip and groups prices" do
      base = %Fare{name: :commuter_rail, mode: :commuter_rail, duration: :single_trip}
      cheap = %{base | name: {:zone, "1"}, cents: 100}
      expensive = %{base | name: {:zone, "10"}, cents: 200}

      actual = summarize([cheap, expensive], :commuter_rail)

      expected = [
        %Summary{
          name: "Commuter Rail One-Way",
          duration: :single_trip,
          fares: [{"Zones 1A-10", ["$1.00", " – ", "$2.00"]}],
          modes: [:commuter_rail]
        }
      ]

      assert actual == expected
    end

    test "different mode summaries can be grouped together" do
      c_base = %Fare{name: :commuter_rail, mode: :commuter_rail, duration: :single_trip}
      c_cheap = %{c_base | name: {:zone, "1"}, cents: 100}
      c_expensive = %{c_base | name: {:zone, "10"}, cents: 200}

      f_base = %Fare{name: :ferry, mode: :ferry, duration: :single_trip}
      f_cheap = %{f_base | cents: 100}
      f_expensive = %{f_base | cents: 200}

      actual = summarize([c_cheap, c_expensive, f_cheap, f_expensive], [:commuter_rail, :ferry])

      expected = [
        %Summary{
          name: "Commuter Rail One-Way",
          duration: :single_trip,
          fares: [{"Zones 1A-10", ["$1.00", " – ", "$2.00"]}],
          modes: [:commuter_rail]
        },
        %Summary{
          name: "Ferry One-Way",
          duration: :single_trip,
          fares: [{"All ferry routes", ["$1.00", " – ", "$2.00"]}],
          modes: [:ferry]
        }
      ]

      assert actual == expected
    end

    test "ferry groups them by single/multiple trip and groups prices" do
      base = %Fare{name: :ferry, mode: :ferry, duration: :single_trip}
      cheap = %{base | cents: 100}
      expensive = %{base | cents: 200}

      actual = summarize([cheap, expensive], :ferry)

      expected = [
        %Summary{
          name: "Ferry One-Way",
          duration: :single_trip,
          fares: [{"All ferry routes", ["$1.00", " – ", "$2.00"]}],
          modes: [:ferry]
        }
      ]

      assert actual == expected
    end
  end

  describe "summarize_one/3" do
    test "single fare is summarized correctly" do
      fare = %Fare{
        name: {:zone, "6"},
        mode: :commuter_rail,
        duration: :single_trip,
        cents: 1250,
        media: :cash
      }

      summarized = summarize_one(fare, url: "/link_here?please=yes")

      expected = %Summary{
        fares: [{"cash", "$12.50"}],
        name: ["Zone 6", " ", "One-Way"],
        url: "/link_here?please=yes",
        modes: [:commuter_rail],
        duration: :single_trip
      }

      assert summarized == expected
    end
  end
end
