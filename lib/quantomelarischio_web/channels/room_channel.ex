defmodule QuantomelarischioWeb.RoomChannel do
  alias QuantomelarischioWeb.Channels.Handlers.BetHandler
  alias Quantomelarischio.Rooms
  use QuantomelarischioWeb, :channel

  @possible_messages [
    "send_challenge",
    "accept_challenge",
    "decline_challenge",
    "place_bet",
    "forfeit_bet",
    "reset_game"
  ]
  @impl true
  def join("room:" <> room_id, _params, socket) do
    user_id = socket.assigns.user_id

    case Rooms.join_room(room_id, user_id) do
      {:ok, roomInfo} ->
        socket = assign(socket, :room_id, room_id)
        send(self(), {:after_join, roomInfo})
        {:ok, %{roomInfo: roomInfo, userId: user_id}, socket}

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
      {:reply, {:ok, socket}} -> {:reply, :ok, socket}
      _ -> {:reply, {:error, %{reason: "Error in handling"}}, socket}
    end
  end

  @impl true
  def handle_info({:after_join, payload}, socket) do
    broadcast_from!(socket, "user_joined", payload)
    {:noreply, socket}
  end
end
