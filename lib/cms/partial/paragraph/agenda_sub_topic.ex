defmodule CMS.Partial.Paragraph.AgendaSubTopic do
  @moduledoc """
  A paragraph for agenda sub-topics (used exclusively by CMS.Partial.Paragraph.AgendaTopic).
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      handle_html: 1
    ]

  alias Phoenix.HTML

  defstruct title: "",
            description: HTML.raw("")

  @type t :: %__MODULE__{
          title: String.t(),
          description: HTML.safe()
        }

  @spec from_api(map) :: t
  def from_api(data) do
    %__MODULE__{
      title: field_value(data, "field_sub_topic_title"),
      description: data |> field_value("field_sub_topic_description") |> handle_html
    }
  end
end
