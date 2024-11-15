defmodule CMS.Partial.Paragraph.DescriptiveLink do
  @moduledoc """

  Represents an individual "Descriptive Link" paragraph in the CMS. They are normally
  sub-paragraphs of a Title Card Set, but can also be used independently as well.

  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      handle_html: 1,
      parse_link: 2
    ]

  alias CMS.Field.Link
  alias Phoenix.HTML

  defstruct body: HTML.raw(""),
            link: nil,
            title: "",
            parent: ""

  @type t :: %__MODULE__{
          body: HTML.safe(),
          link: Link.t() | nil,
          title: String.t(),
          parent: String.t()
        }

  @spec from_api(map) :: t
  def from_api(data) do
    %__MODULE__{
      body: data |> field_value("field_title_card_body") |> handle_html,
      link: parse_link(data, "field_title_card_link"),
      title: field_value(data, "field_title_card_title"),
      parent: field_value(data, "parent_field_name")
    }
  end

  @spec alone?(__MODULE__.t()) :: boolean
  def alone?(%__MODULE__{parent: "field_paragraphs"}), do: true
  def alone?(%__MODULE__{}), do: false
end
