defmodule QuantomelarischioWeb.Channels.Handlers.BetHandler do
  alias Quantomelarischio.Rooms
  alias QuantomelarischioWeb.Endpoint

  def handle(
        "challenge_sent",
        %{"amount" => amount},
        socket
      ) do
    room_id = socket.assigns.room_id
    # user_id = socket.assigns.user_id

    case Rooms.send_challenge(room_id, amount) do
      {:ok, _challenge} ->
        Endpoint.broadcast("room:#{room_id}", "challenge_received", %{
          amount: amount
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
          bet_id: bet.id,
          challenger_id: bet.challenger_id,
          challenged_id: bet.challenged_id,
          amount: bet.amount
        })

        {:reply, {:ok, %{bet_id: bet.id}}, socket}

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

  def handle("place_bet", %{"bet_id" => bet_id, "amount" => amount}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Rooms.place_bet(room_id, bet_id, user_id, amount) do
      {:ok, result} ->
        if result.status == "completed" do
          Endpoint.broadcast("room:#{room_id}", "bet_completed", %{
            bet_id: bet_id,
            winner_id: result.winner_id,
            amount: result.amount
          })
        end

        {:reply, {:ok, result}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle(event, _payload, socket) do
    {:reply, {:error, %{reason: "Unknown event: #{event}"}}, socket}
  end
end
