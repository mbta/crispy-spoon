defmodule CMS.Page.Agenda do
  @moduledoc """
  Represents an agenda content type in the Drupal CMS.
  """

  alias CMS.Field.Link
  alias CMS.Partial.Paragraph

  import CMS.Helpers,
    only: [
      field_value: 2,
      int_or_string_to_int: 1,
      parse_paragraphs: 3,
      parse_link: 2
    ]

  defstruct id: nil,
            title: "",
            topics: [],
            collect_info: false,
            event_reference: nil,
            formstack_url: nil

  @type t :: %__MODULE__{
          id: integer | nil,
          title: String.t(),
          topics: [Paragraph.AgendaTopic.t()],
          collect_info: boolean,
          event_reference: integer | nil,
          formstack_url: Link.t() | nil
        }

  @spec from_api(map, Keyword.t()) :: t
  def from_api(%{} = data, preview_opts \\ []) do
    %__MODULE__{
      id: int_or_string_to_int(field_value(data, "nid")),
      title: field_value(data, "title") || "",
      topics: parse_paragraphs(data, preview_opts, "field_agenda_topics"),
      collect_info: field_value(data, "field_agenda_collect_user_info"),
      event_reference: int_or_string_to_int(field_value(data, "field_agenda_event")),
      formstack_url: parse_link(data, "field_agenda_formstack_url")
    }
  end
end
