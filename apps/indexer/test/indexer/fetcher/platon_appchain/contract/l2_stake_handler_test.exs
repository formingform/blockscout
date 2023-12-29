defmodule Indexer.Fetcher.PlatonAppchain.Contract.L2StakeHandlerTest do
  use ExUnit.Case
  doctest CallContract

  alias Indexer.Fetcher.PlatonAppchain.Contract.L2StakeHandler

  @tag :callContract
  test "call L2StakeHandler" do
    data =  L2StakeHandler.get_validators(<<>>,2)
    a = Ethers.call(data, to: "0x1000000000000000000000000000000000000005", from: "0x13943B955A42f55c0576c08a14734641249a943F")

    # 合约调用
    #    tx_data = Ethers.Contracts.ERC20.balance_of("0xDB0eCbE91f2739a10DAd39e5b53b3174C6C0Eeb2")
    #    a = Ethers.call(tx_data, to: "0x877149B4428A731fF08A301103EBFB7BE7ad4183")
    IO.inspect(a,lable: "a is:")
    IO.puts "Hello, World!"
  end

  #  http://192.168.9.82:8801
  #  0x1000000000000000000000000000000000000005
  @tag :abi_decode_by_type
  test "contract abi decode by type" do
    re= "0000000000000000000000000000000000000000000000000000000000000038"
        |> Base.decode16!(case: :lower)
        |> ABI.TypeDecoder.decode_raw([{:uint, 256}])
        |> List.first
    IO.inspect( "re is>>>#{inspect re}}")
  end

  @tag :abi_decode_by_json
  test "contract abi decode by json" do
    result =  File.read!("priv/counter.abi.json")
              |> Jason.decode!
              |> ABI.parse_specification
              |> ABI.find_and_decode("60fe47b10000000000000000000000000000000000000000000000000000000000000038" |> Base.decode16!(case: :lower))
    IO.inspect("decode value is>>>#{inspect result}")
    {func,params} = result

    IO.puts("function name : #{func.function}")
    IO.puts("function method id: #{Base.encode16(func.method_id,case: :lower)}")
    [value] = params
    IO.puts("value: #{value}")
  end
end
