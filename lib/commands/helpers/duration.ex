defmodule Commands.Helpers.Duration do
  def parse_duration(duration_str) do
    with [_, amount, unit] <- Regex.run(~r/^(\d+)([smhd])$/, duration_str) do
      amount = String.to_integer(amount)

      case unit do
        "s" -> amount
        "m" -> amount * 60
        "h" -> amount * 3600
        "d" -> amount * 86400
        _ -> raise ArgumentError, "Unsupported duration unit: #{unit}"
      end
    else
      _ -> raise ArgumentError, "Invalid duration format: #{duration_str}"
    end
  end
end