# Delphi FMX + Skia 高性能虚拟化卡片列表与声明式 UI DSL

> 完整开发使用手册请查阅同一目录下的 [使用文档.md](使用文档.md)。

## 核心架构速览

- **[SkVirtualList.Core.pas](SkVirtualList.Core.pas)**：
  - `TSkVirtualListView`：通用虚拟化滚动列表控件，支持惯性回弹（`TAniCalculations`）、防幽灵误触、双轴手势仲裁、单双列同屏异构混排与视口数学裁剪。
  - `TSkRenderContext`：跨卡片复用画笔、跨平台中文字体自适应探测、SVG 路径缓存，实现单帧零堆内存抖动（Zero Heap Allocation）。
  - `ISkCardRenderer`：渲染器策略接口契约，支持画廊手势与智能巡航扩展协议。
- **[SkUiDsl.pas](SkUiDsl.pas)**：
  - 声明式 UI DSL 原语：`HStack`, `VStack`, `Box`, `Spacer`, `SkText`, `AsyncImage`, `Carousel`, `SkSvg`, `SkCircle`, `SkBadge`。
  - 支持 `Flex` 弹性伸缩、两端对齐（`Between`）、圆角阴影、多行折行自适应排版（`MaxLines` 智能截断与省略号 `...`）与子热区精确绑定（`OnClick(AZoneID)`）。
  - `TDeclarativeCardRenderer`：声明式渲染基类，集成布局测量与坐标缓存（`TCachedLayout`）。
- **[SkImageCache.pas](SkImageCache.pas)**：
  - L1 内存 LRU 淘汰（默认 80 容量上限）+ L2 磁盘持久化（MD5 散列）。
  - 异步后台下载队列与最大 4 并发限流，同 Owner 自动合并去重，版本号防悬挂引用，`Destroy` 安全等待与生命周期安全。
- **[SkAsync.pas](SkAsync.pas)**：
  - 原生线程池轻量封装，支持业务后台异步执行与主线程回调，严格保证 `Finally` 回调 100% 必然执行。
- **[SkCardRenderers.Biz.pas](SkCardRenderers.Biz.pas)**：
  - `TSingleProductCardRenderer`：单列大图商品卡（含加购子热区 `ZONE_ACTION_BUY` 与轮播热区 `ZONE_IMAGE_CAROUSEL`，支持真实物理动态测高与轮播节点常驻复用）。
  - `TDoubleMerchantCardRenderer`：双列网格商家卡（4:3 封面比例，高评分自动展开金牌服务条）。
- **[Biz.OrderRenderer.pas](Biz.OrderRenderer.pas)**：
  - `TOrderCardRenderer`：复合订单卡片（支持 1~N 行商品明细动态弹性伸缩，多缩略图子热区支持一键重试与业务跳转）。
- **[Unit1.pas](Unit1.pas)**：
  - 窗体挂载、多数据装配、单列/双列/混排/订单模式切换、骨架屏/空状态控制、横向滚动工具栏（`HorzScrollBox1`）、通用坏图重试与局部改价演示。
