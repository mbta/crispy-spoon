defmodule CMS.Page.Basic do
  @moduledoc """
  Represents a basic "page" type in the Drupal CMS. Multiple
  content types can use this struct, as defined in CMS.Page.Basic
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      int_or_string_to_int: 1,
      parse_body: 1,
      parse_paragraphs: 2
    ]

  alias CMS.Breadcrumbs
  alias CMS.Partial.{MenuLinks, Paragraph}
  alias Phoenix.HTML

  defstruct body: HTML.raw(""),
            id: nil,
            paragraphs: [],
            sidebar_menu: nil,
            title: "",
            breadcrumbs: []

  @type t :: %__MODULE__{
          id: integer | nil,
          title: String.t(),
          body: HTML.safe(),
          paragraphs: [Paragraph.t()],
          sidebar_menu: MenuLinks.t() | nil,
          breadcrumbs: [Util.Breadcrumb.t()]
        }

  @spec from_api(map, Keyword.t()) :: t
  def from_api(%{} = data, preview_opts \\ []) do
    %__MODULE__{
      id: int_or_string_to_int(field_value(data, "nid")),
      title: field_value(data, "title") || "",
      body: parse_body(data),
      paragraphs: parse_paragraphs(data, preview_opts),
      sidebar_menu: parse_menu_links(data),
      breadcrumbs: Breadcrumbs.build(data)
    }
  end

  @spec parse_menu_links(map) :: MenuLinks.t() | nil
  defp parse_menu_links(%{"field_sidebar_menu" => [menu_links_data]})
       when not is_nil(menu_links_data) do
    MenuLinks.from_api(menu_links_data)
  end

  defp parse_menu_links(_) do
    nil
  end
end
