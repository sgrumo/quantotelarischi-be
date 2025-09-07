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

  def send_challenge(room_id, challenged_id) do
    GenServer.call(via_tuple(room_id), {:send_challenge, challenged_id})
  rescue
    _ -> {:error, :room_not_found}
  end

  def accept_challenge(room_id, user_id, challenge_amount) do
    GenServer.call(via_tuple(room_id), {:accept_challenge, user_id, challenge_amount})
  rescue
    _ -> {:error, :room_not_found}
  end

  def decline_challenge(room_id, user_id) do
    GenServer.call(via_tuple(room_id), {:decline_challenge, user_id})
  rescue
    _ -> {:error, :room_not_found}
  end

  def place_bet(room_id, user_id, action) do
    GenServer.call(via_tuple(room_id), {:place_bet, user_id, action})
  rescue
    _ -> {:error, :room_not_found}
  end

  def forfeit_bet(room_id, user_id) do
    GenServer.call(via_tuple(room_id), {:forfeit_bet, user_id})
  rescue
    _ -> {:error, :room_not_found}
  end

  def shutdown(room_id) do
    GenServer.cast(via_tuple(room_id), :shutdown)
  rescue
    _ -> :ok
  end

  def get_info(room_id) do
    GenServer.cast(via_tuple(room_id), :get_info)
  rescue
    _ -> :ok
  end

  # GenServer callbacks
  @impl true
  def init(room_id) do
    {:ok,
     %{
       room_id: room_id,
       challenge_amount: nil,
       challenger_id: nil,
       challenged_id: nil,
       challenger_bet_amount: nil,
       challenged_bet_amount: nil,
       created_at: DateTime.utc_now()
     }}
  end

  @impl true
  def handle_call({:join, _user_id}, _from, %{users: users} = state)
      when length(users) >= @max_users do
    {:reply, {:error, :room_full}, state}
  end

  @impl true
  def handle_call({:join, user_id}, _from, state) do
    new_state = %{state | challenger_id: user_id}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:send_challenge, challenge_description}, _from, state) do
    new_state = %{state | challenge_description: challenge_description}

    {:reply, {:ok, challenge_description}, new_state}
  end

  @impl true
  def handle_call({:accept_challenge, user_id, challenge_amount}, _from, state) do
    new_state = %{
      state
      | challenge_amount: challenge_amount,
        challenged_id: user_id
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:decline_challenge}, _from, state) do
    {:reply, {:ok, :declined}, state}
  end

  @impl true
  def handle_call(
        {:forfeit_bet, user_id},
        _from,
        %{
          challenged_id: challenged_id,
          challenger_id: challenger_id
        } = state
      ) do
    new_state =
      case {user_id, challenger_id, challenged_id} do
        {id, id, _} -> %{state | challenger_id: nil}
        {id, _id, id} -> %{state | challenged_id: nil}
        _ -> state
      end

    {:reply, {:ok, {:user_has_forfeited}}, new_state}
  end

  @impl true
  def handle_call(
        {:place_bet, user_id, amount},
        _from,
        %{
          challenge_amount: challenge_amount,
          challenged_id: challenged_id,
          challenger_id: challenger_id
        } = state
      ) do
    new_state =
      case {user_id, challenger_id, challenged_id} do
        {id, id, _} -> %{state | challenger_bet_amount: amount}
        {id, _, id} -> %{state | challenged_bet_amount: amount}
        _ -> state
      end

    if new_state.challenger_bet_amount != nil and new_state.challenged_bet_amount != nil do
      if challenge_amount == new_state.challenger_bet_amount + new_state.challenged_bet_amount or
           new_state.challenger_bet_amount == new_state.challenged_bet_amount do
        {:reply, {:ok, :bet_complete}}
      else
        {:reply, {:ok, :bet_lost}}
      end
    end

    {:reply, :ok}
  end

  @impl true
  def handle_cast(
        {:leave, user_id},
        %{challenger_id: challenger_id, challenged_id: challenged_id} = state
      ) do
    new_state =
      case {user_id, challenger_id, challenged_id} do
        {id, id, _} -> %{state | challenger_id: nil}
        {id, _id, id} -> %{state | challenged_id: nil}
        _ -> state
      end

    if new_state.challenged_id == nil and new_state.challenger_id == nil do
      Process.send_after(self(), :shutdown_if_empty, 30_000)
    end

    {:noreply, new_state}
  end

  def handle_cast(:shutdown, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:shutdown_if_empty, %{users: []} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:shutdown_if_empty, state) do
    {:noreply, state}
  end

  defp via_tuple(room_id) do
    {:via, Registry, {Quantomelarischio.RoomRegistry, room_id}}
  end
end
