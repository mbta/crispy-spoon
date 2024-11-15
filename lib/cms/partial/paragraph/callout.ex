defmodule CMS.Partial.Paragraph.Callout do
  @moduledoc """
  Represents the entity_reference ("Callout") Paragraph type
  in the CMS. There is only one field -- a deeper entity reference
  field which we will be parsing for the actual content data.
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      parse_body: 1
    ]

  alias CMS.Field.{Image, Link}
  alias Phoenix.HTML

  defstruct title: "",
            body: HTML.raw(""),
            image: nil,
            link: %Link{}

  @type t :: %__MODULE__{
          title: String.t(),
          body: HTML.safe(),
          image: Image.t() | nil,
          link: Link.t()
        }

  @spec from_api(map) :: t
  def from_api(%{"field_content_reference" => [entity]}) do
    %__MODULE__{
      title: field_value(entity, "title"),
      body: parse_body(entity),
      image: parse_optional_image(entity["field_image"]),
      link: entity["field_url"] |> List.first() |> Link.from_api()
    }
  end

  @spec parse_optional_image([map]) :: Image.t() | nil
  defp parse_optional_image([data]), do: Image.from_api(data)
  defp parse_optional_image(_), do: nil
end
