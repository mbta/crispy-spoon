defmodule DotcomWeb.LayoutView do
  use DotcomWeb, :view
  import Util.BreadcrumbHTML, only: [breadcrumb_trail: 1, title_breadcrumbs: 1]
  import DotcomWeb.SearchHelpers, only: [desktop_form: 2]

  def bold_if_active(DotcomWeb.Endpoint, _, text) do
    raw(text)
  end

  def bold_if_active(%Plug.Conn{} = conn, path, text) do
    requested_path = Enum.at(String.split(conn.request_path, "/"), 1)

    if requested_path == String.trim(path, "/") do
      raw("<strong>#{text}</strong>")
    else
      raw(text)
    end
  end

  defp has_styleguide_subpages?(%{params: %{"section" => "content"}}), do: true
  defp has_styleguide_subpages?(%{params: %{"section" => "components"}}), do: true
  defp has_styleguide_subpages?(_), do: false

  @spec styleguide_main_content_class(map) :: String.t()
  def styleguide_main_content_class(%{all_subpages: _}), do: " col-md-10"
  def styleguide_main_content_class(_), do: ""

  def get_page_classes(module, template) do
    module_class =
      module
      |> Module.split()
      |> Enum.slice(1..-1//1)
      |> Enum.join("-")
      |> String.downcase()

    template_class = template |> String.replace(".html", "-template")

    "#{module_class} #{template_class}"
  end

  def nav_link_content,
    do: [
      %{
        menu_section: "Transit",
        link: ~p"/menu#Transit-section",
        sub_menus: [
          %{
            sub_menu_section: "Modes of Transit",
            links: [
              {"Subway", "/schedules/subway", :internal_link},
              {"Bus", "/schedules/bus", :internal_link},
              {"Commuter Rail", "/schedules/commuter-rail", :internal_link},
              {"Ferry", "/schedules/ferry", :internal_link},
              {"Paratransit (The RIDE)", "/accessibility/the-ride", :internal_link},
              {"All Schedules & Maps", "/schedules", :internal_link}
            ]
          },
          %{
            sub_menu_section: "Plan Your Journey",
            links: [
              {"Trip Planner", "/trip-planner", :internal_link},
              {"Service Alerts", "/alerts", :internal_link},
              {"Sign Up for Service Alerts", "https://alerts.mbta.com/", :external_link},
              {"Parking", "/parking", :internal_link},
              {"Bikes", "/bikes", :internal_link},
              {"User Guides", "/guides", :internal_link},
              {"Holidays", "/holidays", :internal_link},
              {"Accessibility", "/accessibility", :internal_link}
            ]
          },
          %{
            sub_menu_section: "Find a Location",
            links: [
              {"Find Nearby Transit", "/transit-near-me", :internal_link},
              {"MBTA Stations", "/stops", :internal_link},
              {"Destinations", "/destinations", :internal_link},
              {"Maps", "/maps", :internal_link}
            ]
          }
        ]
      },
      %{
        menu_section: "Fares",
        link: ~p"/menu#Fares-section",
        sub_menus: [
          %{
            sub_menu_section: "Fares Info",
            links: [
              {"Fares Overview", "/fares", :internal_link},
              {"Reduced Fares", "/fares/reduced", :internal_link},
              {"Transfers", "/fares/transfers", :internal_link},
              {"Fare Transformation", "/fare-transformation", :internal_link}
            ]
          },
          %{
            sub_menu_section: "Fares by Mode",
            links: [
              {"Subway Fares", "/fares/subway-fares", :internal_link},
              {"Bus Fares", "/fares/bus-fares", :internal_link},
              {"Commuter Rail Fares", "/fares/commuter-rail-fares", :internal_link},
              {"Ferry Fares", "/fares/ferry-fares", :internal_link}
            ]
          },
          %{
            sub_menu_section: "Pay Your Fare",
            links: [
              {"Charlie Service Center", "/fares/charliecard-store", :internal_link},
              {"Sign up for Auto-pay", "https://mycharlie.mbta.com/", :external_link},
              {"Order Monthly Passes", "https://commerce.mbta.com/", :external_link},
              {"Get a CharlieCard", "/fares/charliecard#getacharliecard", :internal_link},
              {"Retail Sales Locations", "/fares/retail-sales-locations", :internal_link}
            ]
          },
          # special
          %{sub_menu_section: "Most popular fares"}
        ]
      },
      %{
        menu_section: "Contact",
        link: ~p"/menu#Contact-section",
        sub_menus: [
          %{
            sub_menu_section: "Customer Support",
            links: [
              {"Send Us Feedback", "/customer-support", :internal_link},
              {"View All Contact Numbers", "/customer-support#customer_support", :internal_link},
              {"Request Public Records",
               "https://massachusettsdot.mycusthelp.com/WEBAPP/_rs/supporthome.aspx?lp=3&COID=64D93B66",
               :external_link},
              {"Lost & Found", "/customer-support/lost-and-found", :internal_link},
              {"Language Services", "/language-services", :internal_link}
            ]
          },
          %{
            sub_menu_section: "Transit Police",
            links: [
              {"MBTA Transit Police", "/transit-police", :internal_link},
              {"See Something, Say Something", "/transit-police/see-something-say-something",
               :internal_link}
            ]
          },
          # special
          %{sub_menu_section: "Emergency Contacts"},
          %{sub_menu_section: "Contact numbers"}
        ]
      },
      %{
        menu_section: "About",
        link: ~p"/menu#About-section",
        sub_menus: [
          %{
            sub_menu_section: "Get to Know Us",
            links: [
              {"Overview", "/mbta-at-a-glance", :internal_link},
              {"Leadership", "/leadership", :internal_link},
              {"History", "/history", :internal_link},
              {"Financials", "/financials", :internal_link},
              {"Public Meetings", "/events", :internal_link},
              {"Press Releases", "/news", :internal_link},
              {"MBTA Gift Shop", "https://www.mbtagifts.com", :external_link},
              {"Policies & Civil Rights", "/policies", :internal_link},
              {"Safety", "/safety", :internal_link},
              {"Quality, Compliance & Oversight", "/quality-compliance-oversight", :internal_link}
            ]
          },
          %{
            sub_menu_section: "Work with Us",
            links: [
              {"Careers", "/careers", :internal_link},
              {"Institutional Sales", "/pass-program", :internal_link},
              {"Business Opportunities", "/business", :internal_link},
              {"Innovation Proposals", "/innovation", :internal_link},
              {"Engineering Design Standards", "/engineering/design-standards-and-guidelines",
               :internal_link}
            ]
          },
          %{
            sub_menu_section: "Our Work",
            links: [
              {"Sustainability", "/sustainability", :internal_link},
              {"Capital Transformation", "/projects/capital-transformation-programs",
               :internal_link},
              {"Commuter Rail Positive Train Control",
               "/projects/commuter-rail-positive-train-control-ptc", :internal_link},
              {"Better Bus Project", "/projects/better-bus-project", :internal_link},
              {"All MBTA Improvement Projects", "/projects", :internal_link}
            ]
          }
        ]
      }
    ]

  def render_nav_link({link_name, href, link_host}) do
    link_content =
      if link_host == :external_link do
        [content_tag(:div, link_name), content_tag(:span, fa("external-link"))]
      else
        content_tag(:div, link_name)
      end

    attrs = ["data-nav": "link", href: href, class: "m-menu__link"]

    content_tag(
      :a,
      link_content,
      attrs
    )
  end

  @hidden_from_search_engines [
    "/org",
    "/charlie",
    "/policies/terms-use-charlie"
  ]
  @doc """
  Evaluates whether we want to show a meta tag to disable search engine crawling
  """
  @spec robots_nofollow?(String.t()) :: boolean()
  def robots_nofollow?(request_path) when request_path in @hidden_from_search_engines, do: true

  def robots_nofollow?(request_path) do
    Enum.any?(@hidden_from_search_engines, &String.starts_with?(request_path, &1 <> "/"))
  end
end
