defmodule Quantomelarischio.Rooms do
  alias Quantomelarischio.Rooms.RoomServer

  def create_room() do
    room_id = generate_room_id()

    case DynamicSupervisor.start_child(Quantomelarischio.RoomSupervisor, {RoomServer, room_id}) do
      {:ok, _pid} -> {:ok, room_id}
      {:error, {:already_started, _pid}} -> {:ok, room_id}
      error -> error
    end
  end

  def join_room(room_id, user_id) do
    case RoomServer.join(room_id, user_id) do
      {:ok, users} -> {:ok, users}
      {:error, :room_full} -> {:error, :room_full}
      {:error, :user_already_inside} -> {:error, :user_already_inside}
    end
  end

  def leave_room(room_id, user_id) do
    RoomServer.leave(room_id, user_id)
  end

  defp generate_room_id() do
    :crypto.strong_rand_bytes(6) |> Base.encode32(case: :lower, padding: false)
  end
end
