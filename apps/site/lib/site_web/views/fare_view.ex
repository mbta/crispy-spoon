defmodule SiteWeb.FareView do
  @moduledoc """
  View for the Fares section of the website.
  """
  use SiteWeb, :view

  alias CMS.Field.Link

  alias CMS.Partial.Paragraph.{
    Description,
    DescriptionList
  }

  alias Fares.Summary
  alias GoogleMaps.Geocode.Address
  alias Phoenix.HTML
  alias Plug.Conn
  alias Routes.Route
  alias SiteWeb.PartialView.SvgIconWithCircle

  @doc "Renders a summary of fares into HTML"
  @spec summarize([Summary.t()], Keyword.t()) :: HTML.safe()
  def summarize(summaries, opts \\ []) do
    render("_summary.html",
      summaries: summaries,
      class: opts[:class],
      link_class: Keyword.get(opts, :link_class, "")
    )
  end

  @spec summary_url(Summary.t()) :: String.t()
  def summary_url(%Summary{url: url}) when not is_nil(url), do: url

  def summary_url(%Summary{modes: [subway_or_bus | _], duration: duration})
      when subway_or_bus in [:subway, :bus] do
    anchor =
      cond do
        duration in ~w(day week)a -> "#7-day"
        duration in ~w(month)a -> "#monthly"
        true -> ""
      end

    do_summary_url(subway_or_bus, anchor)
  end

  def summary_url(%Summary{modes: [mode | _]}) do
    do_summary_url(mode)
  end

  @spec do_summary_url(atom, String.t()) :: String.t()
  defp do_summary_url(name, anchor \\ "") do
    fare_path(SiteWeb.Endpoint, :show, SiteWeb.StaticPage.convert_path(name) <> "-fares") <>
      anchor
  end

  @spec fare_passes(Route.gtfs_route_type()) :: DescriptionList.t()
  def fare_passes(:subway) do
    %DescriptionList{
      descriptions: [
        %Description{
          term: fare_pass_name("7-Day Pass"),
          details: fare_pass_price("{{fare:subway:week}}")
        },
        %Description{
          term: fare_pass_name("Monthly LinkPass"),
          details: fare_pass_price("{{fare:subway:month}}")
        }
      ]
    }
  end

  def fare_passes(:bus) do
    %DescriptionList{
      descriptions: [
        %Description{
          term: fare_pass_name("Express Bus One-Way"),
          details: fare_pass_price("{{fare:express_bus:charlie_card}}")
        },
        %Description{
          term: fare_pass_name("Monthly LinkPass"),
          details: fare_pass_price("{{fare:local_bus:month}}")
        },
        %Description{
          term: fare_pass_name("7-Day Pass"),
          details: fare_pass_price("{{fare:subway:week}}")
        }
      ]
    }
  end

  def fare_passes(:commuter_rail) do
    %DescriptionList{
      descriptions: [
        %Description{
          term: fare_pass_name("Commuter Rail Monthly Pass"),
          details: fare_pass_price("{{fare:commuter_rail:month:commuter_ticket}}")
        }
      ]
    }
  end

  def fare_passes(:ferry) do
    %DescriptionList{
      descriptions: [
        %Description{
          term: fare_pass_name("Ferry Monthly Pass"),
          details: fare_pass_price("{{fare:ferry:month:charlie_ticket}}")
        }
      ]
    }
  end

  @spec fare_pass_name(String.t()) :: HTML.safe()
  defp fare_pass_name(name), do: content_tag(:h3, name, class: "c-fare-pass__name")

  @spec fare_pass_price(String.t()) :: HTML.safe()
  defp fare_pass_price(price), do: content_tag(:span, price, class: "h2 c-fare-pass__price")

  @spec fare_overview_link(Route.gtfs_route_type(), Conn.t()) :: HTML.safe()
  def fare_overview_link(mode, conn) do
    link(
      "View fares overview",
      to:
        cms_static_page_path(
          conn,
          "/fares/#{mode |> Atom.to_string() |> String.replace("_", "-")}-fares"
        ),
      class: "c-call-to-action"
    )
  end

  defp input_value(%Address{formatted: address}) do
    address
  end

  defp input_value(_) do
    ""
  end
end
