defmodule DotcomWeb.CustomerSupportController do
  @moduledoc "Handles the customer support page and form submissions."

  use DotcomWeb, :controller

  require Logger

  alias Routes.Route

  @allowed_attachment_types ~w(image/bmp image/gif image/jpeg image/png image/tiff image/webp)
  # Max 6 files per ticket, max 2 MB for single attachment
  @file_count_limit 6
  @file_size_limit 2_097_152

  @content_blocks [
    %{
      header: %{text: "Call Us", iconSvgText: nil},
      id: "call_us",
      initially_expanded: true
    },
    %{
      header: %{text: "ADA/Accessibility Complaints", iconSvgText: nil},
      id: "accessibility",
      initially_expanded: true
    },
    %{
      header: %{text: "Lost and Found", iconSvgText: nil},
      id: "lost_and_found",
      initially_expanded: true
    },
    %{
      header: %{text: "Get Service Updates", iconSvgText: nil},
      id: "service_updates",
      initially_expanded: true
    },
    %{
      header: %{text: "Transit Police", iconSvgText: nil},
      id: "transit_police",
      initially_expanded: false
    },
    %{
      header: %{text: "Request Public Records", iconSvgText: nil},
      id: "request_public_records",
      initially_expanded: false
    },
    %{
      header: %{text: "Write to Us", iconSvgText: nil},
      id: "write_to_us",
      initially_expanded: false
    },
    %{
      header: %{text: "Report Fraud, Waste, or Abuse", iconSvgText: nil},
      id: "report",
      initially_expanded: false
    },
    %{
      header: %{text: "Report a Railroad Crossing Gate Issue", iconSvgText: nil},
      id: "rail_road",
      initially_expanded: false
    }
  ]

  @support_datetime_selector_fields %{
    controls: "support-datepicker",
    year: "support_date_time_year",
    month: "support_date_time_month",
    day: "support_date_time_day",
    hour: "support_date_time_hour",
    minute: "support_date_time_minute",
    amPm: "support_date_time_am_pm",
    dateEl: %{
      container: "support-date",
      input: "support-date-input",
      select: "support-date-select",
      label: "support-date-label"
    },
    timeEl: %{
      container: "support-time",
      select: "support-time-select",
      label: "support-time-label"
    }
  }

  @routes_repo Application.compile_env!(:dotcom, :repo_modules)[:routes]

  plug(:set_service_options)
  plug(:assign_ip)
  plug(:meta_description)
  plug(:assign_datetime_selector_fields)
  plug(:assign_all_options_per_mode)

  def index(conn, params) do
    comments = Map.get(params, "comments", nil)
    render_form(conn, %{comments: comments})
  end

  def thanks(conn, _params) do
    render(
      conn,
      "index.html",
      breadcrumbs: [Breadcrumb.build("Customer Support")],
      show_form: false
    )
  end

  def submit(conn, %{"support" => form_data, "g-recaptcha-response" => recaptcha_response}) do
    now = Util.now() |> Util.to_local_time() |> DateTime.truncate(:second)

    params =
      form_data
      |> Map.put("recaptcha_response", recaptcha_response)
      # date and time is not mandatory so if it's blank or in the future, we set it to now
      |> Map.update("date_time", now, &validate_incident_date_time/1)

    case do_validation(params) do
      [] ->
        do_submit(conn, params)

      errors ->
        _ = Logger.warning("#{__MODULE__} form validation failed: #{inspect(errors)}")

        conn
        |> put_status(400)
        |> render_form(%{errors: errors, comments: Map.get(params, "comments")})
    end
  end

  def submit(conn, params) do
    Logger.warning("recaptcha validation missing")

    comments =
      case params do
        %{"support" => form_data} ->
          Map.get(form_data, "comments", nil)

        _ ->
          nil
      end

    conn
    |> put_status(400)
    |> render_form(%{errors: ["recaptcha"], comments: comments})
  end

  @spec render_expandable_blocks(Plug.Conn.t(), list) :: [Phoenix.HTML.safe()]
  def render_expandable_blocks(assigns, content_blocks \\ @content_blocks) do
    content_blocks
    |> Enum.map(fn block ->
      view_template = "_#{block.id}.html"

      try do
        Phoenix.View.render(
          DotcomWeb.CustomerSupportView,
          view_template,
          Map.merge(assigns, %{
            header: block.header,
            id: block.id,
            initially_expanded: block.initially_expanded,
            layout: {DotcomWeb.PartialView, "_expandable_block.html"}
          })
        )
      rescue
        # We still want to render the page, so we just return empty content:
        _ -> ""
      end
    end)
  end

  @spec do_submit(Plug.Conn.t(), map) :: Plug.Conn.t()
  defp do_submit(%Plug.Conn{assigns: %{ip_address: {:ok, ip}}} = conn, data) do
    rate_limit_interval = Application.get_env(:dotcom, :feedback_rate_limit, 60_000)

    case Hammer.check_rate("submit-feedback:#{ip}", rate_limit_interval, 1) do
      {:allow, _count} ->
        attachments = photo_attachments(data["photos"])
        {:ok, pid} = Task.start(__MODULE__, :send_ticket, [data, attachments])
        conn = Plug.Conn.put_private(conn, :ticket_task, pid)
        redirect(conn, to: customer_support_path(conn, :thanks))

      {:deny, _limit} ->
        _ = Logger.warning("ip=#{ip} Support form rate limit exceeded for IP address")

        conn
        |> put_status(:too_many_requests)
        |> render_form(%{errors: ["rate limit"]})
    end
  end

  @spec photo_attachments([Plug.Upload.t()]) :: [%{path: String.t(), filename: String.t()}] | nil
  defp photo_attachments([%Plug.Upload{} | _rest] = photos) do
    attachments =
      Enum.reduce(photos, [], fn %Plug.Upload{path: path, filename: filename}, acc ->
        with {:ok, uploaded_file} <- File.read(path),
             {:ok, %File.Stat{size: size}} when size <= @file_size_limit <- File.stat(path) do
          [{simple_filename(filename), uploaded_file} | acc]
        else
          {:error, file_error} ->
            # Sometimes a file isn't successfully uploaded. Ignore it here so that we can still send the email
            _ =
              Logger.warning(
                "module=#{__MODULE__} error=#{:file.format_error(file_error)} failed_photo_attachment"
              )

            acc

          _ ->
            acc
        end
      end)

    if Enum.empty?(attachments), do: nil, else: Enum.take(attachments, @file_count_limit)
  end

  defp photo_attachments(nil), do: nil

  defp simple_filename(name), do: String.replace(name, ~r/(\s)+/, "-")

  defp render_form(conn, %{errors: errors, comments: comments}) do
    Logger.warning("#{__MODULE__} form validation failed: #{inspect(errors)}")

    render(
      conn,
      "index.html",
      breadcrumbs: [Breadcrumb.build("Customer Support")],
      errors: errors,
      show_form: true,
      comments: comments
    )
  end

  defp render_form(conn, %{errors: errors}) do
    Logger.warning("#{__MODULE__} form validation failed: #{inspect(errors)}")

    render(
      conn,
      "index.html",
      breadcrumbs: [Breadcrumb.build("Customer Support")],
      errors: errors,
      show_form: true
    )
  end

  defp render_form(conn, %{comments: comments}) do
    render(
      conn,
      "index.html",
      breadcrumbs: [Breadcrumb.build("Customer Support")],
      errors: [],
      show_form: true,
      comments: comments
    )
  end

  @spec do_validation(map) :: [String.t()]
  defp do_validation(params) do
    validators =
      if params["no_request_response"] == "off" do
        [
          &validate_comments/1,
          &validate_service/1,
          &validate_subject/1,
          &validate_photos/1,
          &validate_vehicle/1,
          &validate_name/1,
          &validate_email/1,
          &validate_privacy/1,
          &validate_recaptcha/1
        ]
      else
        [
          &validate_comments/1,
          &validate_service/1,
          &validate_subject/1,
          &validate_photos/1,
          &validate_vehicle/1,
          &validate_recaptcha/1
        ]
      end

    Dotcom.Validation.validate(validators, params)
  end

  @spec validate_comments(map) :: :ok | String.t()
  defp validate_comments(%{"comments" => ""}), do: "comments"
  defp validate_comments(_), do: :ok

  @spec validate_service(map) :: :ok | String.t()
  defp validate_service(%{"service" => service}) do
    if Feedback.Message.valid_service?(service) do
      :ok
    else
      "service"
    end
  end

  defp validate_service(_), do: "service"

  @spec validate_subject(map) :: :ok | String.t()
  defp validate_subject(%{"subject" => subject, "service" => service}) do
    if Feedback.Message.valid_subject_for_service?(subject, service) do
      :ok
    else
      "subject"
    end
  end

  defp validate_subject(_), do: "subject"

  @spec validate_name(map) :: :ok | String.t()
  defp validate_name(%{"first_name" => ""}), do: "first_name"
  defp validate_name(%{"last_name" => ""}), do: "last_name"
  defp validate_name(_), do: :ok

  @spec validate_email(map) :: :ok | String.t()
  defp validate_email(%{"email" => email}) do
    case Regex.run(~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/, email) do
      nil -> "email"
      [_] -> :ok
    end
  end

  defp validate_email(_), do: "email"

  @spec validate_privacy(map) :: :ok | String.t()
  defp validate_privacy(%{"privacy" => "on"}), do: :ok
  defp validate_privacy(_), do: "privacy"

  @spec validate_vehicle(map) :: :ok | String.t()
  defp validate_vehicle(%{"vehicle" => vehicle_number}) when vehicle_number != "" do
    if Regex.match?(~r/^[0-9]{0,8}$/, vehicle_number),
      do: :ok,
      else: "vehicle"
  end

  defp validate_vehicle(_), do: :ok

  @spec validate_photos(map) :: :ok | String.t()
  defp validate_photos(%{"photos" => photos}) when is_list(photos) do
    if Enum.all?(photos, &valid_upload?/1), do: :ok, else: "photos"
  end

  defp validate_photos(_), do: :ok

  defp valid_upload?(%Plug.Upload{filename: filename}) do
    MIME.from_path(filename) in @allowed_attachment_types
  end

  # Errors we'd expect to see from reCAPTCHA assuming no bugs in the library.
  # See: https://developers.google.com/recaptcha/docs/verify#error_code_reference
  @expected_recaptcha_errors [
    :challenge_failed,
    :invalid_input_response,
    :missing_input_response,
    :timeout_or_duplicate,
    # https://github.com/samueljseay/recaptcha/issues/58
    :"invalid-input-response"
  ]

  @spec validate_recaptcha(map) :: :ok | String.t()
  defp validate_recaptcha(%{"recaptcha_response" => response}) do
    case Recaptcha.verify(response) do
      {:ok, _} ->
        :ok

      {:error, [error]} when error in @expected_recaptcha_errors ->
        _ = Logger.warning("recaptcha failed_validation=#{error}")
        "recaptcha"

      {:error, [:invalid_keys]} ->
        _ = Logger.error("recaptcha invalid_keys")
        "recaptcha"

      {:error, [error]} ->
        _ = Logger.error("recaptch error=#{error}")
        "recaptcha"
    end
  end

  @spec validate_incident_date_time(map) :: DateTime.t()
  defp validate_incident_date_time(incident_date_time) do
    now = Util.now() |> Util.to_local_time() |> DateTime.truncate(:second)

    parsed_date_time =
      case Util.parse(incident_date_time) do
        {:error, :invalid_date} ->
          now

        parsed_dt ->
          parsed_dt
      end

    local_parsed_date_time = Util.convert_using_timezone(parsed_date_time, "America/New_York")

    # if date and time is in the future, set it to now
    # otherwise leave as it is

    if DateTime.compare(local_parsed_date_time, now) in [:lt, :eq] do
      local_parsed_date_time
    else
      now
    end
  end

  def send_ticket(params, attachments) do
    Feedback.Repo.send_ticket(%Feedback.Message{
      photos: attachments,
      email: params["email"],
      phone: params["phone"],
      first_name: params["first_name"],
      last_name: params["last_name"],
      comments: params["comments"],
      service: params["service"],
      subject: params["subject"],
      no_request_response: params["no_request_response"] == "on",
      ada_complaint: params["ada_complaint"] == "on",
      incident_date_time: params["date_time"],
      mode: params["mode"],
      line: params["route"],
      vehicle: params["vehicle"],
      ticket_number: params["ticket_number"]
    })
  end

  @spec get_options_per_mode :: map
  def get_options_per_mode do
    bus_ferry_cr_options =
      for route_type <- 2..4, into: %{} do
        options =
          @routes_repo.by_type(route_type)
          |> Enum.map(fn route ->
            route.name
          end)

        mode = "#{Route.type_atom(route_type)}_options"
        {mode, options}
      end

    subway_options =
      Enum.map(DotcomWeb.ViewHelpers.subway_lines() -- [:silver_line], fn mode ->
        DotcomWeb.ViewHelpers.mode_name(mode)
      end)

    bus_ferry_cr_options |> Map.put("subway_options", subway_options)
  end

  defp set_service_options(conn, _) do
    assign(conn, :service_options, Feedback.Message.service_options())
  end

  defp assign_ip(conn, _) do
    assign(conn, :ip_address, get_ip(conn))
  end

  defp get_ip(conn) do
    conn
    |> Plug.Conn.get_req_header("x-forwarded-for")
    |> do_get_ip(conn)
  end

  defp do_get_ip([<<ip::binary>>], %Plug.Conn{}) do
    {:ok, ip}
  end

  defp do_get_ip([], %Plug.Conn{remote_ip: {a, b, c, d}}) do
    {:ok, Enum.join([to_string(a), to_string(b), to_string(c), to_string(d)], ".")}
  end

  defp do_get_ip(_, %Plug.Conn{}) do
    :error
  end

  defp meta_description(conn, _) do
    conn
    |> assign(
      :meta_description,
      "Contact the MBTA customer support team and view additional contact numbers for the Transit Police, " <>
        "lost and found, and accessibility."
    )
  end

  @spec assign_datetime_selector_fields(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  defp assign_datetime_selector_fields(conn, _) do
    conn
    |> assign(:support_datetime_selector_fields, @support_datetime_selector_fields)
  end

  @spec assign_all_options_per_mode(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  defp assign_all_options_per_mode(conn, _) do
    assign(conn, :all_options_per_mode, get_options_per_mode())
  end
end
