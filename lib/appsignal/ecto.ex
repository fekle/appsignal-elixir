defmodule Appsignal.Ecto do
  @tracer Application.get_env(:appsignal, :appsignal_tracer, Appsignal.Tracer)
  @span Application.get_env(:appsignal, :appsignal_span, Appsignal.Span)
  import Appsignal.Utils, only: [module_name: 1]

  def attach do
    otp_app =
      :appsignal
      |> Application.get_env(:config, %{})
      |> Map.get(:otp_app, nil)

    otp_app
    |> Application.get_env(:ecto_repos, [])
    |> Enum.each(&attach(otp_app, &1))
  end

  def attach(otp_app, repo) do
    event = telemetry_prefix(otp_app, repo) ++ [:query]
    :telemetry.attach({__MODULE__, event}, event, &query/4, :ok)
  end

  defp telemetry_prefix(otp_app, repo) do
    case otp_app
         |> Application.get_env(repo, [])
         |> Keyword.get(:telemetry_prefix) do
      prefix when is_list(prefix) ->
        prefix

      _ ->
        repo
        |> Module.split()
        |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))
    end
  end

  defp query(_event, _measurements, %{repo: repo}, _config) do
    "http_request"
    |> @tracer.create_span(@tracer.current_span())
    |> @span.set_name("Query #{module_name(repo)}")
    |> @span.set_attribute("appsignal:category", "ecto.query")
  end
end
