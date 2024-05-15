defmodule Explorer.Chain.PlatonAppchain.DailyStatic do
  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  # alias Ecto.Changeset
  alias Explorer.{
    Chain,
    Repo
    }

  alias Explorer.Chain.{Wei}
  alias Explorer.Chain.PlatonAppchain.L2Validator

  @optional_attrs ~w(total_validator_size total_bonded)a

  @required_attrs ~w(static_date)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
     static_date： 统计日期,
     total_validator_size:  总验证人数(活跃与候选节点),
     total_bonded:  有效总质押量（不包含解质押或解委托的）,
  """
  @type t :: %__MODULE__{
               static_date: String.t(),
               total_validator_size:  non_neg_integer(),
               total_bonded:  Wei.t(),
             }

  @primary_key false
  schema "daily_static" do
    field(:static_date, :string, primary_key: true)
    field(:total_validator_size, :integer)
    field(:total_bonded, Wei)

    timestamps()
  end

  @spec find_yesterday_data() :: [__MODULE__.t]
  def find_yesterday_data() do
    current_datetime = Timex.now()
    yesterday_datetime = Timex.shift(current_datetime, days: -1)
    yesterday_date = Timex.format!(yesterday_datetime, "{YYYY}{0M}{0D}")

    query =
      from(
         d in __MODULE__,
         where: d.static_date == ^yesterday_date
      )

    query
    |> select_repo([]).one()
  end

  def find_by_static_date(static_date) do
    query =
      from(d in __MODULE__,
        select: count(1),
        where: d.static_date == ^static_date
      )

    query
    |> select_repo([]).one()
  end

  def static_validator() do
    query =
      from(
        l in L2Validator,
        select: %{
          static_date: fragment("to_char(CURRENT_DATE - INTERVAL '1 day', 'YYYYMMDD')"),
          total_validator_size: count(1),
          total_bonded: fragment("SUM(COALESCE(?, 0) + COALESCE(?, 0))", l.stake_amount, l.delegate_amount),
          inserted_at: fragment("CURRENT_TIMESTAMP"),
          updated_at: fragment("CURRENT_TIMESTAMP")
        }
      )

    Repo.insert_all(__MODULE__, query)
  end
end
