defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2BlockProducedStatistics do
  use Ecto.Migration

  # 这个表保存每个共识论round，当选的出块验证人的出块情况。
  # 数据来源：
  #     当同步区块时，如果此区块是round结束块（根据规则计算是否是round结束块），则调用底层rpc接口，获取此round所有验证人的出块情况，并被每个验证人一个应出块数（通过配置），最后把数据import到此表。
  # 注意：
  #     如果此round某个验证人因为各种原因，没有出块，底层rpc接口的返回数据中，也应包括此验证人，实际出库数=0即可。如果不返回，那就麻烦了，还需要再通过rpc获取这个round的验证人列表，然后合并两次rpc的结果。

  # 有了这些数据，即可计算验证人的出块率，计算方法（计算最近最多7个epoch的出块率）：
  #     select round(cast(sum(t.actual_blocks) / sum(t.should_blocks),2)
  #     from (
  #       select actual_blocks, should_blocks
  #       from l2_block_produced_statistics
  #       where validator_hash = '0x0102'
  #       order by round
  #       limit 7
  #     ) t
  #
  def change do
    create table(:l2_block_produced_statistics, primary_key: false) do
      # 验证人地址, validator_hash
      add(:validator_hash, :bytea, null: false, primary_key: true)
      # l2上的round，从1开始计算
      add(:round, :bigint, null: false, primary_key: true)
      # 应当出块数
      add(:should_blocks, :bigint, null: false, default: 0)
      # 实际出块数
      add(:actual_blocks, :bigint, null: false, default: 0)
      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
