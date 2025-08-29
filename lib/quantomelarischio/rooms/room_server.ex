defmodule Quantomelarischio.Rooms.RoomServer do
  use GenServer

  @max_users 2

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via_tuple(room_id))
  end

  def join(room_id, user_id) do
    GenServer.call(via_tuple(room_id), {:join, user_id})
  rescue
    _ -> {:error, :room_not_found}
  end

  def leave(room_id, user_id) do
    GenServer.cast(via_tuple(room_id), {:leave, user_id})
  rescue
    _ -> :ok
  end

  # GenServer callbacks

  def init(room_id) do
    {:ok, %{room_id: room_id, users: [], created_at: DateTime.utc_now()}}
  end

  def handle_call({:join, _user_id}, _from, %{users: users} = state)
      when length(users) >= @max_users do
    {:reply, {:error, :room_full}, state}
  end

  def handle_call({:join, user_id}, _from, %{users: users} = state) do
    if user_id in users do
      {:reply, {:error, :user_already_inside}, state}
    else
      new_users = [user_id | users]
      {:reply, {:ok, new_users}, %{state | users: new_users}}
    end
  end

  def handle_cast({:leave, user_id}, %{users: users} = state) do
    new_users = List.delete(users, user_id)
    new_state = %{state | users: new_users}

    if length(new_users) == 0 do
      Process.send_after(self(), :shutdown_if_empty, 30_000)
    end

    {:noreply, new_state}
  end

  def handle_info(:shutdown_if_empty, %{users: []} = state) do
    {:stop, :normal, state}
  end

  def handle_info(:shutdown_if_empty, state) do
    {:noreply, state}
  end

  defp via_tuple(room_id) do
    {:via, Registry, {Quantomelarischio.RoomRegistry, room_id}}
  end
end
