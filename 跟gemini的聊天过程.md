<p>这是一套基于 <strong>Delphi FireMonkey (FMX)</strong> 结合 <strong>Skia (FMX.Skia)</strong> 实现的<strong>高性能高性能自绘虚拟化卡片列表</strong>方案。整体设计借鉴了移动端现代 UI 渲染引擎（如 Flutter）的思路，采用“纯画布自绘 + 数据虚拟化”取代了 FMX 传统重量级的子控件树方案。</p>
<p>以下是对这套代码的全面深度分析：</p>
<hr>
<h3>一、 整体架构与设计模式</h3>
<ol>
<li>
<p><strong>渲染架构：Canvas 纯自绘（TSkPaintBox）</strong></p>
<ul>
<li>项目完全摒弃了使用 <code>TVertScrollBox</code> 嵌套 <code>TRectangle</code>/<code>TLabel</code>/<code>TImage</code> 的传统做法，避免了繁重的 FMX 控件树更新、布局计算（Layout Pass）及内存开销。</li>
<li>单一画板承担所有图文绘制，达到了近乎原生 60~120 FPS 的极致滑动性能。</li>
</ul>
</li>
<li>
<p><strong>数据虚拟化（Virtualization / Windowing）</strong></p>
<ul>
<li>根据当前滚动偏移量 <code>ScrollY</code> 和可见高度 <code>Height</code>，通过数学计算仅绘制视口可见区域内的卡片（<code>StartRow</code> 到 <code>EndRow</code>）。即使加载数万条数据，内存和 GPU 负担也不会显著上升。</li>
</ul>
</li>
<li>
<p><strong>双层图片缓存体系（LRU 内存 + 磁盘持久化）</strong></p>
<ul>
<li>实现了 <code>TSkImageCache</code>，拥有基于哈希的二级缓存（L1 内存 LRU 淘汰，L2 本地磁盘缓存），结合后台异步线程下载与主线程无缝刷新，避免滑动时发生任何 I/O 卡顿。</li>
</ul>
</li>
</ol>
<hr>
<h3>二、 核心模块深度剖析</h3>
<h4>1. <code>TSkImageCache</code>（异步多级图片缓存）</h4>
<ul>
<li><strong>L1 内存缓存与 LRU 机制</strong>：
<ul>
<li>使用 <code>TDictionary&lt;string, ISkImage&gt;</code> 做 $O(1)$ 查找，使用 <code>TList&lt;string&gt;</code> 维护访问次序（队列尾部为最新，头部为最旧）。</li>
<li>限制容量为 <code>MAX_LRU_CAPACITY = 60</code>。超过阈值时触发淘汰，依赖 Delphi 接口的 ARC 自动释放显存/内存中的图片资源。</li>
</ul>
</li>
<li><strong>L2 磁盘持久化</strong>：
<ul>
<li>对 URL 采用 <code>THashMD5</code> 生成本地文件名，持久化保存在系统的缓存目录（<code>TPath.GetCachePath</code>），二次进入页面无需重复网络请求。</li>
</ul>
</li>
<li><strong>线程安全与防重复下载</strong>：
<ul>
<li>使用 <code>TMonitor</code> 控制多线程访问安全。</li>
<li>引入 <code>FDownloading: TList&lt;string&gt;</code> 记录正在下载的 URL，防止同一个图片因多次快速重绘触发重复的 HTTP 请求。</li>
</ul>
</li>
</ul>
<h4>2. <code>TSkCardListView</code>（自绘列表与物理滚动组件）</h4>
<ul>
<li><strong>触控与惯性物理模拟</strong>：
<ul>
<li>利用 FMX 原生惯性物理类 <code>TAniCalculations</code>，完美支持触控拖拽后的惯性滑动（Fling）与边缘回弹，并在 <code>HandleAniChange</code> 中驱动 <code>Redraw</code>。</li>
</ul>
</li>
<li><strong>手势判定与点击命中</strong>：
<ul>
<li>记录点击起始点和拖拽位移；当位移 $&gt; 6$ 像素时判定为滑动而非点击，避免误触。</li>
<li>卡片在每次绘制时都会缓存当前的绝对边界 <code>Item.LastCardRect</code> 与“加入购物车”按钮边界 <code>Item.LastActionBtnRect</code>，使得 <code>MouseUp</code> 时能精确命中点击区域（支持子区域事件区分）。</li>
</ul>
</li>
<li><strong>字体多平台兼容</strong>：
<ul>
<li>在 <code>InitTypefaces</code> 中动态探测并加载各平台默认高质量中文字体（Windows: 微软雅黑/黑体；Android: Noto Sans CJK SC；iOS/macOS: PingFang SC），确保跨平台中文排版不掉字、不模糊。</li>
</ul>
</li>
<li><strong>多布局模式支持</strong>：
<ul>
<li><code>vmSingleProduct</code>（单列大图商品卡片，类似外卖/商超列表）。</li>
<li><code>vmDoubleMerchant</code>（双列瀑布流/网格卡片，支持 4:3 封面图、星级评价绘制）。</li>
</ul>
</li>
</ul>
<h4>3. <code>Unit1.pas</code>（控制器与模拟数据）</h4>
<ul>
<li>解耦清晰，通过 <code>TOnCardItemEvent</code> 事件监听卡片点击和按钮点击。</li>
<li>动态构建了包含日期、价格、原价、月售、评分等丰富样式的测试数据源。</li>
</ul>
<hr>
<h3>三、 技术亮点</h3>
<ol>
<li><strong>极佳的渲染性能</strong>：
<ul>
<li>所有文本、圆角、标签、星级（Unicode <code>★</code> 自绘）、划线价格、阴影底色均在 GPU 上通过 Skia 一次性批量绘制，几乎没有 GC 压力。</li>
</ul>
</li>
<li><strong>绘制视口裁剪（Viewport Clip）</strong>：
<ul>
<li>在 <code>Draw</code> 中严格使用 <code>ACanvas.ClipRect(ADest)</code>，确保滚动时卡片不会溢出至上方标题栏或外部边界。</li>
</ul>
</li>
<li><strong>细节打磨完备</strong>：
<ul>
<li>实现了文本过长省略号截断（<code>DrawEllipsisText</code>）。</li>
<li>针对图片未加载完成，预设浅灰占位底色，避免异步加载完成瞬间出现的闪烁感。</li>
</ul>
</li>
</ol>
<hr>
<h3>四、 潜在隐患与优化建议（Refactoring Suggestions）</h3>
<p>代码整体成熟度很高，但若作为商业级项目部署，建议关注以下优化点：</p>
<h4>1. ⚠️ <strong>Draw 循环中的频繁内存分配（关键性能点）</strong></h4>
<ul>
<li><strong>问题</strong>：在 <code>DrawSingleProductCard</code> 和 <code>DrawDoubleMerchantCard</code> 中，每一张卡片绘制都会执行：
<pre><code>LPaint := TSkPaint.Create;
LFont := TSkFont.Create(...);
</code></pre>
在 60 FPS 连续快速滑动时，这意味着<strong>每秒钟都在堆上创建并销毁成百上千个 Paint 和 Font 对象</strong>，会引发频繁的内存碎片和 CPU 负担。</li>
<li><strong>建议</strong>：
将 <code>LPaint</code>、常用的 <code>LFontTitle</code>、<code>LFontSub</code> 作为 <code>TSkCardListView</code> 的私有成员（Field），在初始化时创建一次并在 <code>Draw</code> 中复用，只需在绘制不同元素前修改其 <code>.Color</code>、<code>.Size</code> 等属性。</li>
</ul>
<h4>2. ⚠️ <strong>双列网格模式下的 HitTest Bug</strong></h4>
<ul>
<li><strong>问题</strong>：在 <code>Draw</code> 的 <code>vmDoubleMerchant</code> 模式下：
<pre><code>Item.LastCardRect := CardRect;
</code></pre>
如果在屏幕可视区域内，某些 item 在屏幕外时，它们的 <code>LastCardRect</code> 保存的依然是上一次绘制的位置；或者当卡片滚动出视口后，<code>LastCardRect</code> 没有被重置（失效化），可能导致用户点击空白区域仍触发老位置的点击。</li>
<li><strong>建议</strong>：在 <code>MouseDown</code> 扫描时，除了判断 <code>LastCardRect.Contains</code>，还应校验该项当前索引是否处于可视区间内；或者在每次 <code>Draw</code> 开始时，将不可见卡片的 <code>LastCardRect</code> 置空（如 <code>TRectF.Empty</code>）。</li>
</ul>
<h4>3. 💡 <strong>文本测量性能优化（DrawEllipsisText）</strong></h4>
<ul>
<li><strong>问题</strong>：<code>DrawEllipsisText</code> 采用 <code>while</code> 循环每次减少 1 个字符并调用 <code>AFont.MeasureText</code>，如果长文本较多，这属于线性探测，每帧开销较高。</li>
<li><strong>建议</strong>：改用**二分查找法（Binary Search）**寻找最佳截断字符位置，或者直接使用 Skia 的 <code>TSkParagraph</code> 结合 <code>MaxLines := 1</code> 和 <code>Ellipsis := &#39;...&#39;</code> 进行原生截断排版，效率更高且支持精确的行宽折行。</li>
</ul>
<h4>4. 💡 <strong>滚轮与惯性混合冲突</strong></h4>
<ul>
<li><strong>问题</strong>：在 Windows 平台上，<code>MouseWheel</code> 直接修改了 <code>ViewportPosition</code>，而移动端拖拽则是通过 <code>FAniCalculations.MouseMove</code>。在特定情况下，直接赋值可能会打断惯性动画状态机。</li>
<li><strong>建议</strong>：在 <code>MouseWheel</code> 时调用 <code>FAniCalculations.MouseWheel</code>，让所有物理位移统一由 <code>TAniCalculations</code> 接管计算。</li>
</ul>
<hr>
<h3>五、 总结</h3>
<p>这是一份<strong>高质量、专业度极高</strong>的 Delphi FMX + Skia 源码。它成功攻克了 FireMonkey 在跨平台移动端 UI 列表滑动卡顿、内存开销大的痛点，其实现方案可以直接作为工业级电商 App、信息流 App 的核心列表展示组件。只需要对绘制上下文对象（Paint/Font）的复用稍作调整，即可达到商业级生产环境的极高水准。</p>
<hr>
<p>这样的实现，以后碰到不同的面板，都需要自绘？</p>
<p>你的直觉非常敏锐。<strong>如果每种业务面板都要像现在这样，一行一行去写 <code>DrawRoundRect</code>、计算 <code>TextY + 18</code>、硬编码坐标，那维护成本将是一场灾难。</strong></p>
<p>目前代码中的写法是 <strong>“极限性能验证”</strong>（Proof of Concept）的原型写法，目的是向你展示通过底层 Skia Canvas 绘制能达到多高的帧率和自由度。</p>
<p>在实际工业级项目中，如果你既要 <strong>极佳的滑动性能</strong>，又不想 <strong>“每次都痛苦地手写坐标自绘”</strong>，行业内有以下 <strong>3 种主流的进阶演进方案</strong>：</p>
<hr>
<h3>方案一：组件池化复用（RecyclerView / 虚拟化 Frame 模式）</h3>
<blockquote>
<p><strong>开发体验最好：直接在 Delphi 可视化设计器（Form Designer）里拖控件设计卡片！</strong></p>
</blockquote>
<p>不要在画板上把所有东西“画”出来，而是回归 FMX 控件，但<strong>只创建视口看得见的控件（约 8~10 个）循环复用</strong>：</p>
<pre><code>[数据层: 10000 条数据] 
       ↓ 映射
[视口可见区域: 只创建 8 个 TFrame] 
       ↓ 滑动时
[顶部滑出的 Frame 被挪到最底部，仅刷新内容（Data Binding）]
</code></pre>
<ul>
<li><strong>怎么做</strong>：
<ol>
<li>遇到新面板，新建一个 <code>TFrame</code>（比如 <code>TProductCardFrame</code>），在里面可视化拖拉放 <code>Label</code>、<code>Image</code>、<code>Button</code>、布局排版。</li>
<li>写一个通用的 <code>TVirtualListView</code>，屏幕能放 8 个卡片，就只 <code>Create</code> 10 个 Frame（多 2 个做缓冲）。</li>
<li>滑动时，<strong>绝对不销毁创建 Frame</strong>，只改变 Frame 的 <code>Position.Y</code> 并执行 <code>Frame.BindData(Item)</code>。</li>
</ol>
</li>
<li><strong>优点</strong>：<strong>所见即所得</strong>。换样式只需在设计器里拖拽排版，0 自绘代码。</li>
<li><strong>性能</strong>：因为内存里永远只有 10 个控件，内存极低、无 GC 压力，滑动同样能保持 60 FPS。</li>
</ul>
<hr>
<h3>方案二：模板渲染器解耦（Card Renderer 模式）</h3>
<blockquote>
<p><strong>架构最正统：保留纯自绘的高性能，但把“列表引擎”和“卡片外观”彻底拆开。</strong></p>
</blockquote>
<p>现在的代码缺陷在于 <code>TSkCardListView</code> 既管<strong>滚动/缓存</strong>，又管<strong>具体业务长什么样</strong>（紧耦合）。</p>
<ul>
<li><strong>改进方式</strong>：把绘制抽象为一个接口或基类：
<pre><code>type
  TBaseCardRenderer = class
  public
    function MeasureHeight(AItem: TCardItem; AWidth: Single): Single; virtual; abstract;
    procedure DrawCard(const ACanvas: ISkCanvas; AItem: TCardItem; const ARect: TRectF); virtual; abstract;
    function HandleClick(AItem: TCardItem; const APoint: TPointF): Boolean; virtual;
  end;
</code></pre>
</li>
<li>你的列表组件 <code>TSkCardListView</code> 只负责：
<ul>
<li>计算滚动、物理惯性、手势判定；</li>
<li>图片下载缓存；</li>
<li>调用 <code>FRenderer.DrawCard(...)</code>。</li>
</ul>
</li>
<li>以后来一个新面板（如“外卖卡片”、“评论卡片”），你<strong>不需要改动核心列表引擎的任何一行代码</strong>，只需派生一个 <code>TCommentCardRenderer</code> 挂上去即可。</li>
</ul>
<hr>
<h3>方案三：轻量级声明式排版（Mini Flexbox / 类似 Flutter 思想）</h3>
<blockquote>
<p><strong>高阶方案：用代码组合出“盒模型”，无需算数学坐标。</strong></p>
</blockquote>
<p>如果你追求极致性能不想用 FMX 控件，但又讨厌算 <code>Top + 16</code>，可以封装一套极简的<strong>声明式 UI 树</strong>（类似于 Flutter / SwiftUI 的原理）。</p>
<p>你不需要算坐标，而是像这样声明面板：</p>
<pre><code>// 伪代码：在 Renderer 里面这样写卡片结构
Card := Column.Spacing(8).Children([
  Row.Children([
    Image(AItem.ImageUrl).Size(80, 80).Radius(4),
    Column.Flex(1).Children([
      Text(AItem.Title).Bold.Size(14),
      Text(AItem.Subtitle).Color(TAlphaColors.Gray),
      Row.Between([
        Price(AItem.Price),
        Button(&#39;购买&#39;).OnClick(...)
      ])
    ])
  ])
]);

// 引擎根据卡片宽度，自动单趟遍历（Measure &amp; Layout）算出所有元素的 Bounds，然后统一 Draw
Card.Layout(CardWidth); 
Card.Render(ACanvas);
</code></pre>
<p>用 200~300 行底层代码写一个简化的流式布局器（Flow/Flex），以后任何新面板都只需要几行“结构化代码”拼装即可，<strong>彻底消灭手工计算像素坐标</strong>。</p>
<hr>
<h3>总结：未来的选型建议</h3>
<p>| 业务场景                                           | 推荐选型                             | 理由                                                         |
| :------------------------------------------------- | :----------------------------------- | :----------------------------------------------------------- |
| <strong>企业级应用 / 复杂表单 / 经常变需求</strong>             | <strong>方案一（Frame 对象池复用）</strong>       | <strong>开发效率第一</strong>，直接用 Delphi 设计器拖拽，换皮肤改版最轻松。 |
| <strong>核心爆款页面（如电商首页信息流、短视频评论区）</strong> | <strong>方案二（自绘 + Renderer 接口化）</strong> | <strong>性能第一</strong>，千级数据秒开，不卡顿。只需将现在的代码按 Renderer 模式拆分解耦即可。 |
| <strong>自研跨平台移动端 UI 框架</strong>                       | <strong>方案三（自绘 + 声明式盒模型）</strong>    | 既有自绘的极致性能与跨平台一致性，又有现代化布局语法的灵活性。 |</p>
<hr>
<p>经常开发app，以后会有大量不同的列表不同的样式，做为高级开发并拥有发展眼光，哪个方案更适合</p>
<p>站在<strong>高级开发架构师</strong>的视角和<strong>长期技术演进</strong>的角度，结论非常明确：</p>
<h3>终极选型：【方案三（轻量级声明式组件化）】 + 【方案二（Renderer 接口解耦）】的融合架构</h3>
<p><strong>绝对不要停留在“每做一个页面就手工算像素自绘”（方案二的原生状态）</strong>，那是一次性代码，毫无资产沉淀；
<strong>也不建议长期重度依赖“Frame 对象池”（方案一）</strong>，因为 FMX 的底层控件树（Layout Pass、事件派发、消息循环）在移动端无论怎么优化，依然有原生框架的历史包袱，无法做到真正的 120Hz 丝滑和像素级跨平台绝对一致。</p>
<p>整个前端与移动端架构过去 10 年的演进史（Web 放弃了 DOM 漫天飞转向了 React/Vue；Android 从 ListView 放弃了 XML 转向了 Jetpack Compose；iOS 转向了 SwiftUI；Google 打造了 Flutter）已经替我们验证了唯一正确的道路：
👉 <strong>“底层无状态 Canvas 渲染 + 上层声明式组件（Component/Flexbox）树”。</strong></p>
<hr>
<h3>一、 架构蓝图：你该如何设计这个“高产、高性能”系统？</h3>
<p>作为拥有长远眼光的开发者，你应该为自己/团队沉淀一套<strong>微型的 Delphi 跨平台 UI 渲染引擎</strong>。整个架构分为三层：</p>
<pre><code>┌────────────────────────────────────────────────────────┐
│ 业务层 (Business Cards) : 几行代码拼装新卡片 (商品/商家/评论/个人中心) │
├────────────────────────────────────────────────────────┤
│ 布局原子层 (Primitives DSL) : HStack, VStack, Padding, Text, Img│
├────────────────────────────────────────────────────────┤
│ 渲染与虚拟化底座 (Core Engine) : 视口裁切, 滑动物理, 多级LRU图片缓存│
└────────────────────────────────────────────────────────┘
</code></pre>
<h4>1. 底层：列表虚拟化引擎（你当前已写完 80%）</h4>
<ul>
<li>它只干三件事：
<ol>
<li>计算滑动的视口范围；</li>
<li>驱动惯性物理系统与双级图片缓存；</li>
<li>提供 <code>ISkCanvas</code>，并调用上层的渲染接口：<code>Renderer.Draw(Canvas, ItemRect, Data)</code>.</li>
</ol>
</li>
</ul>
<h4>2. 中层：轻量级盒模型组件系统（核心研发资产）</h4>
<p>你只需要封装几个基础的<strong>流式布局原语（Layout Primitives）</strong>，基于链式调用（Fluent API）：</p>
<ul>
<li>容器类：<code>VStack</code>（纵向排列）、<code>HStack</code>（横向排列）、<code>Padding</code>（内边距）、<code>Spacer</code>（弹簧占位）。</li>
<li>渲染原子：<code>SkText</code>（文本/自动折行/省略号）、<code>SkImage</code>（异步网络图/圆角）、<code>SkBadge</code>（标签描边）。</li>
</ul>
<h4>3. 业务层：以后开发一个全新样式的列表卡片，只需这样写：</h4>
<p>遇到新面板，你<strong>既不需要算坐标，也不需要拉 FMX 控件</strong>，像写 Flutter/SwiftUI 一样在 5 分钟内声明出来：</p>
<pre><code>type
  // 比如这是一个全新的“外卖商家”卡片渲染器
  TMerchantCardRenderer = class(TInterfacedObject, ICardRenderer&lt;TMerchantItem&gt;)
  public
    function BuildLayout(Item: TMerchantItem): IUiElement;
  end;

function TMerchantCardRenderer.BuildLayout(Item: TMerchantItem): IUiElement;
begin
  // 用声明式语法描述布局结构：
  Result := HStack.Spacing(10).Padding(12).Children([
    // 左侧图片
    AsyncImage(Item.AvatarUrl).Size(80, 80).Round(8),

    // 右侧纵向内容
    VStack.Flex(1).Children([
      // 标题 + 距离
      HStack.Between([
        Text(Item.Name).Bold.FontSize(15).Color($FF1A1A1A),
        Text(Item.Distance).FontSize(11).Color($FF999999)
      ]),

      Spacer.Height(6),

      // 评分与月售
      HStack.Spacing(8).Children([
        RatingBar(Item.Score),
        Text(&#39;月售 &#39; + Item.Sales).FontSize(11).Color($FF666666)
      ]),

      Spacer.Height(8),

      // 优惠标签行 (动态遍历生成)
      HStack.Spacing(4).Children(
        Item.Tags.Map(function(T: string): IUiElement 
        begin 
          Result := Badge(T).BorderColor($FFE6432E).TextColor($FFE6432E); 
        end)
      )
    ])
  ]);
end;
</code></pre>
<hr>
<h3>二、 为什么这种方案最适合“有大量不同列表样式”的场景？</h3>
<h4>1. 极致的开发与维护效率（5 分钟一个新卡片）</h4>
<ul>
<li><strong>免除死板坐标计算</strong>：谁来改版页面，只要修改 <code>Spacing(10)</code> 或者调整 <code>HStack/VStack</code> 的嵌套关系即可，引擎会自动单趟完成父子节点的尺寸计算（Measure）和布局（Layout）。</li>
<li><strong>UI 资产复用</strong>：你写一次 <code>RatingBar</code>（评分星级）组件，全公司所有 App 的所有列表只要调用 <code>RatingBar(Score)</code> 即可，一次沉淀，永久复用。</li>
</ul>
<h4>2. 极致的性能（降维打击 FMX 传统控件）</h4>
<ul>
<li><strong>0 句柄、0 布局震颤</strong>：整个列表在操作系统眼里，依然<strong>只有一个原生的 PaintBox 视图</strong>。</li>
<li><strong>单次 GPU 提交</strong>：不论你界面嵌套了多少层 HStack/VStack，它在本质上只是在纯内存中完成几个算术加减法（耗时小于 0.05ms），然后一笔画进 Skia 的 GPU 指令队列中，任何低端 Android 机滑动都能稳稳贴在 60/120 帧。</li>
</ul>
<h4>3. 跨平台绝对一致的呈现</h4>
<ul>
<li>传统的 FMX 控件在 Windows、iOS、Android 上的字体基线、内边距、圆角抗锯齿处理往往有微小差异，排版容易“破相”。</li>
<li>由 Skia 核心直接接管盒模型绘制，<strong>可以保证在所有平台上 100% 像素级一致</strong>，完全消除跨平台调样式的痛苦。</li>
</ul>
<hr>
<h3>三、 建议的落地执行演进路线（3 步走）</h3>
<p>你不必一口气写出非常复杂的 Flexbox 布局引擎，建议分阶段演进：</p>
<ul>
<li><strong>第一阶段（规范解耦 - 耗时 1 天）</strong>：
把当前的 <code>SkCardListView.pas</code> 进行代码拆分。
<ul>
<li>将滚动、惯性、点击命中、缓存保留在 <code>TSkVirtualListView</code> 中。</li>
<li>将绘制提取成 <code>ICardRenderer</code> 接口。此时新卡片依然手绘，但核心框架已经与业务剥离。</li>
</ul>
</li>
<li><strong>第二阶段（建立极简盒模型 - 耗时 2~3 天）</strong>：
编写 3 个基础类：<code>TUiNode</code>（基类）、<code>TLinearBox</code>（具备横向/纵向排版能力的容器）、<code>TLeafNode</code>（文本、图片叶子节点）。
<ul>
<li>实现两个标准算法：<code>Measure(MaxWidth)</code>（自底向上计算宽高）和 <code>Layout(Rect)</code>（自顶向下分配坐标）。</li>
</ul>
</li>
<li><strong>第三阶段（DSL 语法糖与基础库沉淀 - 持续迭代）</strong>：
通过 Delphi 的流式调用（Fluent API），包装出 <code>HStack</code>、<code>VStack</code>、<code>Text</code>、<code>AsyncImage</code> 等函数，以后任何新人进团队，只需看示例拼积木即可。</li>
</ul>
<p><strong>总结</strong>：
手写坐标是“手工作坊”，Frame 拖控件是“借用现成旧轮子”，而<strong>自建 Skia 声明式微型组件系统</strong>才是高级跨平台移动开发者的“现代化自动化工厂”。一旦建成，后续面对几十个风格迥异的列表 App，你将具备降维打击级的交付速度与性能优势。</p>
<hr>
<p>你在BuildLayout中写的声明式语法描述布局结构，我看不太懂，帮我详细解释下</p>
<p>很多从传统 Delphi（或者 Win32 / 原生 FMX）转过来的高级开发者，第一次看到这种语法都会觉得陌生。这很正常，因为传统的 Delphi 是**“命令式排版”**（你要精确告诉电脑把控件放在 X=10, Y=20 的绝对坐标上）。</p>
<p>而我上面写的，是目前移动端领域（Flutter、SwiftUI、Jetpack Compose、Vue/React）最主流的**“声明式排版（Declarative UI）”**。</p>
<p>在 Delphi 中，它<strong>既不是新语言，也不是黑魔法</strong>，它纯粹是利用了 Delphi 自带的 <strong>“接口/类 + 链式调用（Fluent API） + 动态数组字面量 <code>[...]</code>”</strong> 封装出来的。</p>
<p>下面我用白话、对比、以及 Delphi 底层的实现机制，彻底给你讲透它到底是怎么工作的。</p>
<hr>
<h3>一、 核心概念对比：命令式 vs 声明式</h3>
<h4>1. 传统的“命令式”（你现在代码里的做法）</h4>
<p>你必须把 CPU 当成一个“没有自主思考能力的工人”，每一步都要手算坐标：</p>
<blockquote>
<p>“在 <code>X=8, Y=8</code> 处画一张宽高 96x108 的图片；
算一下文本的 X 是 <code>8 + 96 + 10 = 114</code>；
文本 Y 是 <code>ARect.Top + 22</code>，画第一行标题；
把 Y 增加 18 像素（<code>TextY := TextY + 18</code>），画第二行副标题；
底部按钮算出宽度 68，右边距 8，所以按钮 X 是 <code>ARect.Right - 76</code>……”</p>
</blockquote>
<ul>
<li><strong>缺点</strong>：如果产品经理说“把左边图片宽度改成 80，再往右挪 5 像素”，你后面<strong>所有手写的数字变量全部要重新心算改一遍</strong>，极易出错。</li>
</ul>
<h4>2. 现代的“声明式”（BuildLayout 的做法）</h4>
<p>你只需要告诉电脑**“这个界面的结构关系（盒子关系）是什么”**，绝对坐标让代码自动帮你算：</p>
<blockquote>
<p>“整张卡片是一个<strong>横向排布的盒子（HStack）</strong>，盒子内部元素之间间隔 10 像素；
盒子里放两个东西：</p>
<ol>
<li>左边放一个 80x80 的图片；</li>
<li>右边放一个<strong>纵向排布的盒子（VStack）</strong>，把剩下的空间占满（Flex=1）；
这个纵向盒子里依次从上到下放：标题、副标题、价格。”</li>
</ol>
</blockquote>
<hr>
<h3>二、 逐行拆解我写的那段代码</h3>
<p>我们把那段看似神秘的代码一行行翻译成 Delphi 概念：</p>
<pre><code>Result := HStack.Spacing(10).Padding(12).Children([
</code></pre>
<ul>
<li><strong><code>HStack</code></strong>：即 Horizontal Stack（<strong>水平排布盒</strong>），代表这个容器里面的子元素都是<strong>从左往右横着排</strong>。</li>
<li><strong><code>.Spacing(10)</code></strong>：这个横向盒子里，每个子元素之间自动留 10 像素空隙。（<strong>你再也不用手动写 <code>X := X + Width + 10</code> 了</strong>）。</li>
<li><strong><code>.Padding(12)</code></strong>：这个盒子的四周内边距留白 12 像素。</li>
<li><strong><code>.Children([ ... ])</code></strong>：利用了 Delphi 的<strong>开放数组构造器语法 <code>[...]</code></strong>，把子节点像树枝一样挂到盒子里。</li>
</ul>
<pre><code>    // 第1个子元素：左侧图片
    AsyncImage(Item.AvatarUrl).Size(80, 80).Round(8),
</code></pre>
<ul>
<li>告诉盒子：“我的第 1 个孩子是一张图片，大小固定为 80x80，圆角为 8”。</li>
<li>此时图片会自动被放在 <code>X = 12 (内边距), Y = 12</code> 的位置。</li>
</ul>
<pre><code>    // 第2个子元素：右侧纵向内容容器
    VStack.Flex(1).Children([
</code></pre>
<ul>
<li><strong><code>VStack</code></strong>：即 Vertical Stack（<strong>垂直排布盒</strong>），代表它内部的所有子元素都是<strong>从上往下竖着排</strong>。</li>
<li><strong><code>.Flex(1)</code></strong>：弹性系数。类似于网页 CSS Flexbox。意思是：“左边图片占了 80 宽之后，<strong>右边剩下的所有可用宽度全部归我这个 VStack 所有</strong>”。</li>
</ul>
<pre><code>      // 标题 + 距离（两端对齐）
      HStack.Between([
        Text(Item.Name).Bold.FontSize(15).Color($FF1A1A1A),
        Text(Item.Distance).FontSize(11).Color($FF999999)
      ]),
</code></pre>
<ul>
<li><strong><code>HStack.Between</code></strong>：这也是一个横向排布盒，但它的对齐规则是两端对齐（Space-Between）——<strong>把商家名顶在最左边，把距离（如 &#39;1.2km&#39;）顶在最右边</strong>。（你不需要再写 <code>ARect.Right - TextWidth</code> 去算右侧对齐坐标了）。</li>
</ul>
<hr>
<h3>三、 底层原理：Delphi 是如何用普通代码实现它的？</h3>
<p>这套机制在底层<strong>极度简单</strong>，没有任何复杂的运行时，它本质上就是<strong>面向对象的“组合模式（Composite Pattern）”</strong>。</p>
<p>整个底层只需要三个步骤：</p>
<h4>步骤 1：树状节点接口定义</h4>
<p>所有的元素（文本、图片、HStack、VStack）都实现同一个简单的接口：</p>
<pre><code>type
  IUiElement = interface
    // 1. 测量自己想要多大 (Measure)
    function Measure(MaxWidth, MaxHeight: Single): TSizeF;
    // 2. 父节点分配给自己的绝对坐标 (Layout)
    procedure Layout(const ARect: TRectF);
    // 3. 真正执行 Skia 绘制 (Draw)
    procedure Draw(const ACanvas: ISkCanvas);
  end;
</code></pre>
<h4>步骤 2：自动算坐标的核心（以 <code>HStack</code> 为例）</h4>
<p>为什么你不用算坐标了？因为 <strong><code>HStack</code> 在它的 <code>Layout</code> 方法内部帮你把加减法写死了</strong>：</p>
<pre><code>// 这是底层容器写的通用逻辑，你写一次，终身受益：
procedure THStack.Layout(const ARect: TRectF);
var
  CurX: Single;
  Child: IUiElement;
begin
  CurX := ARect.Left + FPaddingLeft; // 从左内边距开始
  
  for Child in FChildren do
  begin
    // 给每一个子元素分配 Rect，并把 X 向右推进
    Child.Layout(RectF(CurX, ARect.Top, CurX + Child.DesiredWidth, ARect.Bottom));
    
    // 自动累加：当前坐标 + 宽度 + 间距（这行代码解放了你的人生）
    CurX := CurX + Child.DesiredWidth + FSpacing; 
  end;
end;
</code></pre>
<h4>步骤 3：怎么实现链式调用（Fluent API）？</h4>
<p>很多人好奇 <code>HStack.Spacing(10).Padding(12)</code> 在 Delphi 里怎么写？
其实就是让函数<strong>返回对象自己（<code>Result := Self</code>）</strong>：</p>
<pre><code>type
  THStack = class(TInterfacedObject, IUiElement)
  private
    FSpacing: Single;
    FPadding: Single;
  public
    function Spacing(AVal: Single): THStack;
    function Padding(AVal: Single): THStack;
  end;

function THStack.Spacing(AVal: Single): THStack;
begin
  FSpacing := AVal;
  Result := Self; // 返回自身，允许后面继续点点点 (.)
end;
</code></pre>
<hr>
<h3>四、 整个运行流程串起来是怎样的？</h3>
<p>当你滑动列表，需要绘制一张卡片时：</p>
<ol>
<li><strong>构型（微秒级）</strong>：列表引擎调用你的 <code>BuildLayout(Item)</code>，在纯内存里以极快的速度 new 出这棵简单的结构树（几百纳秒级，几乎不耗 CPU）。</li>
<li><strong>布局（算数学）</strong>：列表引擎对根节点执行 <code>Root.Layout(CardRect)</code>。
<ul>
<li>根节点（HStack）把宽度分给图片和右边的 VStack；</li>
<li>VStack 自动算出第一行 Text 的 Y、第二行 Text 的 Y。<strong>所有坐标瞬间计算完毕！</strong></li>
</ul>
</li>
<li><strong>渲染（一笔画）</strong>：列表引擎调用 <code>Root.Draw(ACanvas)</code>。
<ul>
<li>树开始递归，遇到图片节点就调 <code>Canvas.DrawImageRect</code>；</li>
<li>遇到文字节点就调 <code>Canvas.DrawSimpleText</code>。</li>
</ul>
</li>
</ol>
<h3>总结</h3>
<p>这种声明式语法，<strong>并不是去掉了底层的自绘</strong>，而是<strong>把你从“机械重复计算像素坐标”的苦力活中解放出来</strong>，把算坐标的加减法交给了 <code>HStack/VStack</code> 这些容器底层。</p>
<p>作为开发者，你以后写任何复杂列表，脑子里想的都是**“这个界面是怎么分块切图的”**（行、列、边距），几行代码拼装出来，剩下的所有计算和渲染全自动完成。这才是现代 UI 架构最迷人的地方。</p>
<hr>
<p>目前的列表是上下滚动，是否可以在item里水平放置多张图片，通过左划右划的方式切换图片</p>
<p><strong>完全可以，而且在纯 Skia 自绘架构下实现这种效果，性能会远远甩开传统原生控件！</strong></p>
<p>在电商 App（如淘宝、得物、拼多多、Airbnb）中，这种**“外层垂直滚动列表 + 内层卡片横向手势画廊（Image Carousel）”**非常普遍。</p>
<p>在纯自绘架构下，不要去嵌套任何 <code>THorizontalScrollBox</code>，依然是<strong>纯画布渲染 + 手势向量裁决</strong>。</p>
<hr>
<h3>一、 核心技术难点：手势冲突裁决（Gesture Arena）</h3>
<p>你手指按在卡片的图片上滑动时，系统面临一个抉择：<strong>“用户到底是要上下滑列表，还是要左右翻图片？”</strong></p>
<p>解决这个问题的标准工业级方案是**“手势仲裁机制（角度/向量判断）”**：</p>
<pre><code>           垂直方向 (DeltaY)
                 ↑
                 │   [判定为上下滚动列表]
                 │   /
                 │  / 
                 │ /  
      45度分割线  │/________ 
                 │\         \
                 │ \         [判定为横向切换图片]
                 │  \
─────────────────┼──────────────────→ 水平方向 (DeltaX)
                 │
</code></pre>
<ol>
<li><strong>按下（MouseDown）</strong>：只记录坐标，<strong>不触发任何滚动</strong>，状态设为 <code>tmDeciding</code>（决策中）。</li>
<li><strong>移动（MouseMove）</strong>：
<ul>
<li>当手指移动距离超过阀值（如 6 像素）：</li>
<li>如果 <code>Abs(DeltaX) &gt; Abs(DeltaY)</code> 并且落点在图片区域：<strong>锁定为横向轮播模式（Horizontal Swipe）</strong>，外层列表彻底静止，所有的 X 位移喂给当前卡片的图片偏移量。</li>
<li>如果 <code>Abs(DeltaY) &gt;= Abs(DeltaX)</code>：<strong>锁定为垂直滚动模式（Vertical Scroll）</strong>，横向画廊不响应。</li>
</ul>
</li>
<li><strong>松手（MouseUp）</strong>：
<ul>
<li>如果横向拖拽超过图片宽度的 20%，**自动吸附（Page Snapping）**到下一张或上一张图；否则回弹复位。</li>
</ul>
</li>
</ol>
<hr>
<h3>二、 核心改造代码实现</h3>
<p>只需要在原有的架构上做 3 处轻量改造：</p>
<h4>1. 数据实体增加多图支持与自身滚动状态</h4>
<p>在 <code>TCardItem</code> 中增加轮播数据：</p>
<pre><code>type
  TCardItem = class
  public
    // ... 原有字段保持不变 ...
    Images: TArray&lt;string&gt;;     // 该卡片的多张图片 URL
    ActiveImageIndex: Integer;  // 当前显示第几张图 (0, 1, 2...)
    ImageScrollOffset: Single;  // 横向拖拽时的临时像素偏移量 (0 为居中)
    
    // 内部命中区域
    LastImageRect: TRectF;      // 记录图片所在的矩形区域
  end;
</code></pre>
<h4>2. 在组件中加入手势裁决状态机</h4>
<p>在 <code>TSkCardListView</code> 私有区增加状态枚举：</p>
<pre><code>type
  TTouchMode = (tmNone, tmDeciding, tmVerticalScroll, tmHorizontalSwipe);

// TSkCardListView 私有变量
private
  FTouchMode: TTouchMode;
  FActiveSwipeItem: TCardItem; // 正在被横向滑动的卡片
</code></pre>
<p>在手势方法中进行仲裁：</p>
<pre><code>procedure TSkCardListView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
begin
  inherited;
  if Button = TMouseButton.mbLeft then
  begin
    FIsMouseDown := True;
    FDownPos := PointF(X, Y);
    FLastMousePos := FDownPos;
    FTouchMode := tmDeciding; // 进入决策等待态
    FActiveSwipeItem := nil;

    // 检查是否点中了某张卡片的图片区域
    for I := 0 to FItems.Count - 1 do
    begin
      if FItems[I].LastImageRect.Contains(FDownPos) and (Length(FItems[I].Images) &gt; 1) then
      begin
        FActiveSwipeItem := FItems[I];
        Break;
      end;
    end;

    FAniCalculations.MouseDown(X, Y);
  end;
end;

procedure TSkCardListView.MouseMove(Shift: TShiftState; X, Y: Single);
var
  CurPos: TPointF;
  DeltaX, DeltaY: Single;
begin
  inherited;
  if not FIsMouseDown then Exit;

  CurPos := PointF(X, Y);
  DeltaX := CurPos.X - FDownPos.X;
  DeltaY := CurPos.Y - FDownPos.Y;

  // 1. 决策阶段：判断手指滑动主方向
  if (FTouchMode = tmDeciding) and (CurPos.Distance(FDownPos) &gt; 6) then
  begin
    if (FActiveSwipeItem &lt;&gt; nil) and (Abs(DeltaX) &gt; Abs(DeltaY)) then
      FTouchMode := tmHorizontalSwipe // 锁定横向滑动图片！
    else
      FTouchMode := tmVerticalScroll; // 锁定垂直滚动列表！
  end;

  // 2. 根据决策执行不同逻辑
  case FTouchMode of
    tmVerticalScroll:
      begin
        // 执行原有的垂直滚动
        ScrollByDelta(-(CurPos.Y - FLastMousePos.Y));
        FAniCalculations.MouseMove(X, Y);
      end;

    tmHorizontalSwipe:
      begin
        // 横向驱动当前卡片的图片偏移
        if FActiveSwipeItem &lt;&gt; nil then
        begin
          FActiveSwipeItem.ImageScrollOffset := CurPos.X - FDownPos.X;
          Redraw; // 局部重绘
        end;
      end;
  end;

  FLastMousePos := CurPos;
end;

procedure TSkCardListView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  ImgWidth: Single;
begin
  inherited;
  if FIsMouseDown then
  begin
    FIsMouseDown := False;

    // 处理横向轮播松手后的“分页吸附 (Snapping)”
    if (FTouchMode = tmHorizontalSwipe) and (FActiveSwipeItem &lt;&gt; nil) then
    begin
      ImgWidth := FActiveSwipeItem.LastImageRect.Width;
      
      // 滑动幅度超过 20% 时切换图片
      if FActiveSwipeItem.ImageScrollOffset &lt; -ImgWidth * 0.2 then
      begin
        // 向左滑：下一张
        if FActiveSwipeItem.ActiveImageIndex &lt; High(FActiveSwipeItem.Images) then
          Inc(FActiveSwipeItem.ActiveImageIndex);
      end
      else if FActiveSwipeItem.ImageScrollOffset &gt; ImgWidth * 0.2 then
      begin
        // 向右滑：上一张
        if FActiveSwipeItem.ActiveImageIndex &gt; 0 then
          Dec(FActiveSwipeItem.ActiveImageIndex);
      end;

      // 归位偏移量（进阶可加上平滑缓动动画）
      FActiveSwipeItem.ImageScrollOffset := 0;
      FActiveSwipeItem := nil;
      Redraw;
    end
    else
    begin
      FAniCalculations.MouseUp(X, Y);
    end;

    FTouchMode := tmNone;
  end;
end;
</code></pre>
<h4>3. 在 Skia 画布中绘制“水平画廊”与“分页指示器”</h4>
<p>绘制这一步极其简单，<strong>利用 Skia 的 <code>ClipRect</code> 裁剪视口</strong>，将当前图片、上一张、下一张画在对应的偏移位置即可：</p>
<pre><code>procedure TSkCardListView.DrawSingleProductCard(const ACanvas: ISkCanvas; AItem: TCardItem; const ARect: TRectF);
var
  ImgRect, CurImgRect: TRectF;
  I: Integer;
  OffsetX, ImgW, DotX: Single;
  LImg: ISkImage;
  LPaint: ISkPaint;
begin
  // ... 前面绘制卡片背景代码保持不变 ...

  ImgRect := RectF(ARect.Left + 8, ARect.Top + 8, ARect.Left + 104, ARect.Top + 116);
  AItem.LastImageRect := ImgRect; // 缓存命中区域！
  ImgW := ImgRect.Width;

  ACanvas.Save;
  try
    // 关键：裁剪在图片圆角矩形内，超出部分不显示
    ACanvas.ClipRoundRect(TSkRoundRect.Create(ImgRect, 6, 6), TSkClipOp.Intersect, True);

    // 计算当前滑动的总基准 X
    OffsetX := - (AItem.ActiveImageIndex * ImgW) + AItem.ImageScrollOffset;

    // 绘制所有图片（虚拟化只画相邻可见的 2~3 张）
    for I := 0 to High(AItem.Images) do
    begin
      CurImgRect := RectF(
        ImgRect.Left + OffsetX + (I * ImgW),
        ImgRect.Top,
        ImgRect.Left + OffsetX + ((I + 1) * ImgW),
        ImgRect.Bottom
      );

      // 只绘制处于视口范围内的图片
      if (CurImgRect.Right &gt; ImgRect.Left) and (CurImgRect.Left &lt; ImgRect.Right) then
      begin
        LImg := TSkImageCache.GetImage(AItem.Images[I], procedure begin Redraw; end);
        if LImg &lt;&gt; nil then
          ACanvas.DrawImageRect(LImg, CurImgRect)
        else
        begin
          LPaint := TSkPaint.Create;
          LPaint.Color := $FFF0F0F2;
          ACanvas.DrawRect(CurImgRect, LPaint);
        end;
      end;
    end;

    // 绘制底部小圆点（分页指示器 Pagination Dots）
    if Length(AItem.Images) &gt; 1 then
    begin
      LPaint := TSkPaint.Create;
      LPaint.AntiAlias := True;
      for I := 0 to High(AItem.Images) do
      begin
        DotX := ImgRect.CenterPoint.X + (I - Length(AItem.Images)/2) * 7;
        if I = AItem.ActiveImageIndex then
          LPaint.Color := TAlphaColors.White       // 选中白点
        else
          LPaint.Color := $80FFFFFF;              // 半透明灰白点
        ACanvas.DrawCircle(PointF(DotX, ImgRect.Bottom - 6), 2, LPaint);
      end;
    end;

  finally
    ACanvas.Restore;
  end;

  // ... 后面绘制右侧文字、价格按钮的代码保持不变 ...
end;
</code></pre>
<hr>
<h3>三、 这种实现的杀手级优势</h3>
<ol>
<li><strong>绝对零卡顿</strong>：
在 FMX 里如果卡片里塞原生 <code>TScrollBox</code>，当列表滑到 50 个卡片时，内存会爆炸，手势冲突会让你抓狂（iOS 的手势捕获常常吞掉事件）。而纯 Skia 方案中，<strong>多张图片只是单纯的 $X + (I \times Width)$ 算术偏移</strong>，每秒 120 帧极其平顺。</li>
<li><strong>状态天然隔离</strong>：
每个 <code>TCardItem</code> 记录自己的 <code>ActiveImageIndex</code>，列表上下滚动时，<strong>没有任何图片错位或状态丢失</strong>的问题。</li>
<li><strong>扩展性极强</strong>：
不仅可以滑动，你还可以在 <code>MouseUp</code> 中加上一个轻量插值器（Lerp / 动画），让手指松开时带有像 iPhone 原生画廊一样的平滑弹簧阻尼回弹效果。</li>
</ol>
<hr>
<p>链接调用是否可以中上绘制边框，绘制类似TRectange，有fill、stroke等常用属性，是否可以使用Tpath机制显示SVG图像</p>
<p><strong>完全可以，而且这两点恰恰是 Skia 最强大、最拿手的“看家本领”！</strong></p>
<p>用链式调用实现类似 <code>TRectangle</code>（填充、描边、圆角、甚至阴影），以及像 <code>TPath</code> 一样用一行 SVG Path 字符串渲染矢量图，代码不仅极其优雅，而且由于直接走 Skia GPU 指令，<strong>渲染性能是 FMX 原生 <code>TRectangle</code> 和 <code>TPath</code> 的数倍以上</strong>。</p>
<p>下面为你详细展示如何将这两大能力融入到链式语法中。</p>
<hr>
<h3>一、 类似 TRectangle 的边框与填充（Fill &amp; Stroke）</h3>
<p>在声明式语法中，我们可以封装一个万能容器节点（通常称为 <code>Box</code> 或 <code>Container</code>），支持链式配置：</p>
<ul>
<li><code>.Fill(Color)</code>：背景填充色</li>
<li><code>.Stroke(Color, Width)</code>：描边颜色和线条粗细</li>
<li><code>.CornerRadius(R)</code>：圆角大小（甚至可以单设某一个角）</li>
<li><code>.Shadow(Blur, OffsetY, Color)</code>：外阴影</li>
</ul>
<h4>1. 开发者以后的调用方式：</h4>
<pre><code>// 画一个带描边、白色背景、圆角的商品卡片底板
Box.Width(200).Height(100)
   .Fill(TAlphaColors.White)                     // 类似 TRectangle.Fill
   .Stroke($FFE0E0E0, 1.5)                       // 类似 TRectangle.Stroke
   .CornerRadius(10)                             // 圆角
   .Padding(8)                                   // 内边距
   .Children([ ... ]);                           // 里面可以塞文字、图片
</code></pre>
<h4>2. 底层在 Skia 中是如何实现的？</h4>
<p>在底层渲染器内部，只需要调用两次 Skia Canvas（先画 Fill，再画 Stroke）：</p>
<pre><code>procedure TBoxNode.Draw(const ACanvas: ISkCanvas);
var
  LPaint: ISkPaint;
  LRRect: TSkRoundRect;
begin
  LRRect := TSkRoundRect.Create(FLayoutBounds, FCornerRadius, FCornerRadius);
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  // 1. 绘制填充背景 (Fill)
  if FHasFill then
  begin
    LPaint.Style := TSkPaintStyle.Fill;
    LPaint.Color := FFillColor;
    ACanvas.DrawRoundRect(LRRect, LPaint);
  end;

  // 2. 绘制描边 (Stroke)
  if FHasStroke and (FStrokeWidth &gt; 0) then
  begin
    LPaint.Style := TSkPaintStyle.Stroke;
    LPaint.Color := FStrokeColor;
    LPaint.StrokeWidth := FStrokeWidth;
    ACanvas.DrawRoundRect(LRRect, LPaint);
  end;

  // 3. 递归绘制子元素 (Children)
  inherited Draw(ACanvas);
end;
</code></pre>
<hr>
<h3>二、 TPath / SVG 矢量图形支持</h3>
<p>你提到的“TPath 机制”，在实际开发中分为两种需求：</p>
<ol>
<li><strong>SVG Path 路径数据</strong>（一串类似 <code>M10 10 L20 20 Z</code> 的字符串，常用于单色小图标，如购物车、爱心、箭头）。</li>
<li><strong>完整 SVG 文件</strong>（标准的 <code>.svg</code> 矢量文件，包含多颜色、渐变）。</li>
</ol>
<p><strong>Skia 对这两者的支持比 FMX 原生强太多了</strong>，原生 FMX 的 <code>TPath</code> 只能单色且解析慢，而 Skia 原生具备工业级 SVG 引擎。</p>
<h4>1. 开发者以后的调用方式：</h4>
<p><strong>方式 A：直接使用 SVG Path 字符串（做 App 小图标首选）</strong></p>
<pre><code>HStack.Spacing(6).Children([
  // 直接传入矢量 Path 字符串，设置大小和颜色！
  SvgPath(&#39;M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.08-.14.12-.31.12-.48 0-.55-.45-1-1-1H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z&#39;)
    .Size(18, 18)
    .Color($FFE6432E), // 购物车图标变红色

  Text(&#39;加入购物车&#39;).FontSize(12).Color($FFE6432E)
])
</code></pre>
<p><strong>方式 B：直接渲染完整 <code>.svg</code> 文件/资源</strong></p>
<pre><code>SvgImage(&#39;assets/vip_badge.svg&#39;).Size(24, 16)
</code></pre>
<h4>2. 底层在 Skia 中是如何实现的？</h4>
<p><strong>对于 SVG Path（一串字符串）：</strong>
使用 Skia 的 <code>TSkPath.MakeFromSVGString</code>，极其高效，而且支持显存自动缓存：</p>
<pre><code>procedure TSvgPathNode.Draw(const ACanvas: ISkCanvas);
var
  LPath: ISkPath;
  LPaint: ISkPaint;
  LMatrix: TMatrix;
begin
  // 1. 将字符串瞬间转为 GPU 矢量路径
  LPath := TSkPath.MakeFromSVGString(FSvgData);
  if LPath = nil then Exit;

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LPaint.Color := FColor;
  LPaint.Style := TSkPaintStyle.Fill;

  // 2. 缩放到当前控件布局指定的 Rect 范围
  ACanvas.Save;
  try
    // 根据当前节点的坐标和设置的 Width/Height 建立缩放平移矩阵
    ACanvas.Translate(FLayoutBounds.Left, FLayoutBounds.Top);
    ACanvas.Scale(FLayoutBounds.Width / LPath.Bounds.Width, 
                  FLayoutBounds.Height / LPath.Bounds.Height);
    
    // 3. 一笔画入显卡
    ACanvas.DrawPath(LPath, LPaint);
  finally
    ACanvas.Restore;
  end;
end;
</code></pre>
<p><strong>对于完整 SVG 图标（.svg）：</strong>
Skia 提供了原生的 <code>ISkSVGDOM</code>：</p>
<pre><code>var
  LSvg: ISkSVGDOM;
begin
  LSvg := TSkSVGDOM.MakeFromFile(&#39;my_icon.svg&#39;);
  LSvg.SetContainerSize(TSkSize.Create(FLayoutBounds.Width, FLayoutBounds.Height));
  
  ACanvas.Save;
  try
    ACanvas.Translate(FLayoutBounds.Left, FLayoutBounds.Top);
    LSvg.Render(ACanvas); // 无论多复杂的彩色 SVG，直接完美自绘
  finally
    ACanvas.Restore;
  end;
end;
</code></pre>
<hr>
<h3>三、 总结：这套体系带给你的终极威力</h3>
<p>如果你按照这个路线封装下去，你在 Delphi 里的开发模式将会发生质变：</p>
<ol>
<li><strong>告别体积庞大的位图 PNG</strong>：
按钮上的“购物车”、“放大镜搜索”、“返回箭头”、“星级”、“标签”，你都不需要切一堆 @2x, @3x 的 PNG 图了，直接从网上复制一段几十个字符的 SVG Path 字符串丢进代码里，任意放大缩小，永不失真，App 体积减少几十兆。</li>
<li><strong>完全替代 TRectangle</strong>：
无需在 FMX 窗体上挂载繁重的 <code>TRectangle</code> 控件，通过 <code>Box.Fill().Stroke().CornerRadius()</code> 纯靠 GPU 绘制背景，不仅有圆角描边，还能支持单边边框（如只画底边横线）、渐变背景（LinearGradient）。</li>
<li><strong>极佳的阅读性</strong>：
一个带描边背景、左边是矢量 SVG 图标、右边是文字的按钮，在声明式语法下只需要 5 行代码就能一气呵成：
<pre><code>Box.Stroke($FFE6432E, 1).CornerRadius(4).Padding(6).Children([
  HStack.Spacing(4).Children([
    SvgPath(SVG_CART_DATA).Size(14, 14).Color($FFE6432E),
    Text(&#39;抢购&#39;).FontSize(12).Color($FFE6432E)
  ])
])
</code></pre>
这种架构让你既保留了 C++/Rust/Flutter 级别的底层极致渲染性能，又拥有了现代声明式语言的开发敏捷度。</li>
</ol>
<hr>
<p>这个链式调用的设计是不是以后想加什么都可以，比如再加圆(circle)，以后想到新样式就可以很方便的追加</p>
<p><strong>对！完全正确！你已经抓住了这个架构最核心、最迷人的精髓——“无限横向扩展（Open-Closed Principle 开闭原则）”。</strong></p>
<p>传统手绘代码为什么痛苦？因为它是**“死代码”<strong>，写完一个卡片，下一个卡片要重新手算。
而声明式链式调用的底层是</strong>“多态节点树（Polymorphic Node Tree）”**。列表引擎根本不在乎你画的是什么，它只认识一个抽象协议：</p>
<blockquote>
<p>“管你是个矩形、圆形、文本还是外星飞船，你只要告诉我你多大（<code>Measure</code>），你的坐标是多少（<code>Layout</code>），然后把东西画在我的画布上（<code>Draw</code>）。”</p>
</blockquote>
<p>这就意味着：<strong>以后你想加任何新样式、新形状、新特效，只需写一个独立的几行代码的子类，完全不会污染、破坏任何现有的老代码！</strong></p>
<hr>
<h3>一、 比如你想加一个“圆形（Circle）”，有多简单？</h3>
<h4>1. 你只需要花 5 分钟写一个极简的实现：</h4>
<pre><code>type
  TCircleNode = class(TInterfacedObject, IUiElement)
  private
    FRadius: Single;
    FFillColor: TAlphaColor;
    FStrokeColor: TAlphaColor;
    FStrokeWidth: Single;
  public
    constructor Create(ARadius: Single);
    function Fill(AColor: TAlphaColor): TCircleNode;
    function Stroke(AColor: TAlphaColor; AWidth: Single): TCircleNode;
    
    // 实现接口：测量
    function Measure(MaxWidth, MaxHeight: Single): TSizeF;
    procedure Layout(const ARect: TRectF);
    // 实现接口：用 Skia 一笔画出圆形
    procedure Draw(const ACanvas: ISkCanvas);
  end;

function TCircleNode.Fill(AColor: TAlphaColor): TCircleNode;
begin
  FFillColor := AColor;
  Result := Self; // 保证链式调用
end;

procedure TCircleNode.Draw(const ACanvas: ISkCanvas);
var
  LPaint: ISkPaint;
begin
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  
  // 1. 画实心圆
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := FFillColor;
  ACanvas.DrawCircle(FLayoutBounds.CenterPoint, FRadius, LPaint);
  
  // 2. 画边框
  if FStrokeWidth &gt; 0 then
  begin
    LPaint.Style := TSkPaintStyle.Stroke;
    LPaint.Color := FStrokeColor;
    LPaint.StrokeWidth := FStrokeWidth;
    ACanvas.DrawCircle(FLayoutBounds.CenterPoint, FRadius, LPaint);
  end;
end;
</code></pre>
<h4>2. 全局暴露一个构造函数：</h4>
<pre><code>function Circle(Radius: Single): TCircleNode;
begin
  Result := TCircleNode.Create(Radius);
end;
</code></pre>
<h4>3. 以后你在任何列表、任何页面，立刻就能链式调用：</h4>
<pre><code>HStack.Spacing(8).Children([
  // 画一个绿色的在线状态圆点
  Circle(4).Fill($FF2ECC71), 

  // 画一个带白色描边的红色红点未读角标
  Circle(8).Fill($FFE6432E).Stroke(TAlphaColors.White, 1.5),

  Text(&#39;消息通知&#39;)
])
</code></pre>
<hr>
<h3>二、 两个维度的“无限扩展”空间</h3>
<p>随着你 App 业务的深入，你会发现你可以向这套系统里像拼乐高一样源源不断地加入<strong>两类扩展</strong>：</p>
<h4>维度 1：追加全新的【视觉组件（Nodes）】</h4>
<p>| 想加的新组件             | 怎么链式调用                         | Skia 底层实现方式                                  |
| :----------------------- | :----------------------------------- | :------------------------------------------------- |
| <strong>分割线 (Divider)</strong>     | <code>Divider.Height(1).Color($FFE0E0E0)</code> | <code>ACanvas.DrawLine</code>                                 |
| <strong>虚线 (DashLine)</strong>      | <code>DashLine.DashLength(4).Color(Gray)</code> | 给 <code>TSkPaint</code> 加 <code>PathEffect.MakeDash</code>             |
| <strong>动态二维码 (QRCode)</strong>  | <code>QRCode(&#39;https://...&#39;).Size(60, 60)</code> | 用算法生成矩阵后，<code>DrawRect</code> 一笔画出              |
| <strong>Lottie 矢量动画</strong>      | <code>Lottie(&#39;star.json&#39;).Size(20, 20)</code>   | Skia 自带原生的 <code>ISkAnimation</code>，直接播放 Json 动画 |
| <strong>星级评分 (RatingBar)</strong> | <code>RatingBar(4.5).StarSize(12)</code>        | 循环画几个 Unicode <code>★</code> 或 SVG 星星                 |</p>
<h4>维度 2：追加全局通用的【修饰器属性（Modifiers）】</h4>
<p>你甚至可以给<strong>任何组件</strong>（不管是文字、图片还是圆形）追加修饰器，比如加阴影、透明度、旋转、毛玻璃：</p>
<pre><code>// 任意组件都可以链式追加效果：
AsyncImage(&#39;url&#39;)
  .Size(50, 50)
  .Opacity(0.8)                     // 80% 透明度
  .Blur(5)                          // 高斯模糊 / 毛玻璃效果
  .Shadow(OffsetY=4, Blur=8, Color) // 投影
  .Rotation(45)                     // 旋转 45 度
</code></pre>
<p>底层只要在基类节点的 <code>Draw</code> 前后调用 <code>ACanvas.Save</code>、<code>ACanvas.Rotate</code>、<code>ACanvas.Restore</code> 即可。</p>
<hr>
<h3>三、 总结：高级开发的“架构复利”</h3>
<ul>
<li><strong>传统的做法（负资产）</strong>：
做一个新界面，复制粘贴几百行坐标算术代码；修一个 Bug，改了这里坏了那里。时间越长，技术债务越重。</li>
<li><strong>现在的架构（资产复利）</strong>：
<ul>
<li><strong>第一周</strong>：你写完了基础框架，支持了 <code>HStack</code>、<code>VStack</code>、<code>Text</code>、<code>Box</code>。</li>
<li><strong>第二周</strong>：你遇到新需求，随手追加了 <code>Circle</code>、<code>SvgPath</code>、<code>Badge</code>。</li>
<li><strong>第三周</strong>：你追加了 <code>Divider</code>、<code>RatingBar</code>、<code>渐变色</code>。</li>
<li><strong>半年后</strong>：你的这套框架里已经积累了三四十个强大、极其轻量、跨平台的 Skia 视觉原子。</li>
</ul>
</li>
</ul>
<p>到了那个时候，不论老板或客户拿出多么奇葩、多么复杂的 App 列表样式设计图，你或者你团队的新人，<strong>只需要在 <code>BuildLayout</code> 里用你沉淀下来的组件像拼积木一样组合出来，10 分钟搞定一个页面，而且滑起来像丝绸一样流畅（120 帧）</strong>。</p>
<p>这就是从“搬砖写界面”，升级为“自研跨平台微型 UI 引擎”带来的降维打击。</p>
<hr>
<p>gemini_Argon回复:</p>
<p>我已经完整审阅了压缩包中的所有源码（<code>Project1.dpr</code>、<code>SkCardListView.pas</code>、<code>Unit1.pas</code>、<code>Unit1.fmx</code>）以及内置的 <code>gemini.md</code> 架构演进文档。</p>
<p>作为长期深耕 Delphi FireMonkey 与底层图形渲染的开发者，下面我将先针对现有代码进行<strong>深度诊断</strong>，然后为你设计一套真正兼具<strong>工业级性能、高扩展性、零 GC 抖动</strong>的灵活列表组件架构，并给出分阶段可落地的实施计划。</p>
<h3>一、 现有源码 (<code>SkCardListView.pas</code>) 深度诊断与隐患分析</h3>
<p>目前的 <code>TSkCardListView</code> 验证了“基于 <code>TSkPaintBox</code> + <code>TAniCalculations</code> + 视口虚拟化裁剪 + 双级异步缓存”的高性能路线，但在走向通用化和生产环境前，存在以下几个必须解决的硬伤：</p>
<ol>
<li><strong>严重的“幽灵点击”（HitTest 脏数据 Bug）</strong>
<ul>
<li><strong>定位</strong>：在 <code>Draw</code> 方法中，仅对 <code>StartRow</code> 到 <code>EndRow</code> 之间的可视项更新了 <code>Item.LastCardRect := CardRect</code>。但在 <code>MouseUp</code> 中，却遍历了 <code>0</code> 到 <code>FItems.Count - 1</code> 的所有项去判断 <code>Item.LastCardRect.Contains(ClickPoint)</code>。</li>
<li><strong>后果</strong>：当列表滚动后，滚出屏幕的旧 Item 依然保留着上次在屏幕内时的坐标 <code>LastCardRect</code>。用户点击当前屏幕某处时，如果序号靠前的不可见 Item 曾经也在这个坐标，就会误触到不可见的旧 Item！</li>
</ul>
</li>
<li><strong>高频渲染下的对象分配（GC/内存抖动）</strong>
<ul>
<li><strong>定位</strong>：在 <code>DrawSingleProductCard</code>、<code>DrawDoubleMerchantCard</code>、<code>DrawStarRating</code> 中，每次 <code>Draw</code>（60~120Hz）都会对每个可见卡片反复执行 <code>TSkPaint.Create</code> 和 <code>TSkFont.Create</code>。</li>
<li><strong>后果</strong>：虽然 Skia4Delphi 使用接口引用计数（ARC）自动释放，但每秒数千次的堆内存分配与析构会造成严重的 CPU 损耗，在 Android 低端机上容易引发掉帧。</li>
</ul>
</li>
<li><strong>布局计算与业务逻辑强耦合</strong>
<ul>
<li><strong>定位</strong>：<code>GetTotalContentHeight</code> 和 <code>Draw</code> 里硬编码了 <code>vmSingleProduct</code>（固定高 <code>142</code>）和 <code>vmDoubleMerchant</code>（双列计算公式 <code>ColWidth * 0.75 + 92</code>）。<code>TCardItem</code> 的字段（保质期、路名、原价、评分）也是写死的。</li>
<li><strong>后果</strong>：一旦增加第三种卡片样式，或者同一列表里出现“顶部 Banner + 分类金刚区 + 商品流”的混排（Heterogeneous List），现有类就必须推倒重改。</li>
</ul>
</li>
<li><strong>文本截断算法效率低下</strong>
<ul>
<li><strong>定位</strong>：<code>DrawEllipsisText</code> 使用 <code>while</code> 循环逐字符缩减并调用 <code>AFont.MeasureText</code>。</li>
<li><strong>后果</strong>：如果遇到一段 200 字的长文本，每一帧重绘都要测量上百次。而且 <code>DrawSimpleText</code> 不支持多行自动换行与富文本。</li>
</ul>
</li>
<li><strong>图片异步回调的生命周期隐患</strong>
<ul>
<li><strong>定位</strong>：<code>TSkImageCache.GetImage</code> 中的 <code>TTask.Run</code> 在下载完成后通过 <code>TThread.Queue</code> 回调 <code>Redraw</code>。</li>
<li><strong>后果</strong>：如果图片还在下载中，用户关闭了窗体或销毁了 <code>TSkCardListView</code>，匿名函数捕获的 <code>Self</code> 指针已经悬空，<code>TThread.Queue</code> 执行时会直接触发 <code>Access Violation</code>。</li>
</ul>
</li>
<li><strong><code>gemini.md</code> 中“纯声明式 DSL”方案的落地陷阱</strong>
<ul>
<li>文档后半部分提出了类似 Flutter 的 <code>HStack.Children([...])</code> 方案。但在 Delphi 中需要警惕：<strong>绝对不能在 <code>Draw</code> 渲染循环里每一帧去 <code>BuildLayout</code> 构建对象树</strong>，否则接口对象的频繁创建销毁会把 Skia 带来的性能优势消耗殆尽。若引入轻量节点树，必须做**布局树缓存（Dirty 标记更新）*<em>或采用*<em>无状态的 Flyweight（享元）绘制器</em></em>。</li>
</ul>
</li>
</ol>
<h3>二、 目标架构设计：四层解耦的可扩展虚拟列表 (<code>TSkVirtualListView</code>)</h3>
<p>为了兼顾<strong>极致性能</strong>与<strong>灵活扩展</strong>，建议将列表拆分为以下四个正交的层次：</p>
<p>Plaintext</p>
<pre><code>+-----------------------------------------------------------------------+
| 1. 容器与引擎层 (TSkVirtualListView : TSkPaintBox)                     |
|    - 惯性滚动 (TAniCalculations) / 手势竞技场 (Gesture Arena)          |
|    - 视口裁剪与二分查找虚拟化 (支持不等高、多列瀑布流/网格、吸顶)       |
|    - 共享画笔资源池 (TSkRenderContext: 复用 Paint/Font/Paragraph)     |
+-----------------------------------------------------------------------+
                                   | 调用接口 (ISkItemAdapter)
                                   v
+-----------------------------------------------------------------------+
| 2. 适配器与渲染策略层 (TSkCustomAdapter / ISkCardRenderer&lt;T&gt;)          |
|    - 负责回答：总共有多少项？第 Index 项是什么类型？多宽多高？怎么画？  |
|    - 支持多模板注册 (BannerRenderer, ProductRenderer, MerchantRenderer)|
+-----------------------------------------------------------------------+
                                   | 使用原语绘制 / 布局计算
                                   v
+-----------------------------------------------------------------------+
| 3. 轻量级绘制原语与微布局层 (Skia UI Primitives &amp; Micro-Layout)        |
|    - 零分配矩形切分器 (TRectSlicer: DockLeft/DockTop/SplitColumns)    |
|    - 或：缓存式声明节点树 (TUiNode: Measure -&gt; LayoutCache -&gt; Draw)    |
|    - 内置原语：圆角框(带阴影/边框)、多行富文本(Paragraph)、SVG、轮播图  |
+-----------------------------------------------------------------------+
                                   | 绑定业务数据
                                   v
+-----------------------------------------------------------------------+
| 4. 数据模型与异步资源层 (Data Item &amp; TSkResourcePool)                  |
|    - 泛型数据项或接口，彻底剥离 LastCardRect 等 UI 状态                |
|    - 安全图片缓存 (带 CancelToken / WeakRef 防止销毁崩溃 + 并发限流)   |
+-----------------------------------------------------------------------+
</code></pre>
<h4>核心架构亮点说明：</h4>
<ol>
<li>
<p><strong>UI 坐标状态与业务数据彻底分离（解决 HitTest 与耦合问题）</strong></p>
<ul>
<li>
<p>业务层的 <code>TProductItem</code> 或 <code>TMerchantItem</code> 只存纯数据，不再包含 <code>LastCardRect</code>、<code>LastActionBtnRect</code>。</p>
</li>
<li>
<p>引擎内部维护一个轻量级的 <code>TArray&lt;TVirtualLayoutSlot&gt;</code>（结构体数组，连续内存，极速访问）：</p>
<p>Delphi</p>
<pre><code>type
  THitZone = record
    ZoneID: Integer; // 例如: 1=加购按钮, 2=收藏按钮, 3=轮播图区
    Rect: TRectF;    // 相对于卡片左上角的局部坐标
  end;

  TVirtualLayoutSlot = record
    Index: Integer;
    ItemType: Integer;
    Bounds: TRectF;  // 在整个虚拟画布中的绝对坐标 (Content Space)
    HitZones: TArray&lt;THitZone&gt;; // 由 Renderer 在 Measure/Layout 阶段注册的热区
  end;
</code></pre>
</li>
<li>
<p><strong>优势</strong>：</p>
<ol>
<li>列表滚动时，<code>Bounds</code> 不需要重新计算（它只存文档流绝对坐标，绘制时减去 <code>ScrollY</code> 即可），彻底杜绝不可见项的“幽灵点击”。</li>
<li>支持任意数量的卡片内子按钮点击（加购、领券、进店、点赞），只需比对 <code>ZoneID</code>，无需为每个按钮在组件上加事件属性。</li>
<li>支持<strong>不等高列表</strong>与<strong>多列混排</strong>（例如第 0 项占满整行高度 180，第 1~10 项双列显示高度 240），通过二分查找（<code>BinarySearch</code>）在 $O(\log N)$ 时间内定位可视区首尾行。</li>
</ol>
</li>
</ul>
</li>
<li>
<p><strong>共享渲染上下文 <code>TSkRenderContext</code>（解决 GC 抖动问题）</strong></p>
<ul>
<li>组件初始化时创建唯一的 <code>TSkRenderContext</code>，预先实例化常用的 <code>FillPaint</code>、<code>StrokePaint</code>、<code>ShadowPaint</code>、<code>RegularFont</code>、<code>BoldFont</code> 以及 <code>ISkParagraphBuilder</code>。</li>
<li>传递给 <code>Renderer.DrawCard(ACanvas, AContext, AItem, ARect)</code>，整个绘制过程<strong>零对象分配</strong>。</li>
</ul>
</li>
<li>
<p><strong>提供两种卡片编写范式（兼顾效率与易用性）</strong></p>
<ul>
<li>
<p><strong>范式 A：零分配矩形切分器 <code>TRectSlicer</code>（推荐用于极致性能场景）</strong> 不用手写容易出错的 <code>ARect.Left + 8 + 96 + 10</code>，通过值类型 Record 方法链式切分矩形：</p>
<p>Delphi</p>
<pre><code>var ContentRect := ARect.Deflate(8, 8);
var ImgRect := ContentRect.CutLeft(96); // 切出左侧 96px 给图片，ContentRect 自动缩减
ContentRect.CutLeft(10);                // 切出 10px 间距
var BottomBar := ContentRect.CutBottom(28); // 切出底部价格栏
var BtnRect := BottomBar.CutRight(68);  // 底部右侧切出 68px 给按钮
</code></pre>
<p><em>没有任何堆内存分配，代码直观，改尺寸时后续元素自动平移。</em></p>
</li>
<li>
<p><strong>范式 B：缓存式声明节点树 <code>IUiNode</code>（即 <code>gemini.md</code> 中的 HStack/VStack 方案改良版）</strong> 支持 <code>HStack</code>、<code>VStack</code>、<code>Box</code>、<code>SkText</code>、<code>SvgPath</code>、<code>Circle</code> 等链式组装，但<strong>仅在数据变更或宽度变化（<code>UpdateLayout</code>）时构建并计算一次坐标</strong>，将结果烘焙（Bake）为平坦的绘制指令列表存入 <code>TVirtualLayoutSlot</code> 中，<code>Draw</code> 阶段只负责极速回放。</p>
</li>
</ul>
</li>
</ol>
<h3>三、 详细可落地的分阶段实施计划</h3>
<p>我们将重构与扩展计划分为 <strong>4 个阶段（Phases）</strong>，每个阶段均可独立编译、测试并看到直观效果。</p>
<h4>第一阶段：底层加固与核心引擎抽离（预计 1~1.5 天）</h4>
<p><strong>目标</strong>：修复现有 Bug，消除渲染内存分配，将硬编码的列表改造为通用的虚拟容器 <code>TSkVirtualListView</code>。</p>
<ol>
<li><strong>重构图片缓存 <code>TSkImageCache</code> (<code>SkImageCache.pas</code>)</strong>
<ul>
<li>引入 <code>TThreadPool</code> 限制最大并发下载数（如 4~6 个线程），避免首次加载 100 张图瞬间创建大量 HTTP 线程。</li>
<li>增加组件订阅机制或传入 <code>TWeakRef</code> / 取消令牌，解决组件销毁后异步线程回调 <code>Redraw</code> 引发的 AV 崩溃。</li>
<li>增加图片解码尺寸优化（降采样），防止大图直接原尺寸上屏撑爆内存。</li>
</ul>
</li>
<li><strong>构建共享渲染上下文 <code>TSkRenderContext</code> (<code>SkVirtualList.Core.pas</code>)</strong>
<ul>
<li>封装跨平台字体加载逻辑（复用原有的 <code>InitTypefaces</code>）。</li>
<li>提供 <code>GetFillPaint(AColor)</code>、<code>GetStrokePaint(AColor, AWidth)</code>、<code>GetFont(ASize, ABold)</code> 等内联复用方法，彻底干掉 <code>Draw</code> 里的 <code>TSkPaint.Create</code>。</li>
<li>封装基于 <code>TSkParagraph</code> 或二分测量法的快速文本绘制方法，支持单行省略号、多行截断及中英文混排精确基线对齐，替换原有的 <code>while</code> 循环 <code>DrawEllipsisText</code>。</li>
</ul>
</li>
<li><strong>实现虚拟布局表与精准命中测试 (<code>TVirtualLayoutManager</code>)</strong>
<ul>
<li>定义 <code>TVirtualLayoutSlot</code> 记录每个 Item 的文档流坐标 <code>Bounds: TRectF</code> 和子热区 <code>HitZones</code>。</li>
<li>修正 <code>MouseUp</code> 点击逻辑：将屏幕点击坐标 <code>(X, Y)</code> 转换为文档流坐标 <code>(X, Y + ScrollY)</code>，仅在当前可视范围 <code>[FVisibleStartIndex..FVisibleEndIndex]</code> 内进行碰撞检测，彻底修复“幽灵点击” Bug。</li>
<li>优化 <code>MouseWheel</code> 与 <code>TAniCalculations</code> 的阻尼配合，加入按下状态（<code>PressedIndex</code> / <code>PressedZoneID</code>）的视觉反馈支持（如点击卡片变暗或轻微缩放）。</li>
</ul>
</li>
</ol>
<h4>第二阶段：渲染器策略接口与矩形切分工具（预计 1 天）</h4>
<p><strong>目标</strong>：实现数据与视图解耦，支持同一列表中混排多种不同样式、不同列数的卡片。</p>
<ol>
<li>
<p><strong>定义渲染器契约接口 (<code>ISkCardRenderer</code>)</strong></p>
<p>Delphi</p>
<pre><code>type
  ISkCardRenderer = interface
    [&#39;{8B4F2A10-5C3E-4D9A-9F1B-2E6D8C7A0E31}&#39;]
    // 返回该类型卡片占用的列数 (例如 1=通栏单列, 2=双列网格)
    function GetSpanCount: Integer;
    // 测量卡片高度，同时可在此注册固定子热区
    function MeasureHeight(AContext: TSkRenderContext; AItem: TObject; AWidth: Single): Single;
    // 执行绘制，并可动态更新子热区 (HitZones)
    procedure DrawCard(const ACanvas: ISkCanvas; AContext: TSkRenderContext;
      AItem: TObject; const ARect: TRectF; var AHitZones: TArray&lt;THitZone&gt;;
      AIsPressed: Boolean; APressedZoneID: Integer);
  end;
</code></pre>
</li>
<li>
<p><strong>开发 <code>TRectSlicer</code> 布局辅助工具与常用绘制原语</strong></p>
<ul>
<li>实现 <code>TRectSlicer</code> Record Helper（支持 <code>CutLeft</code>, <code>CutRight</code>, <code>CutTop</code>, <code>CutBottom</code>, <code>Pad</code>, <code>SplitGrid</code>）。</li>
<li>封装高频 UI 原语绘制函数（均挂载在 <code>TSkRenderContext</code> 上）：
<ul>
<li><code>DrawCardBox</code>：支持背景填充、边框 Stroke、四角独立圆角、外阴影（DropShadow）。</li>
<li><code>DrawBadge</code>：自适应文字宽度的胶囊标签/圆角标签（带背景色或描边）。</li>
<li><code>DrawPriceText</code>：自动将 <code>¥ 1678.90</code> 拆分为小号符号 <code>¥</code>、大号整数 <code>1678</code>、小号小数 <code>.90</code> 及带删除线的原价。</li>
<li><code>DrawSvgIcon</code>：基于 <code>TSkPath.MakeFromSVGString</code> 并缓存编译后的 <code>ISkPath</code>，无需重复解析 SVG 字符串，直接矩阵缩放绘制（替代原有的 Unicode 字符图标 <code>📍</code>、<code>⏱</code>、<code>★</code>，彻底消除不同手机系统 Emoji 渲染不一致的问题）。</li>
</ul>
</li>
</ul>
</li>
<li>
<p><strong>迁移现有两种卡片为独立 Renderer (<code>SkCardRenderers.Biz.pas</code>)</strong></p>
<ul>
<li>编写 <code>TSingleProductRenderer</code> 和 <code>TDoubleMerchantRenderer</code>。</li>
<li>验证单列切換双列、乃至<strong>单双列同屏混排</strong>（如上方 2 个单列爆款商品 + 下方双列店铺流）的流畅度。</li>
</ul>
</li>
</ol>
<h4>第三阶段：声明式微布局引擎（Flexbox DSL）落地（预计 1.5~2 天）</h4>
<p><strong>目标</strong>：将 <code>gemini.md</code> 中构想的 <code>HStack</code> / <code>VStack</code> / <code>Box</code> / <code>Circle</code> / <code>SvgPath</code> 声明式语法真正写成可编译、高性能的 Delphi 单元 (<code>SkUiDsl.pas</code>)。</p>
<ol>
<li><strong>设计轻量级节点基类与接口 (<code>IUiNode</code> / <code>TUiNode</code>)</strong>
<ul>
<li>实现核心三部曲：<code>Measure(MaxW, MaxH): TSizeF</code> $\rightarrow$ <code>Layout(ARect: TRectF)</code> $\rightarrow$ <code>Draw(ACanvas, AContext)</code>。</li>
<li>为节点增加 <code>.OnClick(ZoneID)</code> 修饰符：当节点执行完 <code>Layout(ARect)</code> 后，若带有 <code>ZoneID</code>，自动将该节点的 <code>FLayoutBounds</code> 收集到当前 Slot 的 <code>HitZones</code> 数组中。<strong>这意味着写声明式布局时，顺手加一句 <code>.OnClick(BTN_BUY)</code> 就自动完成了按钮热区绑定！</strong></li>
</ul>
</li>
<li><strong>实现核心容器节点</strong>
<ul>
<li><code>THStack</code> / <code>TVStack</code>：支持 <code>.Spacing(N)</code>、<code>.Padding(L,T,R,B)</code>、<code>.AlignItems(Center/Start/End)</code>、<code>.JustifyContent(Start/Between/End)</code>，以及子元素的 <code>.Flex(Weight)</code> 弹性剩余空间分配。</li>
<li><code>TBoxNode</code>：对应增强版 <code>TRectangle</code>，支持 <code>.Fill()</code>、<code>.Stroke()</code>、<code>.Radius()</code>、<code>.Shadow()</code>。</li>
</ul>
</li>
<li><strong>实现核心叶子节点</strong>
<ul>
<li><code>TTextNode</code> (<code>SkText</code>)：支持 <code>.Bold</code>、<code>.Size()</code>、<code>.Color()</code>、<code>.MaxLines()</code>、<code>.Strikethrough</code>（删除线）。</li>
<li><code>TImageNode</code> (<code>SkAsyncImage</code>)：支持 <code>.Size()</code>、<code>.Radius()</code>、<code>.OverlayTag()</code>。</li>
<li><code>TSvgNode</code> (<code>SkSvg</code>) &amp; <code>TCircleNode</code> (<code>SkCircle</code>) &amp; <code>TDividerNode</code> (<code>SkDivider</code>)。</li>
</ul>
</li>
<li><strong>实现布局树缓存机制（关键性能保障）</strong>
<ul>
<li>在 <code>TDeclarativeCardRenderer&lt;T&gt;</code> 基类中，每个可见或已测量的 Slot 缓存其生成的 <code>IUiNode</code> 根节点。</li>
<li>仅当 <code>Item</code> 数据发生改变或列表宽度改变（<code>Resize</code>）时才重新调用 <code>BuildLayout(Item)</code> 并执行 <code>Measure &amp; Layout</code>；在 120FPS 滚动过程中，直接复用已计算好的节点树执行偏移绘制（<code>ACanvas.Translate(Slot.Left, Slot.Top - ScrollY)</code> 后直接 <code>RootNode.Draw</code>）。</li>
</ul>
</li>
</ol>
<h4>第四阶段：高级交互特性扩展（预计 1~1.5 天）</h4>
<p><strong>目标</strong>：补齐现代移动 App 列表的核心交互体验。</p>
<ol>
<li><strong>手势竞技场（Gesture Arena）与卡片内横向轮播 (<code>TCarouselNode</code>)</strong>
<ul>
<li>落地 <code>gemini.md</code> 中的 45 度角手势方向锁定状态机（<code>tmDeciding</code> $\rightarrow$ <code>tmVerticalScroll</code> / <code>tmHorizontalSwipe</code>）。</li>
<li>引入简单的弹簧/线性插值过渡动画（在 <code>MouseUp</code> 松手进行 Page Snapping 时，不再生硬瞬间跳变 <code>ImageScrollOffset := 0</code>，而是通过微型步进动画平滑归位到下一张图）。</li>
</ul>
</li>
<li><strong>生产级列表刚需功能</strong>
<ul>
<li><strong>下拉刷新（Pull-to-Refresh）与上拉加载更多（Infinite Scroll）</strong>：当 <code>ScrollY</code> 接近 <code>TotalContentHeight - Height</code> 时自动触发 <code>OnLoadMore</code> 事件。</li>
<li><strong>分组吸顶（Sticky Header）</strong>：支持某种类型的 Slot 标记为 <code>IsStickyHeader</code>，滚动到顶部时自动悬停绘制在最上层。</li>
<li><strong>空状态与骨架屏（Empty State &amp; Skeleton）</strong>：当 <code>Items.Count = 0</code> 或正在加载时，直接使用 Skia 绘制闪烁占位骨架卡片。</li>
</ul>
</li>
</ol>
<h3>四、 代码级落地预览：重构后的文件结构与调用示范</h3>
<p>完成上述计划后，你的工程结构将非常清晰：</p>
<p>Plaintext</p>
<pre><code>Project1/
 ├── SkImageCache.pas          // 线程安全、带并发控制与生命周期保护的二级缓存
 ├── SkVirtualList.Core.pas    // TSkRenderContext, TRectSlicer, TSkVirtualListView 核心引擎
 ├── SkUiDsl.pas               // HStack, VStack, Box, SkText, SkSvg, SkCircle 声明式引擎
 ├── SkCardRenderers.Biz.pas   // 业务卡片渲染器 (单列商品、双列商户、轮播图卡片等)
 └── Unit1.pas                 // 干净的业务窗体调用
</code></pre>
<p><strong>重构后在业务层扩展一种新卡片的代码体验：</strong></p>
<p>Delphi</p>
<pre><code>// 业务层只需关注数据与BuildLayout，坐标计算、热区检测、内存复用全部由底层接管
function TProductCardRenderer.BuildLayout(const AItem: TProductItem): IUiNode;
begin
  Result := Box.Fill(TAlphaColors.White).Radius(8).Padding(8).Children([
    HStack.Spacing(10).Children([
      // 左侧：支持多图滑动的圆角图片区 + 左上角标签
      Carousel(AItem.Images).Size(96, 108).Radius(6).Badge(AItem.TagTop, $EBE6432E),

      // 右侧：自适应占满剩余宽度的纵向布局
      VStack.Flex(1).Spacing(4).Children([
        // 第一行：描边标签 + 粗体标题
        HStack.Spacing(4).AlignCenter.Children([
          Badge(&#39;超值优惠&#39;).Stroke($FFF3B8AE, 1).TextColor($FFE6432E),
          SkText(AItem.Title).Bold.Size(13.5).Color($FF1A1A1A).Flex(1)
        ]),
        // 第二行：副标题
        SkText(AItem.Subtitle).Size(10.5).Color($FF6A6A6E),
        // 第三行：SVG图标 + 保质期与距离
        HStack.Spacing(6).AlignCenter.Children([
          SkSvg(SVG_CLOCK).Size(12, 12).Color($FFE6432E),
          SkText(AItem.ShelfLife).Size(10.5).Color($FFE6432E),
          SkSvg(SVG_PIN).Size(12, 12).Color($FFE6432E),
          SkText(AItem.Road).Size(10.5).Color($FFE6432E)
        ]),
        // 第四行：地址
        SkText(AItem.Address).Size(10.5).Color($FF9A9A9E),
        // 弹簧占位，将价格栏推到底部
        Spacer.Flex(1),
        // 底部：左侧价格 + 右侧抢购按钮 (绑定热区 ID = ZONE_ACTION_BUY)
        HStack.Between.AlignEnd.Children([
          PriceTag(AItem.Price, AItem.OriginalPrice),
          Box.Fill($FFE6432E).Radius(5).Padding(10, 5)
             .OnClick(ZONE_ACTION_BUY) // &lt;-- 自动注册点击热区！
             .Children([
               SkText(&#39;立即抢购&#39;).Bold.Size(10.5).Color(TAlphaColors.White)
             ])
        ])
      ])
    ])
  ]);
end;
</code></pre>
<h3>下一步推进建议</h3>
<p>这份计划既保留了你现有代码中 <code>TSkPaintBox</code> + <code>TSkImageCache</code> 的高帧率基因，又彻底解决了硬编码坐标、内存抖动与点击错位问题。</p>
<p>我们可以立即开始动手写代码。你希望我：</p>
<ol>
<li><strong>按阶段推进</strong>：先直接为你写出<strong>第一阶段 + 第二阶段</strong>的完整可编译单元代码（修复所有现有 Bug、提取 <code>TSkRenderContext</code>、实现多 Renderer 架构与 <code>TRectSlicer</code>），直接替换现有的 <code>SkCardListView.pas</code> 跑起来？</li>
<li><strong>一步到位</strong>：直接包含第三阶段的 <code>SkUiDsl.pas</code>（<code>HStack</code>/<code>VStack</code>/<code>Box</code>/<code>SkSvg</code> 声明式引擎）一起写出完整代码？</li>
</ol>
<hr>
