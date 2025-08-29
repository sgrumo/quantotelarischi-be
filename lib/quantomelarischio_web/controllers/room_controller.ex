defmodule QuantomelarischioWeb.RoomController do
  use QuantomelarischioWeb, :controller
  alias Quantomelarischio.Rooms

  def create(conn, _params) do
    case Rooms.create_room() do
      {:ok, room_id} ->
        conn
        |> put_status(:created)
        |> json(%{room_id: room_id})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: reason})
    end
  end
end
