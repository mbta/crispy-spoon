defmodule Dotcom.Utils.DateTime.Behaviour do
  @moduledoc """
  A behaviour for working with date_times.
  """

  @callback now() :: DateTime.t()

  @callback coerce_ambiguous_date_time(
              DateTime.t()
              | Timex.AmbiguousDateTime.t()
              | {:error, term()}
            ) ::
              DateTime.t()

  @callback in_range?(
              Dotcom.Utils.DateTime.date_time_range(),
              DateTime.t()
            ) :: boolean
end
