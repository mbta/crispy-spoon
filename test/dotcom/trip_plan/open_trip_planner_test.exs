defmodule Dotcom.TripPlan.OpenTripPlannerTest do
  use ExUnit.Case, async: true

  import Mox
  import Test.Support.Factories.TripPlanner.TripPlanner

  alias Dotcom.TripPlan.{NamedPosition, OpenTripPlanner}

  @date_time Faker.DateTime.forward(2)
  @from build(:stop_named_position)
  @to build(:named_position)
  @opts [arrive_by: @date_time]

  setup :verify_on_exit!

  describe "plan/1" do
    test "processes arguments, adds tags,runs OpenTripPlannerClient.plan/3" do
      expect(OpenTripPlannerClient.Mock, :plan, fn from, to, plan_opts ->
        assert from == NamedPosition.to_keywords(@from)
        assert to == NamedPosition.to_keywords(@to)
        assert plan_opts[:arrive_by] == @opts[:arrive_by]
        assert plan_opts[:tags]
        {:ok, %OpenTripPlannerClient.Plan{itineraries: []}}
      end)

      assert {:ok, _} = OpenTripPlanner.plan(@from, @to, @opts)
    end
  end

  describe "tags/1" do
    test "outputs list of OpenTripPlannerClient.ItineraryTag modules" do
      tags = OpenTripPlanner.tags([])
      assert length(tags) > 0

      for tag <- tags do
        assert tag.module_info()[:attributes][:behaviour] == [
                 OpenTripPlannerClient.ItineraryTag.Behaviour
               ]
      end
    end

    test "uses different tags based on opt values" do
      refute OpenTripPlanner.tags(arrive_by: Faker.DateTime.forward(2)) ==
               OpenTripPlanner.tags(depart_at: Faker.DateTime.forward(2))
    end
  end
end
