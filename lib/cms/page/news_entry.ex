defmodule CMS.Page.NewsEntry do
  @moduledoc """
  Represents a "news_entry" content type in the Drupal CMS.
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      handle_html: 1,
      int_or_string_to_int: 1,
      parse_body: 1,
      path_alias: 1
    ]

  alias Phoenix.HTML

  # configured in the CMS
  @number_of_recent_news_suggestions 4

  defstruct id: nil,
            title: HTML.raw(""),
            body: HTML.raw(""),
            media_contact: nil,
            media_email: nil,
            media_phone: nil,
            more_information: HTML.raw(""),
            posted_on: nil,
            teaser: HTML.raw(""),
            migration_id: nil,
            path_alias: nil,
            utm_url: nil

  @type t :: %__MODULE__{
          id: integer | nil,
          title: HTML.safe(),
          body: HTML.safe(),
          media_contact: String.t() | nil,
          media_email: String.t() | nil,
          media_phone: String.t() | nil,
          more_information: HTML.safe() | nil,
          posted_on: Date.t() | nil,
          teaser: HTML.safe(),
          migration_id: String.t() | nil,
          path_alias: String.t() | nil,
          utm_url: String.t() | nil
        }

  @spec from_api(map) :: t
  def from_api(%{} = data) do
    %__MODULE__{
      id: int_or_string_to_int(field_value(data, "nid")),
      title: field_value(data, "title"),
      body: parse_body(data),
      media_contact: field_value(data, "field_media_contact"),
      media_email: field_value(data, "field_media_email"),
      media_phone: field_value(data, "field_media_phone"),
      more_information: parse_more_information(data),
      posted_on: parse_posted_date(data),
      teaser: handle_html(field_value(data, "field_teaser")),
      migration_id: field_value(data, "field_migration_id"),
      path_alias: path_alias(data)
    }
  end

  def contact?(news_entry) do
    news_entry.media_contact || news_entry.media_email || news_entry.media_phone
  end

  defp parse_more_information(data) do
    data
    |> field_value("field_more_information")
    |> handle_html
  end

  def number_of_recent_news_suggestions do
    @number_of_recent_news_suggestions
  end

  defp parse_posted_date(data) do
    data
    |> field_value("field_posted_on")
    |> Timex.parse!("{YYYY}-{0M}-{0D}")
    |> NaiveDateTime.to_date()
  end
end
