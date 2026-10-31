# Delphi FMX + Skia 高性能虚拟化卡片列表与声明式 UI DSL

> 完整开发使用手册请查阅同一目录下的 [使用文档.md](file:///d:/develop/borland/yin_tai/doc/202610/SkVirtualCardList/%E4%BD%BF%E7%94%A8%E6%96%87%E6%A1%A3.md)。

## 核心架构速览

- **[SkVirtualList.Core.pas](file:///d:/develop/borland/yin_tai/doc/202610/SkVirtualCardList/SkVirtualList.Core.pas)**：
  - `TSkVirtualListView`：通用虚拟化滚动列表控件，支持惯性回弹（`TAniCalculations`）、防幽灵误触、双轴手势仲裁、单双列同屏异构混排与视口数学裁剪。
  - `TSkRenderContext`：跨卡片复用画笔、跨平台中文字体自适应探测、SVG 路径缓存，实现单帧零堆内存抖动（Zero Heap Allocation）。
  - `ISkCardRenderer`：渲染器策略接口契约，支持画廊手势与智能巡航扩展协议。
- **[SkUiDsl.pas](file:///d:/develop/borland/yin_tai/doc/202610/SkVirtualCardList/SkUiDsl.pas)**：
  - 声明式 UI DSL 原语：`HStack`, `VStack`, `Box`, `Spacer`, `SkText`, `AsyncImage`, `Carousel`, `SkSvg`, `SkCircle`, `SkBadge`。
  - 支持 `Flex` 弹性伸缩、两端对齐（`Between`）、圆角阴影、多行折行自适应排版与子热区精确绑定（`OnClick(AZoneID)`）。
  - `TDeclarativeCardRenderer`：声明式渲染基类，集成布局测量与坐标缓存（`TCachedLayout`）。
- **[SkImageCache.pas](file:///d:/develop/borland/yin_tai/doc/202610/SkVirtualCardList/SkImageCache.pas)**：
  - L1 内存 LRU 淘汰（默认 80 容量上限）+ L2 磁盘持久化（MD5 散列）。
  - 异步后台下载队列与最大 4 并发限流，请求合并防击穿，`Unsubscribe` 生命周期安全。
- **[SkCardRenderers.Biz.pas](file:///d:/develop/borland/yin_tai/doc/202610/SkVirtualCardList/SkCardRenderers.Biz.pas)**：
  - `TSingleProductCardRenderer`：单列大图商品卡（含加购子热区 `ZONE_ACTION_BUY` 与轮播热区 `ZONE_IMAGE_CAROUSEL`，支持真实物理动态测高）。
  - `TDoubleMerchantCardRenderer`：双列网格商家卡（4:3 封面比例，高评分自动展开金牌服务条）。
- **[Unit1.pas](file:///d:/develop/borland/yin_tai/doc/202610/SkVirtualCardList/Unit1.pas)**：
  - 窗体挂载、多数据装配、单列/双列/混排模式切换、骨架屏/空状态控制与 Windows 鼠标滚轮转发示例。
