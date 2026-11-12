# Delphi FMX + Skia 虚拟化卡片列表与声明式 UI DSL

完整说明见 [使用文档](使用文档.md)。项目采用纯画布绘制，支持商品、商家、订单卡片和单双列混排。

- `SkVirtualList.Core.pas`：虚拟插槽、滚动、手势、互斥的下拉刷新/加载更多、局部与增量排版。
- `SkUiDsl.pas`：HStack/VStack/Box、文本、图片、SVG、循环轮播与布局缓存。
- `SkImageCache.pas`：80 张内存 LRU、磁盘缓存、4 并发下载、按 URL/Owner 合并重绘订阅。
- `SkCardRenderers.Biz.pas`、`Biz.OrderRenderer.pas`：业务布局与图片点击热区。
- `SkAsync.pas`：原生线程池任务、主线程完成回调及 `Finally` 清理。
- `Unit1.pas`：模式切换、分页模拟、失败重试与局部更新演示。
- `SkCardListView.pas`：历史原型，不在当前工程运行链路中。

本轮修复了图片回调注销、过期请求写入、分页状态冲突、失败后重试、分页重复 ID、文本行数限制和轮播首尾空白。模式切换使用窗体持有的单次定时器；分页任务读取请求开始时的参数快照，过期结果在主线程释放。

性能改动：轮播直接更新缓存节点，不再逐帧重建整张卡片；同一上下文对同一图片只订阅一次重绘；`FinishFetch` 的两个重载均支持末尾追加时的增量排版；轮播图片绘制只检查当前图及前后相邻图。

构建与回归说明见 [tests/README.md](tests/README.md)。本轮环境没有 Delphi 编译器，未执行 Delphi 编译、Windows/Android 实机验证或 FPS/内存基准，不能据此认定达到 60/120 FPS。
