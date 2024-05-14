defmodule BlockScoutWeb.L1L2TxnChannel do
  @moduledoc """
  Establishes pub/sub channel for l1->l2 txn.
  """
  use BlockScoutWeb, :channel

  intercept(["l1_to_l2_txn"])

  def join("platon_appchain:l1_to_l2_txn", _params, socket) do
    IO.puts("websocket is join to L1L2EventChannel>>>>>>>>>>>>>>>>>>>>>>>>>")
    {:ok, %{}, socket}
  end

  #    test begin
#  alias BlockScoutWeb.Endpoint
#  Endpoint.broadcast("platon_appchain:l1_to_l2_txn", "l1_to_l2_txn", %{
#    batch: 1
#  })
  #    test end
  def handle_out(
        "l1_to_l2_txn",
        l1_events,
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    IO.puts("websocket handle_out l1_to_l2_txn tx to client>>>>>>>>>>>>>>>>>>>>>>>>>")
    push(socket, "l1_to_l2_txn", %{
      tx_hash: "tx_hash",
      block_number: 1
    })

    {:noreply, socket}
  end

end
