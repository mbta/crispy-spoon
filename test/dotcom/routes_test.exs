defmodule Dotcom.RoutesTest do
  use ExUnit.Case

  import Dotcom.Routes

  describe "subway_route_ids/0" do
    test "returns a list of route ids" do
      # Exercise/Verify
      assert Enum.all?(subway_route_ids(), &is_binary/1)
    end
  end
end
