defmodule CMS.Partial.Paragraph.CustomHTML do
  @moduledoc """
  Represents a CustomHTML Paragraph in the CMS
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      handle_html: 1
    ]

  alias Phoenix.HTML

  defstruct body: HTML.raw(""),
            right_rail: false

  @type t :: %__MODULE__{
          body: HTML.safe(),
          right_rail: boolean
        }

  @spec from_api(map) :: t
  def from_api(data) do
    %__MODULE__{
      body: data |> field_value("field_custom_html_body") |> handle_html,
      right_rail: field_value(data, "field_right_rail")
    }
  end
end
