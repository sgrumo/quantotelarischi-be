defmodule QuantomelarischioWeb.RoomChannel do
  alias QuantomelarischioWeb.Channels.Handlers.BetHandler
  alias Quantomelarischio.Rooms
  use QuantomelarischioWeb, :channel

  @possible_messages ["accept_challenge", "decline_challenge", "place_bet", "forfeit_bet"]
  @impl true
  def join("room:" <> room_id, _params, socket) do
    user_id = socket.assigns.user_id

    case Rooms.join_room(room_id, user_id) do
      {:ok, users} ->
        socket = assign(socket, :room_id, room_id)
        {:ok, %{users: users}, socket}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    if room_id = socket.assigns[:room_id] do
      user_id = socket.assigns.user_id
      Rooms.leave_room(room_id, user_id)
    end

    :ok
  end

  @impl true
  def handle_in(event, payload, socket)
      when event in @possible_messages do
    case BetHandler.handle(event, payload, socket) do
      {:reply, response, socket} -> {:reply, response, socket}
      _ -> {:reply, {:error, %{reason: "Invalid handler response"}}, socket}
    end
  end
end
