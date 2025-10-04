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
      {:ok, roomInfo} -> {:ok, roomInfo}
      {:error, :room_full} -> {:error, :room_full}
      {:error, :user_already_inside} -> {:error, :user_already_inside}
      {:error, :room_not_found} -> {:error, :room_not_found}
    end
  end

  def leave_room(room_id, user_id) do
    RoomServer.leave(room_id, user_id)
  end

  def send_challenge(room_id, challenge_description) do
    RoomServer.send_challenge(room_id, challenge_description)
  end

  def accept_challenge(room_id, user_id, challenge_amount) do
    case RoomServer.accept_challenge(room_id, user_id, challenge_amount) do
      :ok -> {:ok, challenge_amount}
      {:error, reason} -> {:error, reason}
    end
  end

  def place_bet(room_id, user_id, bet_amount) do
    case RoomServer.place_bet(room_id, user_id, bet_amount) do
      :ok -> :ok
      {:ok, bet} -> {:ok, bet}
      {:error, reason} -> {:error, reason}
    end
  end

  def decline_challenge(room_id, user_id) do
    case RoomServer.decline_challenge(room_id, user_id) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def forfeit_bet(room_id, user_id) do
    case RoomServer.forfeit_bet(room_id, user_id) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def reset_game(room_id) do
    case RoomServer.reset_game(room_id) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Room Discovery and Statistics
  def list_active_rooms() do
    # Get all active room processes
    Quantomelarischio.RoomSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} ->
      case GenServer.call(pid, :get_room_id, 5000) do
        {:ok, room_id} -> room_id
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  def get_room_count() do
    Quantomelarischio.RoomSupervisor
    |> DynamicSupervisor.count_children()
    |> Map.get(:active, 0)
  end

  defp generate_room_id() do
    :crypto.strong_rand_bytes(6) |> Base.encode32(case: :lower, padding: false)
  end

  defp validate_amount(amount) when is_integer(amount) and amount > 1, do: {:ok, amount}
  defp validate_amount(_), do: {:error, :invalid_amount}

  # Broadcast helpers (for use by channels)
  def broadcast_to_room(room_id, event, payload) do
    QuantomelarischioWeb.Endpoint.broadcast("room:#{room_id}", event, payload)
  end

  def broadcast_to_user(user_id, event, payload) do
    QuantomelarischioWeb.Endpoint.broadcast("user_socket:#{user_id}", event, payload)
  end
end
