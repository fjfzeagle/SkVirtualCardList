unit SkCardRenderers.Biz;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Generics.Collections, System.Skia, SkVirtualList.Core, SkUiDsl;

const
  // 通用 SVG 矢量图标路径常量（消除跨平台 Emoji 渲染不一致）
  SVG_CART = 'M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.08-.14.12-.31.12-.48 0-.55-.45-1-1-1H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z';
  SVG_CLOCK = 'M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z';
  SVG_PIN = 'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z';
  SVG_STAR = 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z';

type
  // 纯业务商品数据实体（完全剥离 UI 坐标，保证无状态）
  TProductItem = class
  public
    ID: string;
    Title: string;
    Subtitle: string;
    Road: string;
    ShelfLife: string;
    Address: string;
    TagTop: string;       // 左上角角标（如：官方补贴、热卖、新鲜直达）
    BottomTag: string;    // 底部全宽保障横条（如：假一赔十、破损包赔、冷链配送）
    ShopTag: string;      // 标题后特色标签（如：小店好货）
    PriceTag: string;     // 现价后价格标签（如：补贴价、新客价）
    ImageUrl: string;     // 主图 URL
    Images: TArray<string>; // 多张商品轮播图
    ActiveImageIndex: Integer; // 当前展示第几张 (0, 1, 2...)
    ImageScrollOffset: Single; // 横向拖拽位移 (0 为居中)
    AutoCruise: Boolean;  // 该商品轮播图是否开启智能巡航 (默认 False)
    MultiLineAddress: Boolean; // 地址超长时是否允许折行自适应高 (默认 False)
    Price: Currency;
    OriginalPrice: Currency;
    constructor Create;
  end;

  // 纯业务商家数据实体
  TMerchantItem = class
  public
    ID: string;
    Title: string;
    Road: string;
    Address: string;
    SalesVolume: string;
    Rating: Single;
    ImageUrl: string;
  end;

  // 单列商品卡片渲染器 (基于 SkUiDsl 声明式流式排版)
  TSingleProductCardRenderer = class(TDeclarativeCardRenderer)
  private
    FMultiLineAddress: Boolean;
  public
    constructor Create;
    function GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject = nil): Single; override;
    function BuildLayout(AItem: TObject): IUiNode; override;
    function CanSwipeImage(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean; override;
    function CanAutoCruise(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean; override;
    procedure OnImageSwipe(AItem: TObject; const ADeltaX: Single); override;
    procedure OnImageSwipeEnd(AItem: TObject; const ADeltaX, AImgWidth: Single); override;
    function ResolveSwipeTarget(AItem: TObject; const ADeltaX, AImgWidth: Single;
      out ATargetOffset: Single; out AIndexDelta: Integer): Boolean; override;
    procedure OnImageSwipeFinished(AItem: TObject; const AIndexDelta: Integer); override;

    property MultiLineAddress: Boolean read FMultiLineAddress write FMultiLineAddress;
  end;

  // 双列商家网格卡片渲染器
  TDoubleMerchantCardRenderer = class(TDeclarativeCardRenderer)
  public
    constructor Create;
    function GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject = nil): Single; override;
    function BuildLayout(AItem: TObject): IUiNode; override;
  end;

implementation

{ TProductItem }

constructor TProductItem.Create;
begin
  inherited Create;
  AutoCruise := False; // 默认静止不开启，只有显式配置 AutoCruise := True 的商品才参与巡航
  MultiLineAddress := False; // 默认单行截断，开启后多行折行并自适应撑高
end;

{ TSingleProductCardRenderer }

constructor TSingleProductCardRenderer.Create;
begin
  inherited Create(1, 142); // 1 列通栏，基准高度 142
  FMultiLineAddress := False;
end;

function TSingleProductCardRenderer.GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject): Single;
var
  P: TProductItem;
  LayoutCache: TCachedLayout;
  Desired: TSizeF;
begin
  Result := 142; // 基准高度
  if (AItem <> nil) and (AItem is TProductItem) then
  begin
    P := TProductItem(AItem);
    if (P.MultiLineAddress or FMultiLineAddress) and (not P.Address.IsEmpty) and (AContext <> nil) then
    begin
      // 1. 获取或创建该 Item 的 DSL 布局树 (基于当前可用列宽)
      if not FCache.TryGetValue(AItem, LayoutCache) or (LayoutCache.Node = nil) or
         (Abs(LayoutCache.Width - AColWidth) > 0.5) then
      begin
        LayoutCache.Node := BuildLayout(AItem);
        LayoutCache.Width := AColWidth;
        LayoutCache.Height := 0; // 重置高度，确保 DrawCard 会在实际 Slot 高度下执行 Layout
        FCache.AddOrSetValue(AItem, LayoutCache);
      end;

      if LayoutCache.Node <> nil then
      begin
        // 2. 利用当前平台(Windows/Android)真实字体指标进行 100% 精确度量
        Desired := LayoutCache.Node.Measure(AContext, AColWidth, 10000);

        // 3. 加上 8px 安全呼吸间距，确保在任何 DPI 缩放下都不会贴死或溢出底边
        Result := Max(142, Desired.cy + 8);
      end;
    end;
  end;
end;

function TSingleProductCardRenderer.CanSwipeImage(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean;
var
  P: TProductItem;
begin
  AWidth := 96; // 封面图宽度
  Result := False;
  if (AItem is TProductItem) and (AZoneID = ZONE_IMAGE_CAROUSEL) then
  begin
    P := TProductItem(AItem);
    Result := Length(P.Images) > 1;
  end;
end;

function TSingleProductCardRenderer.CanAutoCruise(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean;
var
  P: TProductItem;
begin
  Result := False;
  if CanSwipeImage(AItem, AZoneID, AWidth) then
  begin
    P := TProductItem(AItem);
    Result := P.AutoCruise;
  end;
end;

procedure TSingleProductCardRenderer.OnImageSwipe(AItem: TObject; const ADeltaX: Single);
var
  P: TProductItem;
begin
  if AItem is TProductItem then
  begin
    P := TProductItem(AItem);
    P.ImageScrollOffset := ADeltaX;
    inherited OnImageSwipe(AItem, ADeltaX);
  end;
end;

procedure TSingleProductCardRenderer.OnImageSwipeEnd(AItem: TObject; const ADeltaX, AImgWidth: Single);
var
  P: TProductItem;
  EffectiveW: Single;
begin
  if AItem is TProductItem then
  begin
    P := TProductItem(AItem);
    EffectiveW := Max(10, AImgWidth);

    // 滑动幅度超过 20% 时切换图片
    if ADeltaX < -EffectiveW * 0.2 then
    begin
      // 向左滑：下一张
      if P.ActiveImageIndex < High(P.Images) then
        Inc(P.ActiveImageIndex);
    end
    else if ADeltaX > EffectiveW * 0.2 then
    begin
      // 向右滑：上一张
      if P.ActiveImageIndex > 0 then
        Dec(P.ActiveImageIndex);
    end;

    P.ImageScrollOffset := 0;
    inherited OnImageSwipeEnd(AItem, ADeltaX, AImgWidth);
  end;
end;

function TSingleProductCardRenderer.ResolveSwipeTarget(AItem: TObject; const ADeltaX, AImgWidth: Single;
  out ATargetOffset: Single; out AIndexDelta: Integer): Boolean;
var
  P: TProductItem;
  EffectiveW: Single;
begin
  Result := False;
  ATargetOffset := 0;
  AIndexDelta := 0;
  if not (AItem is TProductItem) then Exit;
  P := TProductItem(AItem);
  EffectiveW := Max(10, AImgWidth);

  // 滑动幅度超过 20% 时判定为成功切换图片（支持无限循环轮播）；否则目标为回弹归零
  if (ADeltaX < -EffectiveW * 0.2) and (Length(P.Images) > 1) then
  begin
    ATargetOffset := -EffectiveW;
    if P.ActiveImageIndex < High(P.Images) then
      AIndexDelta := +1
    else
      AIndexDelta := -P.ActiveImageIndex; // 循环切回第 1 张 (索引 0)
    Result := True;
  end
  else if (ADeltaX > EffectiveW * 0.2) and (Length(P.Images) > 1) then
  begin
    ATargetOffset := EffectiveW;
    if P.ActiveImageIndex > 0 then
      AIndexDelta := -1
    else
      AIndexDelta := High(P.Images); // 循环切至最后一张
    Result := True;
  end
  else
  begin
    ATargetOffset := 0;
    AIndexDelta := 0;
    Result := True;
  end;
end;

procedure TSingleProductCardRenderer.OnImageSwipeFinished(AItem: TObject; const AIndexDelta: Integer);
var
  P: TProductItem;
begin
  if AItem is TProductItem then
  begin
    P := TProductItem(AItem);
    if (AIndexDelta <> 0) and (Length(P.Images) > 0) then
    begin
      P.ActiveImageIndex := P.ActiveImageIndex + AIndexDelta;
      if P.ActiveImageIndex > High(P.Images) then
        P.ActiveImageIndex := 0
      else if P.ActiveImageIndex < 0 then
        P.ActiveImageIndex := High(P.Images);
    end;
    P.ImageScrollOffset := 0;
    inherited OnImageSwipeFinished(AItem, AIndexDelta);
  end;
end;

function TSingleProductCardRenderer.BuildLayout(AItem: TObject): IUiNode;
var
  P: TProductItem;
  PriceStr, OldPriceStr: string;
  TitleRowChildren: TArray<IUiNode>;
  PriceRowChildren: TArray<IUiNode>;
  RoadRowChildren: TArray<IUiNode>;
  ImageNode: IUiNode;
begin
  P := TProductItem(AItem);
  PriceStr := Format('¥%.1f', [P.Price]);
  OldPriceStr := Format('¥%.1f', [P.OriginalPrice]);

  // 1. 构建标题行：标题文本 + [小店好货] 橙色边框标签
  if not P.ShopTag.IsEmpty then
    TitleRowChildren := [
      SkText(P.Title).Bold.Size(13.5).Color($FF1A1A1A),
      Box.Stroke($FFF87D56, 0.8).Fill($0DF87D56).Radius(2).Padding(4, 1.5).Child(
        SkText(P.ShopTag).Size(9.5).Color($FFE65B32)
      )
    ]
  else
    TitleRowChildren := [SkText(P.Title).Bold.Size(13.5).Color($FF1A1A1A)];

  // 2. 构建价格行：现价 + [补贴价/新客价] 标签 + 划线原价
  if not P.PriceTag.IsEmpty then
    PriceRowChildren := [
      SkText(PriceStr).Bold.Size(15).Color($FFE6432E),
      Box.Fill($1AE6432E).Radius(2).Padding(4, 1.5).Child(
        SkText(P.PriceTag).Size(9.5).Color($FFE6432E)
      ),
      SkText(OldPriceStr).Size(10).Color($FF999999).Strikethrough(True)
    ]
  else
    PriceRowChildren := [
      SkText(PriceStr).Bold.Size(15).Color($FFE6432E),
      SkText(OldPriceStr).Size(10).Color($FF999999).Strikethrough(True)
    ];

  // 3. 构建第三行：首位放置有效期（时钟图标左对齐），次位放置路段（图钉图标排在右侧）
  RoadRowChildren := [];
  if not P.ShelfLife.IsEmpty then
  begin
    SetLength(RoadRowChildren, Length(RoadRowChildren) + 1);
    RoadRowChildren[High(RoadRowChildren)] := HStack.Spacing(3).AlignCenter.Children([
      SkSvg(SVG_CLOCK).Size(11, 11).Color($FFE6432E),
      SkText(P.ShelfLife).Size(10).Color($FFE6432E)
    ]);
  end;

  if not P.Road.IsEmpty then
  begin
    SetLength(RoadRowChildren, Length(RoadRowChildren) + 1);
    RoadRowChildren[High(RoadRowChildren)] := HStack.Spacing(3).AlignCenter.Children([
      SkSvg(SVG_PIN).Size(11, 11).Color($FFE6432E),
      SkText(P.Road).Size(10).Color($FFE6432E)
    ]);
  end;

  // 4. 构建左侧封面图（支持多图横向手势画廊 + 分页圆点 + 角标 + 保障横条）
  if Length(P.Images) > 0 then
    ImageNode := Carousel(P.Images, Self)
      .Size(96, 114).Radius(6)
      .AutoCruise(P.AutoCruise)
      .ActiveIndex(P.ActiveImageIndex)
      .ScrollOffset(P.ImageScrollOffset)
      .Badge(P.TagTop)
      .BottomBar(P.BottomTag)
      .OnClick(ZONE_IMAGE_CAROUSEL)
  else
    ImageNode := AsyncImage(P.ImageUrl, Self)
      .Size(96, 114).Radius(6)
      .Badge(P.TagTop)
      .BottomBar(P.BottomTag)
      .OnClick(ZONE_IMAGE_CAROUSEL);

  Result := Box.Fill(TAlphaColors.White).Radius(8).Shadow(True).Padding(8).Child(
    HStack.Flex(1).Spacing(10).AlignStart.Children([
      ImageNode,

      // 右侧内容区（占满剩余宽度，纵向层次清晰）
      VStack.Flex(1).Spacing(4).Children([
        // 第1行：标题 + 小店好货标签
        HStack.Spacing(6).AlignCenter.Children(TitleRowChildren),

        // 第2行：起止日期副标题
        SkText(P.Subtitle).Size(10).Color($FF6A6A6E),

        // 第3行：路段（图钉图标首位左对齐）+ 保质期限（可选置右）
        HStack.Spacing(10).AlignCenter.Children(RoadRowChildren),

        // 第4行：详细地址 (支持属性控制多行折行自适应或单行截断)
        SkText(P.Address).Size(10).Color($FF9A9A9E).Wrap(P.MultiLineAddress or FMultiLineAddress),

        // 弹性弹簧占位符，将价格栏推至卡片最底部
        Spacer.Flex(1),

        // 第5行：底部价格栏与“加入购物车”按钮
        HStack.Between.AlignCenter.Children([
          // 现价 + 补贴价 + 原价
          HStack.Spacing(5).AlignCenter.Children(PriceRowChildren),

          // 加入购物车按钮（带有 ZONE_ACTION_BUY 子热区绑定）
          Box.Fill($FFE6432E).Radius(4).Padding(8, 4.5)
             .OnClick(ZONE_ACTION_BUY)
             .Child(
               SkText('加入购物车').Bold.Size(10.5).Color(TAlphaColors.White)
             )
        ])
      ])
    ])
  );
end;

{ TDoubleMerchantCardRenderer }

constructor TDoubleMerchantCardRenderer.Create;
begin
  inherited Create(2, 202); // 2 列双列网格，高度 202
end;

function TDoubleMerchantCardRenderer.GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject = nil): Single;
begin
  // 默认高度 202；若评分 >= 4.7（金牌好店），额外展示金黄色服务保障条，高度拓展为 226
  if (AItem is TMerchantItem) and (TMerchantItem(AItem).Rating >= 4.7) then
    Result := 226
  else
    Result := 202;
end;

function TDoubleMerchantCardRenderer.BuildLayout(AItem: TObject): IUiNode;
var
  M: TMerchantItem;
  ScoreStr: string;
  VNodes: TArray<IUiNode>;
  Idx: Integer;
begin
  M := TMerchantItem(AItem);
  ScoreStr := Format('%.1f', [M.Rating]);

  if M.Rating >= 4.7 then
    SetLength(VNodes, 5)
  else
    SetLength(VNodes, 4);

  Idx := 0;
  // 1. 标题
  VNodes[Idx] := SkText(M.Title).Bold.Size(12).Color($FF1A1A1A);
  Inc(Idx);

  // 金牌标签
  if M.Rating >= 4.7 then
  begin
    VNodes[Idx] := Box.Fill($12FFB020).Radius(3).Padding(4, 2).Child(
      HStack.Spacing(3).AlignCenter.Children([
        SkSvg(SVG_STAR).Size(9, 9).Color($FFD48806),
        SkText('金牌老店 · 平台甄选极速达').Size(8.5).Color($FFD48806)
      ])
    );
    Inc(Idx);
  end;

  // 2. 路段
  VNodes[Idx] := SkText('路段：' + M.Road).Size(9.5).Color($FFE6432E);
  Inc(Idx);

  // 3. 详细地址
  VNodes[Idx] := SkText('地址：' + M.Address).Size(9.5).Color($FF999999).MaxLines(1);
  Inc(Idx);

  // 4. 底部月售与五角星评分（两端对齐）
  VNodes[Idx] := HStack.Between.AlignCenter.Children([
    SkText(M.SalesVolume).Size(9.5).Color($FF999999),
    HStack.Spacing(2).AlignCenter.Children([
      SkSvg(SVG_STAR).Size(11, 11).Color($FFE6432E),
      SkText(ScoreStr).Bold.Size(10.5).Color($FFE6432E)
    ])
  ]);

  Result := Box.Fill(TAlphaColors.White).Radius(8).Shadow(True).Children([
    VStack.Spacing(0).Children([
      // 1. 顶部封面图：横向撑满卡片宽度，顶部两角设为 8 圆角贴合卡片，高度 115
      AsyncImage(M.ImageUrl).Height(115).RadiusTop(8).FillWidth(True),

      // 2. 底部店铺图文信息区：设置舒适的独立内边距
      VStack.Padding(8, 6, 8, 8).Spacing(4).Children(VNodes)
    ])
  ]);
end;

end.
