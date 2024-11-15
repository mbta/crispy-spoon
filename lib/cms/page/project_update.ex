defmodule CMS.Page.ProjectUpdate do
  @moduledoc """
  Represents the Project Update content type in the CMS.
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      int_or_string_to_int: 1,
      parse_body: 1,
      parse_date: 2,
      parse_image: 2,
      parse_images: 2,
      parse_paragraphs: 2,
      path_alias: 1
    ]

  alias CMS.Field.Image
  alias CMS.Partial.Paragraph
  alias Phoenix.HTML

  @enforce_keys [:id, :project_id]
  defstruct [
    :id,
    :project_id,
    :path_alias,
    project_url: "",
    body: HTML.raw(""),
    image: nil,
    paragraphs: [],
    photo_gallery: [],
    posted_on: "",
    teaser: "",
    title: "",
    redirects: []
  ]

  @type t :: %__MODULE__{
          id: integer,
          body: HTML.safe(),
          image: Image.t() | nil,
          paragraphs: [Paragraph.t()],
          photo_gallery: [Image.t()],
          posted_on: Date.t(),
          project_id: integer,
          project_url: String.t(),
          path_alias: String.t() | nil,
          teaser: String.t(),
          title: String.t(),
          redirects: [String.t()]
        }

  @spec from_api(map, Keyword.t()) :: t
  def from_api(%{} = data, preview_opts \\ []) do
    {project_id, project_alias} = parse_project(data)

    %__MODULE__{
      id: int_or_string_to_int(field_value(data, "nid")),
      body: parse_body(data),
      image: parse_image(data, "field_image"),
      paragraphs: parse_paragraphs(data, preview_opts),
      photo_gallery: parse_images(data, "field_photo_gallery"),
      posted_on: parse_date(data, "field_posted_on"),
      project_id: project_id,
      project_url: project_alias,
      teaser: field_value(data, "field_teaser"),
      title: field_value(data, "title"),
      path_alias: path_alias(data),
      redirects: Map.get(data, "redirects", [])
    }
  end

  defp parse_project(%{"field_project" => [%{"target_id" => id, "url" => url}]}), do: {id, url}
  defp parse_project(%{"field_project" => [%{"target_id" => id}]}), do: {id, ""}
end
