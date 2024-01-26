defmodule Explorer.Repo.PlatonAppchain.Migrations.CreateL2ValidatorHistorys do
  use Ecto.Migration

  def change do

    create table(:l2_validator_historys, primary_key: false) do
      # 验证人地址, validator_hash
      add(:validator_hash, :bytea, null: false, primary_key: true)
      # 质押成为验证人的epoch，这个不需要作为主键的一部分，如果验证人多次退出，则只保留最近退出的信息
      add(:stake_epoch, :bigint, null: false, primary_key: true)
      # 验证人owner地址
      add(:owner_hash, :bytea, null: false)
      # 拥金比例, 每个结算周期，每个验证人获得总奖励，首先按此金额扣除CommissionRate，剩余的再按质押/委托金额比例分配。
      add(:commission_rate, :integer, null: true, default: 0)
      # 有效质押金额
      add(:stake_amount, :numeric, precision: 100, null: false, default: 0)
      # 锁定的质押金额
      add(:locking_stake_amount, :numeric, precision: 100, null: false, default: 0)
      # 可提取的质押金额
      add(:withdrawal_stake_amount, :numeric, precision: 100, null: false, default: 0)
      # 有效委托金额
      add(:delegate_amount, :numeric, precision: 100, null: false, default: 0)
      # 验证人可领取奖励（出块与质押）
      add(:stake_reward, :numeric, precision: 100, null: false, default: 0)
      # 委托奖励
      add(:delegate_reward, :numeric, precision: 100, null: false, default: 0)
      # 排名，获取所有质押节点返回的列表序号
      add(:rank, :integer, null: false, default: 0)
      # 验证人名称
      add(:name, :string, null: true)
      # 验证人描述信息
      add(:detail, :string, null: true)
      # 节点logo
      add(:logo, :text, null: true)
      # 验证人官方网站
      add(:website, :string, null: true)
      # 预估年收益率
      add(:expect_apr, :integer, null: true)
      # 最近24小时出块率
      add(:block_rate, :integer, null: true)
      # 是否验证 0-未验证，1-已验证
      add(:auth_status, :integer, null: false, default: 0)
      # Invalided    ValidatorStatus = 1 << iota // 0001: The validator is deactivated
      #	LowBlocks                                // 0010: The validator was low block rate
      #	LowThreshold                             // 0100: The validator's stake was lower than minimum stake threshold
      #	Duplicated                               // 1000: The validator was duplicate block or duplicate signature
      #	Unstaked                                 // 0010,0000: The validator was unstaked
      #	Slashing                                 // 0100,0000: The validator is being slashed
      #	Valided      = 0                         // 0000: The validator was activated
      #	NotExist     = 1 << 31                   // 1000,xxxx,... : The validator is not exist
      # 底层是用bit来存储的，是个复合状态
      # 浏览器目前只判断：0: 正常 1：无效 2：低出块 4: 低阈值 8: 双签 32：解质押 64:惩罚
      add(:status, :integer, null: false, default: 0)
      # 0-candidate(质押节点) 1-active(共识节点后续人) 2-verifying(共识节点)
      add(:role, :integer, null: false, default: 0)

      # 退出区块
      add(:exit_number, :bigint, null: false)
      # 退出内容
      add(:event, :string, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
