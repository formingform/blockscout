defmodule Explorer.Helper do
  @moduledoc """
  Common explorer helper
  """
  alias ABI.TypeDecoder
  alias Explorer.Chain.Data

  @spec decode_data(binary() | map(), list()) :: list() | nil
  def decode_data("0x", types) do
    for _ <- types, do: nil
  end

  def decode_data("0x" <> encoded_data, types) do
    decode_data(encoded_data, types)
  end

  def decode_data(%Data{} = data, types) do
    data
    |> Data.to_string()
    |> decode_data(types)
  end

  def decode_data(encoded_data, types) do
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


  def from_unix(unix_timestamp) do
    length = String.length(Integer.to_string(unix_timestamp))
    if length == 13 do
      {:ok, date} = DateTime.from_unix(unix_timestamp, :millisecond)
      date
    else
      {:ok, date} = DateTime.from_unix(unix_timestamp)
      date
    end
  end
end
