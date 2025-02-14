defmodule DotcomWeb.ComponentsTest do
  @moduledoc false
  use ExUnit.Case

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import DotcomWeb.Components

  describe "algolia_autocomplete" do
    test "raises an error without required ID" do
      assert_raise KeyError,
                   fn ->
                     render_component(&algolia_autocomplete/1, %{})
                   end
    end

    test "renders with AlgoliaAutocomplete hook and appropriate data attributes" do
      id = Faker.String.base64(5)
      config = "basic-config"

      html =
        render_component(&algolia_autocomplete/1, %{
          id: id,
          config_type: config
        })

      assert html =~ ~s(<div class="c-search-bar__autocomplete-results"></div>)

      assert html =~
               ~s(<div class="c-search-bar__autocomplete" data-placeholder="Search for routes, info, and more" data-config="#{config}"></div>)

      assert html =~ ~s(<div id="#{id}" phx-hook="AlgoliaAutocomplete" phx-update="ignore">)
    end
  end

  describe "error_container" do
    test "optionally shows a title" do
      assigns = %{
        title: Faker.Lorem.sentence(2),
        content: Faker.Lorem.sentence(4)
      }

      str =
        rendered_to_string(~H"""
        <.error_container title={assigns.title}>
          {assigns.content}
        </.error_container>
        """)

      assert str =~ assigns.title
      assert str =~ assigns.content

      assert rendered_to_string(~H"""
             <.error_container>{assigns.content}</.error_container>
             """) =~ assigns.content
    end
  end

  describe "bordered_container" do
    test "renders header and content with a divider line" do
      assigns = %{
        title: Faker.Lorem.sentence(1..3),
        content: Faker.Lorem.sentence(3..5)
      }

      str =
        rendered_to_string(~H"""
        <.bordered_container>
          <:heading>
            <span>{assigns.title}</span>
          </:heading>
          {assigns.content}
        </.bordered_container>
        """)

      assert str =~ assigns.title
      assert str =~ assigns.content

      assert Floki.parse_fragment!(str)
             |> Floki.find("hr")
             |> Enum.count()
    end

    test "optionally hides the dividing line" do
      assigns = %{
        title: Faker.Lorem.sentence(1..3),
        content: Faker.Lorem.sentence(3..5)
      }

      str =
        rendered_to_string(~H"""
        <.bordered_container hide_divider>
          <:heading>
            <span>{assigns.title}</span>
          </:heading>
          {assigns.content}
        </.bordered_container>
        """)

      assert str =~ assigns.title
      assert str =~ assigns.content

      assert Floki.parse_fragment!(str)
             |> Floki.find("hr") == []
    end
  end

  describe "lined_list" do
    test "shows inner block for each item" do
      assigns = %{
        items: Faker.Lorem.sentences()
      }

      rendered_items =
        rendered_to_string(~H"""
        <.lined_list :let={sentence} items={@items}>
          <p>{sentence}</p>
        </.lined_list>
        """)
        |> Floki.parse_fragment!()
        |> Floki.find("p")

      assert Enum.count(rendered_items) == Enum.count(assigns.items)
      rendered_content = Enum.flat_map(rendered_items, fn {"p", _, content} -> content end)

      for sentence <- assigns.items do
        assert sentence in rendered_content
      end
    end
  end
end
