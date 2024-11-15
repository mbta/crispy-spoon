defmodule Util.DistanceTest do
  use ExUnit.Case, async: true

  import Util.Distance

  @position {42.57, -71.22}
  @stops [
    {42.593248, -71.280995},
    {42.546624, -71.174334},
    {42.518926, -71.252597},
    {42.518651, -71.247852}
  ]

  describe "closest/3" do
    test "given a list of positions, returns a list of the closest items" do
      assert closest(@stops, @position, 1) == [Enum.at(@stops, 1)]
      assert closest(@stops, @position, 2) == [Enum.at(@stops, 1), Enum.at(@stops, 0)]
    end
  end

  describe "sort/2" do
    test "given a list of positions, sorts them all by distance" do
      assert sort(@stops, @position) == [
               Enum.at(@stops, 1),
               Enum.at(@stops, 0),
               Enum.at(@stops, 3),
               Enum.at(@stops, 2)
             ]
    end
  end

  describe "haversine/2" do
    test "returns the Haversine distance between two points" do
      # test from http://rosettacode.org/wiki/Haversine_formula
      one = {36.12, -86.67}
      two = {33.94, -118.40}

      expected = 1793.55589
      actual = haversine(one, two)

      assert_in_delta expected, actual, 0.0001
    end
  end
end
