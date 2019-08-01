defmodule Content.Field.ImageTest do
  use ExUnit.Case, async: true

  describe "from_api/1" do
    test "maps image api data to a struct" do
      image_data = %{
        "target_id" => 1,
        "alt" => "Purple Train",
        "title" => "",
        "width" => "800",
        "height" => "600",
        "target_type" => "file",
        "target_uuid" => "universal-unique-identifier",
        "url" => "http://example.com/files/purple-train.jpeg",
        "mime_type" => "image/jpeg"
      }

      image = Content.Field.Image.from_api(image_data)

      assert image.alt == image_data["alt"]
      assert %URI{host: "localhost", path: "/files/purple-train.jpeg"} = URI.parse(image.url)
    end
  end
end
