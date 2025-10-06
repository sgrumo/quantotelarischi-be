defmodule QuantomelarischioWeb.Channels.Handlers.BetHandler do
  alias Quantomelarischio.Rooms
  alias QuantomelarischioWeb.Endpoint

  def handle(
        "send_challenge",
        %{"challenge_description" => challenge_description},
        socket
      ) do
    room_id = socket.assigns.room_id
    # user_id = socket.assigns.user_id

    case Rooms.send_challenge(room_id, challenge_description) do
      {:ok, _challenge} ->
        Endpoint.broadcast("room:#{room_id}", "challenge_received", %{
          challenge_description: challenge_description
        })

        {:reply, {:ok, socket}}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle("accept_challenge", %{"amount" => amount}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Rooms.accept_challenge(room_id, user_id, amount) do
      {:ok, bet} ->
        Endpoint.broadcast("room:#{room_id}", "challenge_accepted", %{
          amount: bet
        })

        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle("decline_challenge", _payload, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Rooms.decline_challenge(room_id, user_id) do
      {:ok, _} ->
        Endpoint.broadcast("room:#{room_id}", "challenge_declined", %{
          declined_by: user_id
        })

        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle("place_bet", %{"amount" => amount}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Rooms.place_bet(room_id, user_id, amount) do
      :ok ->
        {:reply, :ok, socket}

      {:ok, result} ->
        Endpoint.broadcast("room:#{room_id}", "bet_completed", %{
          challenger_amount: result.challenger_bet_amount,
          challenged_amount: result.challenged_bet_amount,
          status: result.status
        })

        {:reply, {:ok, result}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle("reset_game", _payload, socket) do
    room_id = socket.assigns.room_id

    case Rooms.reset_game(room_id) do
      :ok ->
        Endpoint.broadcast("room:#{room_id}", "game_reset", %{})
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle(event, _payload, socket) do
    {:reply, {:error, %{reason: "Unknown event: #{event}"}}, socket}
  end
end
