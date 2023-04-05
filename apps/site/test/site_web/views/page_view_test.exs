defmodule SiteWeb.PageViewTest do
  use Site.ViewCase, async: true

  alias CMS.Field.{Image, Link}
  alias CMS.Partial.Banner
  alias CMS.Partial.Teaser
  alias Phoenix.HTML
  alias Plug.Conn
  alias SiteWeb.PageView

  describe "banners" do
    test "renders _banner.html for important banners" do
      banner = %Banner{
        title: "Important Banner Title",
        blurb: "Uh oh, this is very important!",
        link: %Link{url: "http://example.com/important", title: "Call to Action"},
        utm_url: "http://example.com/important?utm=stuff",
        thumb: %Image{},
        banner_type: :important
      }

      rendered = render_to_string(PageView, "_banner.html", banner: banner, conn: %Conn{})
      assert rendered =~ "Important Banner Title"
      assert rendered =~ "Uh oh, this is very important!"
      assert rendered =~ "Call to Action"
    end

    test "renders _banner.html for default banners" do
      banner = %Banner{
        title: "Default Banner Title",
        blurb: "This is not as important.",
        link: %Link{url: "http://example.com/default", title: "Call to Action"},
        utm_url: "http://example.com/important?utm=stuff",
        thumb: %Image{},
        banner_type: :default
      }

      rendered = render_to_string(PageView, "_banner.html", banner: banner, conn: %Conn{})
      assert rendered =~ "Default Banner Title"
      refute rendered =~ "This is not as important."
      refute rendered =~ "Call to Action"
    end
  end

  describe "shortcut_icons/0" do
    test "renders shortcut icons" do
      rendered = PageView.shortcut_icons() |> HTML.safe_to_string()
      icons = Floki.find(rendered, ".m-homepage__shortcut")
      assert length(icons) == 5
    end
  end

  describe "render_news_entries/1" do
    test "renders news entries", %{conn: conn} do
      now = Util.now()

      entries =
        for idx <- 1..6 do
          %Teaser{
            id: idx * 1000,
            title: "News Entry #{idx}",
            type: :news_entry,
            date: Timex.shift(now, hours: -idx),
            path: "http://example.com/news?utm=stuff",
            routes: []
          }
        end

      rendered =
        conn
        |> assign(:news, entries)
        |> PageView.render_news_entries()
        |> HTML.safe_to_string()

      assert rendered |> Floki.find(".c-news-entry") |> Enum.count() == 6
      assert rendered |> Floki.find(".c-news-entry--small") |> Enum.count() == 6
      assert rendered =~ "2000"
    end
  end

  describe "alerts/1" do
    alias Alerts.InformedEntitySet, as: IESet
    alias Alerts.Alert

    test "renders properly" do
      alerts = [
        # Filtered
        %Alert{
          effect: :lifecycle
        },
        # High Priority
        %Alert{
          effect: :suspension,
          informed_entity: %IESet{
            route: MapSet.new(["Green", "Blue"])
          }
        },
        %Alert{
          effect: :suspension,
          informed_entity: %IESet{
            route: MapSet.new(["CR-Greenbush"])
          }
        },
        %Alert{
          effect: :suspension,
          informed_entity: %IESet{
            route: MapSet.new(["505", "708"])
          }
        },
        # Accessibility
        %Alert{
          effect: :escalator_closure,
          informed_entity: %IESet{
            stop: MapSet.new(["place-sstat"])
          }
        }
      ]

      rendered = PageView.alerts(alerts) |> HTML.safe_to_string()

      # Section Headers
      assert rendered =~ "Routes With High Priority Alerts"
      assert rendered =~ "Subway"
      assert rendered =~ "Bus"
      assert rendered =~ "Commuter Rail"
      assert rendered =~ "Ferry"
      assert rendered =~ "Station Accessibility"
      assert rendered =~ "Access Issues"
      assert rendered =~ "Elevator Closures"
      assert rendered =~ "Escalator Closures"

      # Buttons
      assert rendered =~ "href=\"/alerts\""
      assert rendered =~ "See all service alerts"
      assert rendered =~ "https://alerts.mbta.com"
      assert rendered =~ "Sign up for alert notifications"

      # Section Content
      assert rendered =~ "/schedules/Green/alerts"
      assert rendered =~ "/schedules/Blue/alerts"
      assert rendered =~ "/schedules/505/alerts"
      assert rendered =~ "/schedules/708/alerts"
      assert rendered =~ "/schedules/CR-Greenbush/alerts"
      assert Regex.match?(~r/There are no high priority.*ferry.*alerts at this time/s, rendered)
      assert rendered =~ "/stops/place-sstat"
      assert rendered =~ "South Station"
      assert Regex.match?(~r/There are no.*elevator closures.*at this time/s, rendered)
      assert Regex.match?(~r/There are no.*access issues.*at this time/s, rendered)
    end
  end
end
