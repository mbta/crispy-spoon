defmodule TransferTest do
  @moduledoc false
  use ExUnit.Case

  import TripPlan.Transfer
  alias TripPlan.{Leg, NamedPosition, PersonalDetail, TransitDetail}

  describe "is_maybe_transfer?/1 correctly identifies the potential presence of a transfer [assumes single ride media]" do
    leg_for_route = fn id -> %Leg{mode: %TransitDetail{route_id: id}} end
    @bus_leg leg_for_route.("77")
    @other_bus_leg leg_for_route.("28")
    @subway_leg leg_for_route.("Red")
    @other_subway_leg leg_for_route.("Orange")
    @cr_leg leg_for_route.("CR-Lowell")
    @ferry_leg leg_for_route.("Boat-F4")
    @innerxp_leg leg_for_route.("326")
    @other_innerxp_leg leg_for_route.("351")
    @outerxp_leg leg_for_route.("505")
    @other_outerxp_leg leg_for_route.("352")
    @sl_rapid_leg leg_for_route.("741")
    @sl_bus_leg leg_for_route.("751")

    test "if from or to is nil" do
      refute [nil, nil] |> is_maybe_transfer?
      refute [@subway_leg, nil] |> is_maybe_transfer?
      refute [nil, @bus_leg] |> is_maybe_transfer?
    end

    test "subway -> subway" do
      assert [@subway_leg, @other_subway_leg] |> is_maybe_transfer?
    end

    test "subway -> local bus" do
      assert [@subway_leg, @bus_leg] |> is_maybe_transfer?
    end

    test "local bus -> subway" do
      assert [@bus_leg, @subway_leg] |> is_maybe_transfer?
    end

    test "local bus -> local bus" do
      assert [@bus_leg, @other_bus_leg] |> is_maybe_transfer?
    end

    test "inner express bus -> subway" do
      assert [@innerxp_leg, @subway_leg] |> is_maybe_transfer?
    end

    test "outer express bus -> subway" do
      assert [@outerxp_leg, @subway_leg] |> is_maybe_transfer?
    end

    test "inner express bus -> local bus" do
      assert [@innerxp_leg, @bus_leg] |> is_maybe_transfer?
    end

    test "outer express bus -> local bus" do
      assert [@outerxp_leg, @bus_leg] |> is_maybe_transfer?
    end

    test "SL4 -> local bus" do
      assert [@sl_bus_leg, @bus_leg] |> is_maybe_transfer?
    end

    test "SL1 -> local bus" do
      assert [@sl_rapid_leg, @bus_leg] |> is_maybe_transfer?
    end

    test "local bus -> the same local bus" do
      refute [@bus_leg, @bus_leg] |> is_maybe_transfer?
    end

    test "inner express bus -> inner express bus" do
      refute [@innerxp_leg, @other_innerxp_leg] |> is_maybe_transfer?
    end

    test "outer express bus -> outer express bus" do
      refute [@outerxp_leg, @other_outerxp_leg] |> is_maybe_transfer?
    end

    test "commuter rail -> any other mode" do
      refute [@cr_leg, @cr_leg] |> is_maybe_transfer?
      refute [@cr_leg, @subway_leg] |> is_maybe_transfer?
      refute [@cr_leg, @bus_leg] |> is_maybe_transfer?
      refute [@cr_leg, @innerxp_leg] |> is_maybe_transfer?
      refute [@cr_leg, @outerxp_leg] |> is_maybe_transfer?
      refute [@cr_leg, @sl_bus_leg] |> is_maybe_transfer?
      refute [@cr_leg, @sl_rapid_leg] |> is_maybe_transfer?
    end

    test "ferry -> any other mode" do
      refute [@ferry_leg, @ferry_leg] |> is_maybe_transfer?
      refute [@ferry_leg, @subway_leg] |> is_maybe_transfer?
      refute [@ferry_leg, @bus_leg] |> is_maybe_transfer?
      refute [@ferry_leg, @innerxp_leg] |> is_maybe_transfer?
      refute [@ferry_leg, @outerxp_leg] |> is_maybe_transfer?
      refute [@ferry_leg, @sl_bus_leg] |> is_maybe_transfer?
      refute [@ferry_leg, @sl_rapid_leg] |> is_maybe_transfer?
    end
  end

  describe "is_subway_transfer?/1" do
    test "picks a transit-transit sequence" do
      legs_with_transfer = [
        %Leg{
          mode: %PersonalDetail{
            steps: [
              %PersonalDetail.Step{
                street_name: "Path"
              }
            ]
          }
        },
        %Leg{
          mode: %TransitDetail{
            route_id: "Green-C"
          },
          to: %NamedPosition{
            stop_id: "70202"
          }
        },
        %Leg{
          mode: %TransitDetail{
            route_id: "Blue"
          },
          from: %NamedPosition{
            stop_id: "70040"
          }
        }
      ]

      legs_without_transfer = [
        %Leg{
          mode: %TransitDetail{
            route_id: "Green-C"
          },
          to: %NamedPosition{
            stop_id: "70202"
          }
        },
        %Leg{
          mode: %PersonalDetail{
            steps: [
              %PersonalDetail.Step{
                street_name: "Path"
              }
            ]
          },
          from: %NamedPosition{
            stop_id: "70202"
          },
          to: %NamedPosition{
            stop_id: "70040"
          }
        }
      ]

      assert is_subway_transfer?(legs_with_transfer)
      refute is_subway_transfer?(legs_without_transfer)
    end

    test "handles transfers within the Winter St. Concourse" do
      leg_to_park = %Leg{
        mode: %TransitDetail{
          route_id: "Green-C"
        },
        to: %NamedPosition{
          stop_id: "71199"
        }
      }

      leg_from_dtx = %Leg{
        mode: %TransitDetail{
          route_id: "Orange"
        },
        from: %NamedPosition{
          stop_id: "70020"
        }
      }

      assert is_subway_transfer?([leg_to_park, leg_from_dtx])
    end
  end
end
