存在问题，优先处理异步回调生命周期和分页状态冲突。本轮只读检查，未修改文件。

已完整阅读项目的 4 份 Markdown，再按文档核对当前运行链路。项目采用“虚拟列表引擎 + 声明式布局 + 业务渲染器 + 图片缓存”，以下按文档预期的 App 多列表复用、千级数据和弱网场景评估；历史原型不作为当前实现审查。
1. [P1] 图片回调的生命周期保护没有真正闭环
   [SkUiDsl.pas (line 1857)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/SkUiDsl.pas:1857)
   商品图片订阅时传入的是渲染器，商家和订单图片没有传 Owner；列表销毁时却只注销列表自身。下载完成后，回调仍可能访问已经释放的 AContext，造成访问异常。最小修复是统一订阅与注销对象，保证回调依赖的上下文仍然有效。
2. [P1] 延迟加载和分页请求缺少过期保护
   [Unit1.pas (line 253)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/Unit1.pas:253)、[Unit1.pas (line 796)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/Unit1.pas:796)
   启动后的混排加载等待 600ms，期间切到订单，旧混排任务仍会覆盖订单数据；分页返回也会直接写入当前列表。窗体销毁后这些任务同样没有失效机制。应记录请求版本和模式快照，并在窗体销毁时使未完成回调失效。
3. [P1] 下拉刷新和加载更多可以同时进行，完成状态会串线
   [SkVirtualList.Core.pas (line 1395)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/SkVirtualList.Core.pas:1395)、[SkVirtualList.Core.pas (line 944)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/SkVirtualList.Core.pas:944)
   加载更多期间仍能下拉刷新，而 FinishFetch 优先按 FIsRefreshing 处理结果。此时加载更多先返回，会被当成刷新完成，页码归 1，加载更多标志仍然保留。最小修复是先让两类请求互斥，并确保完成事件对应原请求。
4. [P2] 一次分页失败就被当成“没有更多数据”
   [Unit1.pas (line 815)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/Unit1.pas:815)
   错误回调调用 FinishFetch(False, False)，控件仍将 HasMore 改为 False。临时超时后，继续滚动无法重试，还会显示“已显示全部内容”。失败时应保留原页码和 HasMore，只解除加载状态。
5. [P2] 初始数据与后续分页范围不一致，会追加重复 ID
   [Unit1.pas (line 485)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/Unit1.pas:485)、[Unit1.pas (line 692)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/Unit1.pas:692)
   商品首次生成 ID 1～20，第 2 页却按每页 10 条计算，生成 11～20；商家首次生成 60 条，也存在重复范围。应统一首次加载、分页计算和 PageSize 的条数规则。
6. [P2] “点击重试”没有按实际失败图片执行
   [Unit1.pas (line 835)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/Unit1.pas:835)
   当前仅检查商品主图 URL 是否包含 404，重试的也是主图。正常 URL 超时、轮播第 2/3 张失败，以及商家图片失败，都无法按提示重试。应根据图片失败状态和当前显示 URL 处理，不能依赖测试地址字符串。
7. [P2] MaxLines(2) 不符合文档描述
   [SkUiDsl.pas (line 1538)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/SkUiDsl.pas:1538)
   未开启换行时，`MaxLines(2)` 走单行直接绘制，长文字可能越界；开启换行后，测量和绘制又都不限制最大行数。应统一实现最大行数限制，并对最后一行做省略处理。
8. [P2] 循环轮播跨首尾时会出现空白过渡
   [SkUiDsl.pas (line 2148)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/SkUiDsl.pas:2148)
   渲染器支持末张切回首张，但绘制只排列真实索引范围内的图片，没有绘制循环相邻图。按源码公式推演，96px 图片在末张向左滑到一半时，仅覆盖 48px。应在首尾边界补画循环相邻图片。
9. [P2] 图片请求合并了，回调却在每次重绘时追加
   [SkImageCache.pas (line 234)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/SkImageCache.pas:234)
   图片加载期间每次绘制都会再次订阅，同一 URL 的回调列表没有去重。弱网下会积累大量重复闭包，完成时集中执行。应按稳定订阅者去重，避免按绘制次数增加回调。
10. [P2] 轮播动画每帧都销毁并重建整张卡片布局树
    [SkUiDsl.pas (line 2597)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/SkUiDsl.pas:2597)
    每次更新图片偏移都会删除卡片缓存，下一帧重新 BuildLayout → Measure → Layout。这与文档强调的动画期间复用布局树不一致，复杂卡片会产生持续分配开销。应直接更新轮播节点状态，保留其余布局缓存。
11. [P2] Finally 无法保证执行
    [SkAsync.pas (line 189)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/SkAsync.pas:189)
    成功或错误回调抛异常后，后面的 LFinally() 会被跳过，且回调字段已经清空。使用它恢复按钮或释放资源时会遗漏清理。应将终结回调放入真正的 try…finally。
12. [P2] 使用手册的部分示例无法直接编译
    [使用文档.md (line 1011)](/Users/xiexianggao/Develop/Delphi/SkVirtualCardList-main/使用文档.md:1011)
    微信小店示例使用了不存在的 AlignBaseline、文本节点 Padding 和 P.SalesCount。应将示例调整为已有 API，或明确标注为示意代码，避免后续接入时踩坑。
    验证方面，工程配置 XML 结构检查通过；轮播和分页问题做了小型算法推演；项目中未发现自动化测试