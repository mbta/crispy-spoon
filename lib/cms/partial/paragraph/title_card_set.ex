defmodule CMS.Partial.Paragraph.TitleCardSet do
  @moduledoc """
  DEPRECATED. This paragraph type is being retained for historical purposes
  (which is why we're not pulling it), but it is no longer used in any current
  CMS content (and can no longer be added via the CMS). Use Descriptive Links
  within a  Multi Column layout instead.
  """
  alias CMS.Partial.Paragraph.DescriptiveLink

  defstruct descriptive_links: []

  @type t :: %__MODULE__{
          descriptive_links: [DescriptiveLink.t()]
        }

  @spec from_api(map) :: t
  def from_api(data) do
    cards =
      data
      |> Map.get("field_title_cards", [])
      |> Enum.map(&DescriptiveLink.from_api/1)

    %__MODULE__{
      descriptive_links: cards
    }
  end
end
