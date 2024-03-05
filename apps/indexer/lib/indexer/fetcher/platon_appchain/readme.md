### L1事件的监听处理
l1_event.ex, l1_execute, checkpoint.ex，既需要获取L1上从INDEXER_PLATON_APPCHAIN_L1_START_BLOCK开始的历史区块的事件，也要赋值获取新区块的相关事件。
这个是有l1_event.ex, l1_execute, checkpoint.ex中通过消息:continue来循环完成的。

### L2事件的监听处理
##### 历史区块事件
是由l2_event.ex, l2_execute.ex, l2_validator_event.ex, commitment.ex来完成的，历史区块处理完成后，这些fetcher将stop。

##### 新区块事件
是有 indexer/block/fetcher.ex来实时处理的
