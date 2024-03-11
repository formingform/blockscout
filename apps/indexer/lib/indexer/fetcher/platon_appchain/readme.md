### 注意点
- PlatON的block无需reorg，也没有safe_block概念。
- 为了和ether的rpc接口兼容，PlatON需要提供eth_blockNumber中参数为："safe"的支持(和"latest"等效)
- 连接的L2节点，需要是归档节点，以便支持RPC接口：debug_traceTransaction

### INDEXER_PLATON_APPCHAIN_L2_START_BLOCK，INDEXER_PLATON_APPCHAIN_L1_START_BLOCK参数配置说明
- 系统初次运行时，这两个参数可以配置为：1
- 系统停止后重启，理论上，有两种方法配置此参数：目前应用链采用的是第二种方法。
1. INDEXER_PLATON_APPCHAIN_L2_START_BLOCK重置为表blocks中获取最大区块+1；INDEXER_PLATON_APPCHAIN_L1_START_BLOCK重置为(l1_events,l1_executes,checkpoints)表最大区块+1
2. 保持参数的设置为1，有每个fetcher自己查询各自表里最大区块号+1，作为继续获取历史区块数据库的起始区块号。

### L1事件的监听处理
l1_event.ex, l1_execute, checkpoint.ex，既需要获取L1上从INDEXER_PLATON_APPCHAIN_L1_START_BLOCK开始的历史区块的事件，也要赋值获取新区块的相关事件。
这个是有l1_event.ex, l1_execute, checkpoint.ex中通过消息:continue来循环完成的。

### L2事件的监听处理
##### 历史区块事件
是由l2_event.ex, l2_execute.ex, l2_validator_event.ex, commitment.ex来完成的，历史区块处理完成后，这些fetcher将stop。

##### 新区块事件
是有 indexer/block/fetcher.ex来实时处理的
