defmodule Test.Support.Generators.ServiceDateTime do
  @moduledoc """
  Factories to help generate/evaluate service date_times for testing.
  """

  import Dotcom.Utils.ServiceDateTime, only: [end_of_service_day: 1]

  import Test.Support.Generators.DateTime,
    only: [date_time_generator: 0, time_range_date_time_generator: 1]

  @doc "Generate a random date_time before midnight or between midnight and 3am."
  def date_time_generator(:after_midnight) do
    random_date_time = date_time_generator() |> Enum.take(1) |> List.first()
    random_hour = Enum.random(0..2)

    after_midnight = Map.put(random_date_time, :hour, random_hour)
    end_of_service_day = end_of_service_day(after_midnight)

    time_range_date_time_generator({after_midnight, end_of_service_day})
  end

  def date_time_generator(:before_midnight) do
    random_date_time = date_time_generator() |> Enum.take(1) |> List.first()
    random_hour = Enum.random(3..23)

    before_midnight = Map.put(random_date_time, :hour, random_hour)
    end_of_day = Timex.end_of_day(before_midnight)

    time_range_date_time_generator({before_midnight, end_of_day})
  end
end
