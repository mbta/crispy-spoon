defmodule CMS.Partial.Paragraph.CodeEmbed do
  @moduledoc """
  Represents a CodeEmbed Paragraph in the CMS.
  Body is raw HTML from CMS, and should not be scrubbed or rewritten.
  """

  import CMS.Helpers, only: [field_value: 2, parse_paragraphs: 3]

  alias CMS.Partial.Paragraph.ColumnMultiHeader
  alias Phoenix.HTML

  defstruct header: nil,
            right_rail: false,
            body: HTML.raw("")

  @type t :: %__MODULE__{
          header: ColumnMultiHeader.t() | nil,
          right_rail: boolean,
          body: HTML.safe()
        }

  @spec from_api(map, Keyword.t()) :: t
  def from_api(data, preview_opts) do
    %__MODULE__{
      header: data |> parse_paragraphs(preview_opts, "field_multi_column_header") |> List.first(),
      right_rail: field_value(data, "field_right_rail"),
      body: data |> field_value("field_code") |> HTML.raw()
    }
  end
end
