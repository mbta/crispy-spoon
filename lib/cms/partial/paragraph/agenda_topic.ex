defmodule CMS.Partial.Paragraph.AgendaTopic do
  @moduledoc """
  A paragraph for agenda topics (used exclusively by CMS.Page.Agenda).
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      handle_html: 1,
      parse_files: 2,
      parse_links: 2,
      parse_paragraphs: 3
    ]

  alias CMS.Field.{File, Link}
  alias CMS.Partial.Paragraph.AgendaSubTopic
  alias Phoenix.HTML

  defstruct title: "",
            video_bookmark: nil,
            description: HTML.raw(""),
            sub_topics: [],
            files: [],
            links: []

  @type video_bookmark :: String.t() | nil

  @type t :: %__MODULE__{
          title: String.t(),
          video_bookmark: video_bookmark,
          description: HTML.safe(),
          sub_topics: [AgendaSubTopic.t()],
          files: [File.t()],
          links: [Link.t()]
        }

  @spec from_api(map, Keyword.t()) :: t
  def from_api(data, preview_opts \\ []) do
    %__MODULE__{
      title: field_value(data, "field_topic_title"),
      video_bookmark: field_value(data, "field_video_bookmark"),
      description: data |> field_value("field_agenda_topic_description") |> handle_html,
      sub_topics: parse_paragraphs(data, preview_opts, "field_sub_topics"),
      files: parse_files(data, "field_related_files"),
      links: parse_links(data, "field_external_resources")
    }
  end
end
