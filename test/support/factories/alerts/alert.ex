defmodule Test.Support.Factories.Alerts.Alert do
  @moduledoc """
  Generated fake data for %Alerts.Alert{}
  """

  use ExMachina

  alias Alerts.{Alert, Priority}
  alias Test.Support.Factories.Alerts.{InformedEntity, InformedEntitySet}

  def alert_factory do
    %Alert{
      id: :rand.uniform(999) |> Integer.to_string(),
      active_period: [{Faker.DateTime.forward(1), Faker.DateTime.forward(2)}],
      banner: Faker.Lorem.Shakespeare.king_richard_iii(),
      cause: Faker.Lorem.Shakespeare.king_richard_iii(),
      created_at: Timex.now(),
      description: Faker.Lorem.Shakespeare.king_richard_iii(),
      effect: Alert.all_types() |> Faker.Util.pick(),
      header: Faker.Lorem.Shakespeare.king_richard_iii(),
      image: Faker.Internet.image_url(),
      image_alternative_text: Faker.Lorem.Shakespeare.king_richard_iii(),
      informed_entity: InformedEntitySet.build(:informed_entity_set),
      lifecycle: Alert.lifecycles() |> Faker.Util.pick(),
      priority: Priority.priority_levels() |> Faker.Util.pick(),
      severity: :rand.uniform(10),
      updated_at: Timex.now(),
      url: Faker.Internet.url()
    }
  end

  def alert_for_route_factory(attrs) do
    {route_id, attrs} = Map.pop(attrs, :route_id)

    build(
      :alert,
      attrs
      |> Map.put(
        :informed_entity,
        InformedEntitySet.build(:informed_entity_set,
          entities: [InformedEntity.build(:informed_entity, route: route_id)]
        )
      )
    )
  end

  def active_during(alert, time) do
    %{alert | active_period: [{time_before(time), time_after(time)}]}
  end

  def active_starting_at(alert, start_time) do
    %{alert | active_period: [{start_time, time_after(start_time)}]}
  end

  # Returns a random time during the day today before the time provided.
  defp time_before(time) do
    between(Timex.beginning_of_day(time), time)
  end

  # Returns a random time during the day today after the time provided.
  defp time_after(time) do
    between(time, Timex.end_of_day(time))
  end

  # Returns a random time between the times provided in the Eastern time zone.
  defp between(time1, time2) do
    Faker.DateTime.between(time1, time2) |> Timex.to_datetime("America/New_York")
  end
end
