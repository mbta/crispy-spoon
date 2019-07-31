defmodule CMS.Partial.Paragraph.ContentListTest do
  @moduledoc """
  Tests struct-specific construction logic. Helper functions in this file
  build minimum-viable CMS API response JSON data from the CMS field name
  minus the "field_" prefix, followed by a typical value one would find.
  """

  use ExUnit.Case, async: true

  alias CMS.Partial.Paragraph.ContentList

  describe "from_api/1" do
    test "If type is specified, it should result in a single-item list" do
      opts = cms_map(content_type: "news_entry")

      assert opts == [type: [:news_entry]]
    end

    test "If no type is specified, it should not be present in opts[]" do
      opts = cms_map(content_type: "")

      assert opts == []
    end

    test "If no relationship data is found, discard all related data" do
      opts =
        cms_map(
          relationship: nil,
          except: nil,
          parent_id: 5678
        )

      assert opts == []
    end

    test "If author has selected 'except,' update relationship type" do
      opts =
        cms_map(
          relationship: nil,
          content_reference: 1234,
          content_logic: "except"
        )

      assert opts == [except: 1234]
    end

    test "If relating by host page, discard content ID and update relationship type" do
      opts =
        cms_map(
          relationship: "host",
          content_reference: 1234,
          parent_id: 5678
        )

      assert opts == [related_to: 5678]
    end

    test "If a specific content ID is present, use that and discard the host page ID" do
      opts =
        cms_map(
          relationship: "related_to",
          content_reference: 1234,
          parent_id: 5678
        )

      assert opts == [related_to: 1234]
    end

    test "If a specific content ID is not present, use the default host_id and discard placeholders" do
      opts =
        cms_map(
          relationship: "except",
          content_reference: nil,
          parent_id: 5678
        )

      assert opts == [except: 5678]
    end

    test "If no terms are found, discard term and depth data" do
      opts =
        cms_map(
          terms: nil,
          term_depth: 4
        )

      assert opts == []
    end

    test "If the default term depth is found, discard depth and compose arguments" do
      opts =
        cms_map(
          terms: [123, 321],
          term_depth: 4
        )

      assert opts == [args: [123, 321]]
    end

    test "If we are using a non-standard depth, all arguments must be set if terms are present" do
      no_terms = cms_map(terms: nil, term_depth: 3)
      one_term = cms_map(terms: [123], term_depth: 3)
      two_terms = cms_map(terms: [123, 321], term_depth: 3)

      assert no_terms == []
      assert one_term == [args: [123, "any", 3]]
      assert two_terms == [args: [123, 321, 3]]
    end
  end

  test "Discard date information if no date operator has been set" do
    opts =
      cms_map(
        date: "2019-03-14",
        date_max: nil,
        date_logic: nil
      )

    assert opts == []
  end

  test "Use absolute date if date operator and date are specified" do
    opts =
      cms_map(
        date: "2018-08-08",
        date_max: nil,
        date_logic: ">="
      )

    assert opts == [date: [value: "2018-08-08"], date_op: ">="]
  end

  test "Use relative time if date operator is specified without specific date" do
    opts =
      cms_map(
        date: nil,
        date_max: nil,
        date_logic: ">="
      )

    assert opts == [date: [value: "now"], date_op: ">="]
  end

  test "Use min and max date range when operator is 'between'" do
    opts =
      cms_map(
        date: "2020-02-20",
        date_max: "2030-03-30",
        date_logic: "between"
      )

    assert opts == [date: [min: "2020-02-20", max: "2030-03-30"], date_op: "between"]
  end

  test "Discards date criteria when 'between' operator is specified without min/max values" do
    opts =
      cms_map(
        date: "2020-02-20",
        date_max: nil,
        date_logic: "between"
      )

    assert opts == []
  end

  test "Discards all nil and irrelevant values" do
    opts =
      cms_map(
        terms: nil,
        term_depth: 4,
        number_of_items: 5,
        content_type: "event",
        type_logic: nil,
        promoted: nil,
        sticky: nil,
        relationship: nil,
        content_logic: nil,
        content_reference: nil,
        parent_id: 5678,
        date: nil,
        date_max: nil,
        date_logic: nil,
        sorting: nil,
        sorting_logic: nil
      )

    assert opts == [items_per_page: 5, type: [:event]]
  end

  defp cms_map(fields) do
    fields
    |> Enum.into(%{}, &cms_field/1)
    |> ContentList.from_api()
    |> Map.get(:recipe)
  end

  defp cms_field({k, nil}) do
    {"field_#{k}", []}
  end

  defp cms_field({:content_reference = k, v}) do
    {"field_#{k}", [%{"target_id" => v}]}
  end

  defp cms_field({:parent_id = k, v}) do
    {"#{k}", [%{"value" => v}]}
  end

  defp cms_field({:terms = k, terms}) do
    {"field_#{k}", Enum.map(terms, &%{"target_id" => &1})}
  end

  defp cms_field({k, v}) do
    {"field_#{k}", [%{"value" => v}]}
  end
end
