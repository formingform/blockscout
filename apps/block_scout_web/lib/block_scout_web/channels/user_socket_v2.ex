defmodule BlockScoutWeb.UserSocketV2 do
  @moduledoc """
    Module to distinct new and old UI websocket connections
  """
  use Phoenix.Socket

  channel("addresses:*", BlockScoutWeb.AddressChannel)
  channel("blocks:*", BlockScoutWeb.BlockChannel)
  channel("exchange_rate:*", BlockScoutWeb.ExchangeRateChannel)
  channel("rewards:*", BlockScoutWeb.RewardChannel)
  channel("transactions:*", BlockScoutWeb.TransactionChannel)
  channel("tokens:*", BlockScoutWeb.TokenChannel)
  channel("zkevm_batches:*", BlockScoutWeb.ZkevmConfirmedBatchChannel)
  channel("platon_appchain_l1l2event:*", BlockScoutWeb.L1L2EventChannel)
  channel("platon_appchain_l2_validator:*", BlockScoutWeb.L2ValidatorChannel)

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
