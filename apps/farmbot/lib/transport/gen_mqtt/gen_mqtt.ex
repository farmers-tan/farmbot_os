alias Farmbot.Transport.GenMqtt.Client, as: Client
alias Experimental.GenStage
defmodule Farmbot.Transport.GenMqtt do
  use GenStage
  require Logger
  alias Farmbot.Token
  @type state :: {pid | nil, Token.t | nil}

  @doc """
    Starts the handler that watches the mqtt client
  """
  @spec start_link :: {:ok, pid}
  def start_link,
    do: GenStage.start_link(__MODULE__, {nil, nil}, name: __MODULE__)

  @spec init(state) :: {:consumer, state, subscribe_to: [Farmbot.Transport]}
  def init(initial) do
    case Farmbot.Auth.get_token do
      {:ok, %Token{} = t} ->
        {:ok, pid} = Client.start_link(t)
        {:consumer, {pid, t}, subscribe_to: [Farmbot.Transport]}
      _ ->
      {:consumer, initial, subscribe_to: [Farmbot.Transport]}
    end
  end

  # GenStage callback.
  def handle_events(_events, _, {_, nil} = state) do
    # we don't have auth yet, so dont do anything with this event.
    {:noreply, [], state}
  end

  def handle_events(events, _, {client, %Token{} = _} = state) do
    for event <- events do
      do_handle(event, client)
    end
    {:noreply, [], state}
  end

  @spec do_handle(any, pid | nil) :: no_return
  defp do_handle(event, client)
    when is_pid(client), do: Client.cast(client, event)

  defp do_handle(_event, _client), do: :ok

  def handle_info({:authorization, %Token{} = t}, {nil, _}) do
    {:ok, pid} = start_client(t)
    {:noreply, [], {pid, t}}
  end

  def handle_info({:authorization, %Token{} = _t}, state) do
    # Probably a good idea to restart mqtt here.
    {:noreply, [], state}
  end

  defp start_client(%Token{} = token), do: Client.start_link(token)
end