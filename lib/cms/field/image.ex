defmodule CMS.Field.Image do
  @moduledoc """
  Represents an image field in the Drupal CMS. This image field is embedded
  in other content types like CMS.Page.NewsEntry. Captions only used on galleries.
  """

  import CMS.Helpers,
    only: [
      field_value: 2,
      handle_html: 1,
      rewrite_url: 1
    ]

  alias Phoenix.HTML

  defstruct url: "",
            alt: "",
            caption: nil

  @type t :: %__MODULE__{
          url: String.t(),
          alt: String.t(),
          caption: HTML.safe() | nil
        }

  @spec from_api(map) :: t
  def from_api(%{"alt" => alt, "url" => url} = data) do
    %__MODULE__{
      url: rewrite_url(url),
      alt: alt,
      caption: data |> field_value("field_image_caption") |> handle_caption()
    }
  end

  @spec handle_caption(String.t() | nil) :: HTML.safe() | nil
  defp handle_caption(nil), do: nil
  defp handle_caption(caption), do: handle_html(caption)
end
