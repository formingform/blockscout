defmodule BlockScoutWeb.L2L1TxnChannel do
  @moduledoc """
  Establishes pub/sub channel for l2->l1 txn.
  """
  use BlockScoutWeb, :channel

  intercept(["l2_to_l1_txn"])

  def join("platon_appchain:l2_to_l1_txn", _params, socket) do
    IO.puts("websocket is join to L2L1EventChannel>>>>>>>>>>>>>>>>>>>>>>>>>")
    {:ok, %{}, socket}
  end

  def handle_out(
        "l2_to_l1_txn",
        l2_events,
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    IO.puts("websocket handle_out l2_to_l1_txn tx to client>>>>>>>>>>>>>>>>>>>>>>>>>")
    push(socket, "l2_to_l1_txn", %{
      tx_hash: "tx_hash",
      block_number: 1
    })

    {:noreply, socket}
  end

end
