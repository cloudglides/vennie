defmodule Vennie.Events.Thread do
  def thread_create(thread) do
    if thread.parent_id == @help_channel_id and is_nil(thread.member) do
      # Small delay to prevent duplicates
      Process.sleep(500)

      Nostrum.Api.create_message(thread.id, """
      Hey <a:hey:1339161785961545779>, <@#{thread.owner_id}>
      * Consider reading https://discord.com/channels/1022510020736331806/1268430786332332107 to improve your question!
      * Explain what exactly your issue is.
      * Post the full error stack trace, not just the top part!
      * Show your code!
      """)

      Logger.debug(thread)
    else
      :noop
    end
  end
end
