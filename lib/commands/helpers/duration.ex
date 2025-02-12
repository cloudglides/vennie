defmodule Commands.Helpers.Duration do
  def parse_duration("1h"), do: 3600
  def parse_duration("30m"), do: 1800
  def parse_duration("1d"), do: 86400
  def parse_duration("7d"), do: 604800
  def parse_duration(duration_str) do
    raise ArgumentError, "Unsupported duration: #{duration_str}"
  end
end
