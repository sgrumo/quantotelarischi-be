defmodule QuantomelarischioWeb.RoomChannel do
  alias Quantomelarischio.Rooms
  use QuantomelarischioWeb, :channel

  @impl true
  def join("room:" <> room_id, _params, socket) do
    user_id = socket.assigns.user_id

    case Rooms.join_room(room_id, user_id) do
      {:ok, users} ->
        socket = assign(socket, :room_id, room_id)
        #        broadcast_from(socket, "user_joined", %{users: users})
        {:ok, %{users: users}, socket}

      {:error, :room_full} ->
        {:error, %{reason: "Room is full"}}

      {:error, :user_already_inside} ->
        {:error, %{reason: "User is already inside the room"}}
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
end
