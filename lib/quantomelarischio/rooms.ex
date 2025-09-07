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
    case ensure_room_exists(room_id) do
      {:ok, _room_id} ->
        case RoomServer.join(room_id, user_id) do
          {:ok, users} -> {:ok, users}
          {:error, :room_full} -> {:error, :room_full}
          {:error, :user_already_inside} -> {:error, :user_already_inside}
          {:error, :room_not_found} -> {:error, :room_not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def leave_room(room_id, user_id) do
    RoomServer.leave(room_id, user_id)
  end

  def get_room_info(room_id) do
    case RoomServer.get_info(room_id) do
      {:ok, info} -> {:ok, info}
      {:error, reason} -> {:error, reason}
    end
  end

  def send_challenge(room_id, amount) do
    with {:ok, amount} <- validate_amount(amount),
         {:ok, challenge} <-
           RoomServer.send_challenge(room_id, amount) do
      {:ok, challenge}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def accept_challenge(room_id, user_id, challenge_amount) do
    case RoomServer.accept_challenge(room_id, user_id, challenge_amount) do
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

  def find_available_room() do
    # Find a room that isn't full
    case list_active_rooms() do
      [] ->
        # No rooms exist, create one
        create_room()

      room_ids ->
        # Check each room for availability
        available_room =
          Enum.find(room_ids, fn room_id ->
            case get_room_info(room_id) do
              {:ok, %{users: users}} when length(users) < 2 -> true
              _ -> false
            end
          end)

        case available_room do
          nil -> create_room()
          room_id -> {:ok, room_id}
        end
    end
  end

  defp generate_room_id() do
    :crypto.strong_rand_bytes(6) |> Base.encode32(case: :lower, padding: false)
  end

  defp ensure_room_exists(room_id) do
    case RoomServer.ping(room_id) do
      :pong -> {:ok, room_id}
      {:error, :room_not_found} -> {:error, :room_not_found}
    end
  end

  defp validate_amount(amount) when is_integer(amount) and amount > 1, do: {:ok, amount}

  defp validate_amount(_), do: {:error, :invalid_amount}

  defp validate_bet_amount(bet_amount, challenge_amount)
       when is_number(bet_amount) and is_number(challenge_amount) do
    if bet_amount > 1 and bet_amount < challenge_amount do
      :ok
    else
      {:error, :invalid_bet_amount}
    end
  end

  defp validate_bet_action(action) when is_binary(action) and byte_size(action) > 0 do
    if action in ["rock", "paper", "scissors", "fold", "call", "raise"] do
      {:ok, action}
    else
      {:error, :invalid_action}
    end
  end

  defp validate_bet_action(_), do: {:error, :invalid_action}

  # Cleanup and maintenance functions
  def cleanup_abandoned_rooms() do
    # This could be called by a periodic task
    abandoned_rooms =
      list_active_rooms()
      |> Enum.filter(fn room_id ->
        case get_room_info(room_id) do
          {:ok, %{users: [], created_at: created_at}} ->
            # Room is empty and older than 1 hour
            DateTime.diff(DateTime.utc_now(), created_at, :second) > 3600

          _ ->
            false
        end
      end)

    Enum.each(abandoned_rooms, fn room_id ->
      # The room should shut itself down, but we can force it if needed
      RoomServer.shutdown(room_id)
    end)

    {:ok, length(abandoned_rooms)}
  end

  # Room statistics
  def get_room_stats(room_id) do
    case get_room_info(room_id) do
      {:ok, info} ->
        stats = %{
          room_id: room_id,
          user_count: length(info.users),
          max_users: 2,
          created_at: info.created_at,
          active_bets_count: length(Map.keys(info.active_bets || %{})),
          pending_challenges_count: length(Map.keys(info.challenges || %{}))
        }

        {:ok, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Broadcast helpers (for use by channels)
  def broadcast_to_room(room_id, event, payload) do
    QuantomelarischioWeb.Endpoint.broadcast("room:#{room_id}", event, payload)
  end

  def broadcast_to_user(user_id, event, payload) do
    QuantomelarischioWeb.Endpoint.broadcast("user_socket:#{user_id}", event, payload)
  end
end
