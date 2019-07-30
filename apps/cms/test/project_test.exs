defmodule Content.ProjectTest do
  use ExUnit.Case

  import Content.CMSTestHelpers,
    only: [
      update_api_response: 3,
      update_api_response_whole_field: 3
    ]

  alias Content.{CMS.Static, Project}

  setup do
    %{
      api_data_without_path_alias: Static.project_repo() |> Enum.at(0),
      api_data_with_path_alias: Static.project_repo() |> Enum.at(1)
    }
  end

  describe "from_api/1" do
    test "maps project api data without path alias to a struct", %{
      api_data_without_path_alias: api_data
    } do
      assert %Content.Project{
               id: id,
               body: body,
               contact_information: contact_information,
               end_year: end_year,
               featured: featured,
               featured_image: %Content.Field.Image{},
               files: [],
               media_email: media_email,
               media_phone: media_phone,
               paragraphs: [paragraph | _],
               photo_gallery: [%Content.Field.Image{} | _],
               start_year: start_year,
               status: status,
               teaser: teaser,
               title: title,
               updated_on: updated_on,
               path_alias: path_alias
             } = Content.Project.from_api(api_data)

      assert id == 3004
      assert Phoenix.HTML.safe_to_string(body) =~ "<p>Major accessibility improvements,"
      assert contact_information == "MBTA Customer Support"
      assert end_year == "2020"
      assert featured == true
      assert media_email == "wollaston@mbta.com"
      assert media_phone == "617-222-3200"
      assert start_year == "2017"
      assert status == "Construction"
      assert teaser =~ "Wollaston Station will be completely renovated to become an accessible,"
      assert title == "Wollaston Station Improvements"
      assert updated_on == ~D[2018-04-02]
      assert path_alias == nil
      assert %Content.Paragraph.CustomHTML{} = paragraph
    end

    test "maps project api data with path alias to a struct", %{
      api_data_with_path_alias: api_data
    } do
      assert %Content.Project{
               path_alias: path_alias
             } = Content.Project.from_api(api_data)

      assert path_alias == "/projects/project-name"
    end

    test "when files are provided", %{api_data_without_path_alias: api_data} do
      project_data =
        api_data
        |> update_api_response_whole_field("field_files", file_api_data())

      project = Content.Project.from_api(project_data)

      assert [%Content.Field.File{}] = project.files
    end

    test "when a project is featured", %{api_data_without_path_alias: api_data} do
      project_data =
        api_data
        |> update_api_response_whole_field("field_featured_image", image_api_data())
        |> update_api_response("field_featured", true)

      project = Content.Project.from_api(project_data)

      assert %Content.Field.Image{} = project.featured_image
      assert project.featured == true
    end

    test "when photo gallery images are provided", %{api_data_without_path_alias: api_data} do
      project_data =
        api_data
        |> update_api_response_whole_field("field_photo_gallery", image_api_data())

      project = Content.Project.from_api(project_data)

      assert [%Content.Field.Image{}] = project.photo_gallery
    end
  end

  describe "contact?/1" do
    test "when no contact info provided, returns false" do
      project = %Content.Project{id: 1}
      refute Content.Project.contact?(project)
    end

    test "when contact_information is provided, returns true" do
      project = %Content.Project{id: 1, contact_information: "provided"}
      assert Content.Project.contact?(project)
    end

    test "when media_email is provided, returns true" do
      project = %Content.Project{id: 1, media_email: "provided"}
      assert Content.Project.contact?(project)
    end

    test "when media_phone is provided, returns true" do
      project = %Content.Project{id: 1, media_phone: "provided"}
      assert Content.Project.contact?(project)
    end
  end

  describe "alias/1" do
    test "returns the bare project alias when a path_alias exists" do
      project = %Project{id: 1234, path_alias: "/projects/alias"}
      assert Project.alias(project) == "alias"
    end

    test "returns project id when path alias does not exist" do
      assert Project.alias(%Project{id: 1234}) == 1234
    end
  end

  defp image_api_data do
    [
      %{
        "alt" => "image alt",
        "url" => "http://example.com/files/train.jpeg"
      }
    ]
  end

  defp file_api_data do
    [
      %{
        "description" => "important file",
        "url" => "http://example.com/files/important.txt",
        "mime_type" => "text/plain"
      }
    ]
  end
end
