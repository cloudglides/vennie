defmodule Commands.Utils do
  alias Nostrum.Api
  require Logger

  @supported_languages %{
    "python" => "python",
    "javascript" => "javascript",
    "cpp" => "cpp",
    "c" => "c",
    "rust" => "rust"
  }

  @doc """
  Parses the incoming message arguments for a code block and executes the code.
  """
  def execute(%{msg: msg, args: args}) do
    case parse_code_block(args) do
      {:ok, language, code} ->
        execute_code(msg, language, code)
      
      {:error, reason} ->
        Api.Message.create(
          msg.channel_id,
          content: reason,
          message_reference: %{message_id: msg.id}
        )
    end
  end

  # Join args with newlines and extract the language and code block.
  defp parse_code_block(args) do
    full_text = Enum.join(args, "\n")
    
    case Regex.run(~r/```(\w+)\n(.*?)```/sm, full_text) do
      [_, lang, code] ->
        normalized_lang = String.downcase(lang)
        if Map.has_key?(@supported_languages, normalized_lang) do
          {:ok, normalized_lang, String.trim(code)}
        else
          {:error, "Unsupported language. Supported languages: #{Map.keys(@supported_languages) |> Enum.join(", ")}"}
        end
      nil ->
        {:error, "Please provide a code block with a language specifier (e.g., ```python\nprint('Hello')\n```)"}
    end
  end

  # Execute the code by sending it to glot.io.
  defp execute_code(msg, language, code) do
    case send_to_execution_service(language, code) do
      {:ok, %{"output" => output, "error" => error}} ->
        response = prepare_response(output, error)
        Api.Message.create(
          msg.channel_id,
          content: "```\n#{response}\n```",
          message_reference: %{message_id: msg.id}
        )
      {:error, reason} ->
        Api.Message.create(
          msg.channel_id,
          content: "Execution failed: #{reason}",
          message_reference: %{message_id: msg.id}
        )
    end
  end

  # Use glot.io's API to run the code.
  defp send_to_execution_service(language, code) do
    # Build the endpoint using the glot.io language slug.
    endpoint = "https://run.glot.io/languages/#{@supported_languages[language]}/latest"
    token = System.get_env("GLOT_TOKEN") || "your_api_token_here"
    
    # The API expects a JSON payload with a "files" key.
    payload = Jason.encode!(%{"files" => [%{"name" => "main", "content" => code}]})
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Token #{token}"}
    ]

    case HTTPoison.post(endpoint, payload, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, result} ->
            # glot.io returns "stdout" and "stderr"
            output = Map.get(result, "stdout", "")
            error = Map.get(result, "stderr", "")
            {:ok, %{"output" => output, "error" => error}}
          {:error, decode_error} ->
            {:error, "Failed to decode response: #{inspect(decode_error)}"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, "Service returned status #{code}: #{body}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  # Format the output, combining stdout and stderr if necessary.
  defp prepare_response(output, error) do
    full_response =
      if error not in [nil, ""] do
        "Error:\n#{error}\n\nOutput:\n#{output}"
      else
        output
      end

    String.slice(full_response, 0, 1900)
  end

  # Websocket utility remains unchanged.
  def websocket(%{msg: msg, args: _args}) do
    case Vennie.GatewayTracker.get_state() do
      nil ->
        Api.Message.create(msg.channel_id, "WebSocket details not available yet!")
      ws_state ->
        details =
          ws_state
          |> inspect(pretty: true)
          |> String.slice(0, 1900)

        Api.Message.create(msg.channel_id, "```elixir\n#{details}```")
    end
  end
end

