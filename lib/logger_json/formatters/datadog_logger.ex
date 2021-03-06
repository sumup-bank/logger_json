defmodule LoggerJSON.Formatters.DatadogLogger do
  @moduledoc """
  DataDog formatter. Adhears to the DataDog
  [default standard attribute list](https://docs.datadoghq.com/logs/processing/attributes_naming_convention/#default-standard-attribute-list).
  """
  import Jason.Helpers, only: [json_map: 1]

  alias LoggerJSON.{FormatterUtils, JasonSafeFormatter}

  @behaviour LoggerJSON.Formatter

  @processed_metadata_keys ~w[pid file line function module application]a

  def format_event(level, message, timestamp, metadata, metadata_keys) do
    Map.merge(
      %{
        logger:
          json_map(
            thread_name: inspect(Keyword.get(metadata, :pid)),
            method_name: method_name(metadata)
          ),
        message: "#{IO.chardata_to_string(message)}",
        syslog:
          json_map(
            hostname: node_hostname(),
            severity: Atom.to_string(level),
            timestamp: FormatterUtils.format_timestamp(timestamp)
          )
      },
      format_metadata(metadata, metadata_keys)
    )
  end

  defp format_metadata(md, md_keys) do
    LoggerJSON.take_metadata(md, md_keys, @processed_metadata_keys)
    |> JasonSafeFormatter.format()
    |> FormatterUtils.maybe_put(:error, format_error(md))
  end

  defp format_error(md) do
    with %{reason: reason} <- FormatterUtils.format_process_crash(md) do
      json_map(stack: reason)
    end
  end

  defp method_name(metadata) do
    function = Keyword.get(metadata, :function)
    module = Keyword.get(metadata, :module)
    line = Keyword.get(metadata, :line)

    [_ | last_module] = String.split("#{module}", ".")

    "#{last_module}.#{function}::#{line}"
  end

  defp node_hostname do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end
end
