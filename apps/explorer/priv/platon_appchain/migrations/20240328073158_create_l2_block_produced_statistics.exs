defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2BlockProducedStatistics do
  use Ecto.Migration

  # 这个表保存每个epoch，当选的出块验证人的出块情况。
  # 当同步区块时，
  # 如果此区块是选举块（根据规则计算是否是选举块）
  #   则需要查询下一轮出块验证人列表，并用upsert的方法，加入此表
  #     新加入的记录时，should_blocks = 10, actual_blocks = 0
  #     有冲突时则更新原记录，should_block += 10
  # 如果此区块是epoch结束块（根据规则计算是否是epoch结束块），
  #   则需要查询此表中epoch=current_epoch的记录，并到链上查询每个validator在current_epoch的实际出块数量，
  #   并更新相应记录的actual_blocks，并计算最近最多7个epoch的出块率。出块率计算方法：
  #     update l2_validators set produced_rate =
  #     (select round(cast(sum(t.actual_blocks) / sum(t.should_blocks),2)
  #     from (
  #       select actual_blocks, should_blocks
  #       from l2_block_produced_statistics
  #       where validator_hash = '0x0102'
  #       order by epoch
  #       limit 7
  #     ) t)
  #     where validator_hash = '0x0101';
  #   如果更新结果返回的记录数=0，则还要更新l2_validator_historys表
  #
  def change do
    create table(:l2_block_produced_statistics, primary_key: false) do
      # l2上的epoch，一个epoch结束块高生成一个checkpoint
      add(:epoch, :bigint, null: false, primary_key: true)
      # 验证人地址, validator_hash
      add(:validator_hash, :bytea, null: false, primary_key: true)
      # 应当出块数，当选一次+10
      add(:should_blocks, :bigint, null: false, default: 0)
      # 实际出块数
      add(:actual_blocks, :bigint, null: false, default: 0)
      # 出块率
      add(:block_rate, :bigint, null: false, default: 0)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
