defmodule Indexer.Fetcher.PlatonAppchain.Contracts.InnerContractHandler do
  @moduledoc """
  提供L2内置合约的一些方法调用，比如获取一些治理参数的值
  """
  #撤销委托后委托金额锁定的结算周期数量
  @epochs_for_locking_undelegation 6

  #后续可以从rpc接口获取，目前先用缺省配置值
  def get_epochs_for_locking_undelegation(block_number) do
    @epochs_for_locking_undelegation
  end
end
