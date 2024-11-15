defmodule CMS.Page.Diversions do
  @moduledoc """
  Represents a basic "page" type in the Drupal CMS. Multiple
  content types can use this struct, as defined in CMS.Page.Basic
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      int_or_string_to_int: 1,
      parse_body: 1,
      parse_page_types: 1,
      parse_paragraphs: 2,
      parse_related_transit: 1
    ]

  alias CMS.Breadcrumbs
  alias CMS.Partial.{MenuLinks, Paragraph}
  alias Phoenix.HTML

  defstruct id: nil,
            body: HTML.raw(""),
            breadcrumbs: [],
            page_types: [],
            paragraphs: [],
            related_transit: [],
            sidebar_menu: nil,
            title: ""

  @type t :: %__MODULE__{
          id: integer | nil,
          body: HTML.safe(),
          breadcrumbs: [Util.Breadcrumb.t()],
          page_types: [String.t()],
          paragraphs: [Paragraph.t()],
          related_transit: [String.t()],
          sidebar_menu: MenuLinks.t() | nil,
          title: String.t()
        }

  @spec from_api(map, Keyword.t()) :: t
  def from_api(%{} = data, preview_opts \\ []) do
    %__MODULE__{
      id: int_or_string_to_int(field_value(data, "nid")),
      body: parse_body(data),
      breadcrumbs: Breadcrumbs.build(data),
      page_types: parse_page_types(data),
      paragraphs: parse_paragraphs(data, preview_opts),
      related_transit: parse_related_transit(data),
      sidebar_menu: parse_menu_links(data),
      title: field_value(data, "title") || ""
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
