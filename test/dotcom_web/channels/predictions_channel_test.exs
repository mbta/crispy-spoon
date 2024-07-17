defmodule DotcomWeb.PredictionsChannelTest do
  use DotcomWeb.ChannelCase, async: false

  import Mox

  alias DotcomWeb.{PredictionsChannel, UserSocket}
  alias Test.Support.Factories.Predictions.Prediction

  @predictions_pub_sub Application.compile_env!(:dotcom, :predictions_pub_sub)

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    channel = "predictions:stop:#{Faker.Lorem.word()}"
    socket = socket(UserSocket, "", %{})

    stub(MBTA.Api.Mock, :get_json, fn _, _ ->
      []
    end)

    # Ensure no streams are running so that we can test stream creation
    Predictions.StreamSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(&DynamicSupervisor.terminate_child(Predictions.StreamSupervisor, elem(&1, 1)))

    {:ok, %{channel: channel, socket: socket}}
  end

  describe "join/3" do
    test "filters skipped or cancelled predictions", context do
      canonical_prediction = Prediction.build(:canonical_prediction)

      filtered_prediction =
        canonical_prediction
        |> Map.put(:schedule_relationship, :skipped)

      expect(@predictions_pub_sub, :subscribe, fn _ ->
        [canonical_prediction, filtered_prediction]
      end)

      {:ok, %{predictions: predictions}, _} =
        PredictionsChannel.join(context.channel, nil, context.socket)

      assert predictions == [canonical_prediction]
    end

    test "filters predictions with no departure time", context do
      canonical_prediction = Prediction.build(:canonical_prediction)

      filtered_prediction =
        canonical_prediction
        |> Map.put(:departure_time, nil)

      expect(@predictions_pub_sub, :subscribe, fn _ ->
        [canonical_prediction, filtered_prediction]
      end)

      {:ok, %{predictions: predictions}, _} =
        PredictionsChannel.join(context.channel, nil, context.socket)

      assert predictions == [canonical_prediction]
    end
  end

  describe "handle_info/2" do
  end

  describe "terminate/2" do
  end
end
