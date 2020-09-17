defmodule SiteWeb.CustomerSupportView do
  @moduledoc """
  Helper functions for handling interaction with and submitting the customer support form
  """
  use SiteWeb, :view

  import Phoenix.HTML.Tag, only: [content_tag: 2, content_tag: 3]

  def photo_info(%{
        "photo" => %Plug.Upload{path: path, filename: filename, content_type: content_type}
      }) do
    encoded =
      path
      |> File.read!()
      |> Base.encode64()

    {encoded, content_type, filename, File.stat!(path).size |> Sizeable.filesize()}
  end

  def photo_info(_) do
    nil
  end

  def show_error_message(conn) do
    conn.assigns.show_form && !Enum.empty?(conn.assigns[:errors])
  end

  @spec class_for_error(String.t(), [String.t()], String.t(), String.t()) :: String.t()
  def class_for_error(_, [], _, _), do: ""

  def class_for_error(value, errors, on_class, off_class) do
    if Enum.member?(errors, value), do: on_class, else: off_class
  end

  def preamble_text do
    content_tag(
      :div,
      [
        content_tag(
          :p,
          "Responses may take up to 5 business days. Do not use this form to report emergencies."
        ),
        content_tag(:p, "All fields with an asterisk* are required.")
      ]
    )
  end

  @spec placeholder_text(String.t()) :: String.t()
  def placeholder_text("comments"),
    do:
      "If applicable, please make sure to include the time and date of the incident, the route, and the vehicle number."

  def placeholder_text("name"), do: "Jane Smith"
  def placeholder_text("email"), do: "janesmith@email.com"
  def placeholder_text("phone"), do: "(555)-555-5555"
  def placeholder_text(_), do: ""

  @doc """
  Also see SiteWeb.ErrorHelpers.error_tag for a slightly different implementation of this functionality.
  """
  def support_error_tag(errors, field) when is_list(errors) do
    if Enum.member?(errors, field) do
      content_tag(
        :div,
        content_tag(:span, error_msg(field),
          role: "alert",
          "aria-live": "assertive",
          class: "support-#{field}-error"
        ),
        class: "error-container support-#{field}-error-container form-control-feedback"
      )
    else
      nil
    end
  end

  defp error_msg("service"), do: "Please select the type of concern."
  defp error_msg("comments"), do: "Please enter a comment to continue."
  defp error_msg("upload"), do: "Sorry. We had trouble uploading your image. Please try again."
  defp error_msg("email"), do: "Please enter a valid email."
  defp error_msg("name"), do: "Please enter your full name to continue."

  defp error_msg("privacy"),
    do: "You must agree to our Privacy Policy before submitting your feedback."

  defp error_msg("recaptcha"),
    do: "You must complete the reCAPTCHA before submitting your feedback."

  defp error_msg(_), do: "Sorry. Something went wrong. Please try again."
end
