defmodule CMS.Page.Project do
  @moduledoc """
  Represents the Project content type in the CMS.
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      int_or_string_to_int: 1,
      parse_body: 1,
      parse_date: 2,
      parse_files: 2,
      parse_image: 2,
      parse_images: 2,
      parse_paragraphs: 2,
      path_alias: 1
    ]

  alias CMS.{Field, Partial.Paragraph}
  alias Field.{File, Image}
  alias Phoenix.HTML

  @enforce_keys [:id]
  defstruct [
    :id,
    body: HTML.raw(""),
    contact_information: nil,
    end_year: nil,
    featured: false,
    featured_image: nil,
    files: [],
    media_email: nil,
    media_phone: nil,
    paragraphs: [],
    photo_gallery: [],
    posted_on: "",
    start_year: nil,
    status: nil,
    teaser: "",
    title: "",
    updated_on: nil,
    path_alias: nil,
    redirects: []
  ]

  @type t :: %__MODULE__{
          id: integer,
          body: HTML.safe(),
          contact_information: String.t() | nil,
          end_year: String.t() | nil,
          featured: boolean,
          featured_image: Image.t() | nil,
          files: [File.t()],
          media_email: String.t() | nil,
          media_phone: String.t() | nil,
          paragraphs: [Paragraph.t()],
          photo_gallery: [Image.t()],
          start_year: String.t() | nil,
          status: String.t() | nil,
          teaser: String.t(),
          title: String.t(),
          updated_on: Date.t() | nil,
          path_alias: String.t() | nil,
          redirects: [String.t()]
        }

  @spec from_api(map, Keyword.t()) :: t
  def from_api(%{} = data, preview_opts \\ []) do
    %__MODULE__{
      id: int_or_string_to_int(field_value(data, "nid")),
      body: parse_body(data),
      contact_information: field_value(data, "field_contact_information"),
      end_year: field_value(data, "field_end_year"),
      featured: field_value(data, "field_featured"),
      featured_image: parse_image(data, "field_featured_image"),
      files: parse_files(data, "field_files"),
      media_email: field_value(data, "field_media_email"),
      media_phone: field_value(data, "field_media_phone"),
      paragraphs: parse_paragraphs(data, preview_opts),
      photo_gallery: parse_images(data, "field_photo_gallery"),
      start_year: field_value(data, "field_start_year"),
      status: field_value(data, "field_project_status"),
      teaser: field_value(data, "field_teaser"),
      title: field_value(data, "title"),
      updated_on: parse_date(data, "field_updated_on"),
      path_alias: path_alias(data),
      redirects: Map.get(data, "redirects", [])
    }
  end

  @spec contact?(t) :: boolean
  def contact?(project) do
    project.contact_information || project.media_email || project.media_phone
  end

  @spec alias(t()) :: String.t() | integer
  def alias(%__MODULE__{path_alias: "/projects/" <> path_alias}), do: path_alias
  def alias(%__MODULE__{id: id}), do: id
end
