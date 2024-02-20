defmodule Explorer.Helper do
  @moduledoc """
  Common explorer helper
  """

  require Logger

  alias ABI.TypeDecoder
  alias Explorer.Chain.Data

  @spec decode_data(binary() | map(), list()) :: list() | nil
  def decode_data("0x", types) do
    Logger.error(fn -> "decode_data_0x,  types: #{inspect(types)}" end )

    for _ <- types, do: nil
  end

  def decode_data("0x" <> encoded_data, types) do
    Logger.error(fn -> "decode_data_1, data: #{inspect(encoded_data)}, types: #{inspect(types)}" end )


    decode_data(encoded_data, types)
  end

  def decode_data(%Data{} = data, types) do
    Logger.error(fn -> "decode_data_2, data: #{inspect(data)}, types: #{inspect(types)}" end )

    data
    |> Data.to_string()
    |> decode_data(types)
  end

  def decode_data(encoded_data, types) do
    Logger.error(fn -> "decode_data_3, data: #{inspect(encoded_data)}, types: #{inspect(types)}" end )


    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  @spec parse_integer(binary() | nil) :: integer() | nil
  def parse_integer(nil), do: nil

  def parse_integer(string) do
    case Integer.parse(string) do
      {number, ""} -> number
      _ -> nil
    end
  end
end
