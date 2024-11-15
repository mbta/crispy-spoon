defmodule CMS.Partial.RoutePdfTest do
  use ExUnit.Case

  import CMS.Partial.RoutePdf

  alias CMS.Partial.RoutePdf

  describe "custom?/1" do
    test "pdfs with nil text are not custom" do
      assert custom?(%RoutePdf{
               path: "/sites/default/files/route_pdfs/route087.pdf",
               date_start: ~D[2017-07-01],
               date_end: ~D[2018-01-31],
               link_text_override: nil
             }) == false
    end

    test "pdfs with empty text are not custom" do
      assert custom?(%RoutePdf{
               path: "/sites/default/files/route_pdfs/route087.pdf",
               date_start: ~D[2017-07-01],
               date_end: nil,
               link_text_override: ""
             }) == false
    end

    test "pdfs with text are custom" do
      assert custom?(%RoutePdf{
               path: "/sites/default/files/route_pdfs/route087.pdf",
               date_start: ~D[2017-07-01],
               date_end: ~D[2018-01-31],
               link_text_override: "custom text"
             }) == true
    end
  end

  describe "outdated?/2" do
    @today ~D[2018-01-01]

    test "pdfs that finished in the past are outdated" do
      assert outdated?(
               %RoutePdf{
                 path: "/sites/default/files/route_pdfs/route087.pdf",
                 date_start: ~D[2017-07-01],
                 date_end: ~D[2017-12-31]
               },
               @today
             ) == true
    end

    test "pdfs that finish today are not outdated" do
      assert outdated?(
               %RoutePdf{
                 path: "/sites/default/files/route_pdfs/route087.pdf",
                 date_start: ~D[2017-07-01],
                 date_end: ~D[2018-01-01]
               },
               @today
             ) == false
    end

    test "pdfs that finished in the future are not outdated" do
      assert outdated?(
               %RoutePdf{
                 path: "/sites/default/files/route_pdfs/route087.pdf",
                 date_start: ~D[2017-07-01],
                 date_end: ~D[2018-02-01]
               },
               @today
             ) == false
    end

    test "pdfs that don't have an end date are not outdated" do
      assert outdated?(
               %RoutePdf{
                 path: "/sites/default/files/route_pdfs/route087.pdf",
                 date_start: ~D[2017-07-01],
                 date_end: nil
               },
               @today
             ) == false
    end
  end

  describe "started?/2" do
    @today ~D[2018-01-01]

    test "pdfs that start in the past have started" do
      assert started?(
               %RoutePdf{
                 path: "/sites/default/files/route_pdfs/route087.pdf",
                 date_start: ~D[2017-07-01]
               },
               @today
             ) == true
    end

    test "pdfs that start today have started" do
      assert started?(
               %RoutePdf{
                 path: "/sites/default/files/route_pdfs/route087.pdf",
                 date_start: ~D[2018-01-01]
               },
               @today
             ) == true
    end

    test "pdfs that start in the future have not started" do
      assert started?(
               %RoutePdf{
                 path: "/sites/default/files/route_pdfs/route087.pdf",
                 date_start: ~D[2018-02-01]
               },
               @today
             ) == false
    end
  end
end
