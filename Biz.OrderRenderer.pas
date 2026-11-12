unit Biz.OrderRenderer;



interface



uses

  System.SysUtils, System.Types, System.UITypes, System.Classes,

  System.Generics.Collections, System.Math, System.Skia,

  SkVirtualList.Core, SkUiDsl, Biz.OrderModel;



const

  ZONE_BTN_CANCEL     = 101; // 取消订单

  ZONE_BTN_LOGISTICS  = 102; // 查看物流

  ZONE_BTN_PAY        = 103; // 立即支付

  ZONE_ORDER_IMAGE_BASE = 2000; // 加上明细索引，定位失败图片重试



type

  TOrderCardRenderer = class(TDeclarativeCardRenderer)

  public

    constructor Create;

    function GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject = nil): Single; override;

    function BuildLayout(AItem: TObject): IUiNode; override;

  end;



implementation



{ TOrderCardRenderer }



constructor TOrderCardRenderer.Create;

begin

  // 单列通栏展示，默认初始预估高度 200px（由 GetItemHeight.Measure 精确重算并自动缓存）

  inherited Create(1, 200);

end;



function TOrderCardRenderer.GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject = nil): Single;

var

  Order: TOrder;

  LayoutCache: TCachedLayout;

  Desired: TSizeF;

begin

  Result := FItemHeight;

  if (AItem <> nil) and (AItem is TOrder) then

  begin

    Order := TOrder(AItem);

    // 获取或创建 DSL 布局树

    if not FCache.TryGetValue(AItem, LayoutCache) or (LayoutCache.Node = nil) or

       (Abs(LayoutCache.Width - AColWidth) > 0.5) then

    begin

      LayoutCache.Node := BuildLayout(AItem);

      LayoutCache.Width := AColWidth;

      LayoutCache.Height := 0;

      FCache.AddOrSetValue(AItem, LayoutCache);

    end;



    if (LayoutCache.Node <> nil) and (AContext <> nil) then

    begin

      Desired := LayoutCache.Node.Measure(AContext, AColWidth, 10000);

      Result := Max(140, Desired.cy);

    end

    else

    begin

      // 兜底公式：组头(约34) + 每个商品(约68) + 组尾汇总与按钮(约44) + 容器上下Padding(24)

      Result := 34 + (Order.Details.Count * 68) + 44 + 24;

    end;

  end;

end;



function TOrderCardRenderer.BuildLayout(AItem: TObject): IUiNode;

var

  Order: TOrder;

  CardNodes: TList<IUiNode>;

  Detail: TOrderItemDetail;

  I: Integer;

begin

  Order := TOrder(AItem);

  CardNodes := TList<IUiNode>.Create;

  try

    // ---------------------------------------------------------

    // 1. 组头：单号、下单时间与订单状态

    // ---------------------------------------------------------

    CardNodes.Add(

      HStack.Between.AlignCenter.Padding(0, 0, 0, 10)

        .Children([

          HStack.Spacing(6).AlignCenter

            .Children([

              SkText('单号: ' + Order.OrderId).Size(FONT_SIZE_BODY).Color($FF6A6A6E),

              SkText(Order.OrderDate).Size(FONT_SIZE_SUB).Color($FF9A9A9E)

            ]),

          SkText(Order.StatusText).Bold.Size(FONT_SIZE_TITLE).Color($FFE6432E)

        ])

    );



    // ---------------------------------------------------------

    // 2. 中部：循环动态生成商品明细行（支持 1~N 个商品）

    // ---------------------------------------------------------

    for I := 0 to Order.Details.Count - 1 do

    begin

      Detail := Order.Details[I];

      CardNodes.Add(

        HStack.Spacing(10).Padding(0, 6).AlignCenter

          .Children([

            AsyncImage(Detail.ImageUrl).Size(56, 56).Radius(6).OnClick(ZONE_ORDER_IMAGE_BASE + I),

            VStack.Spacing(4).Flex(1)

              .Children([

                SkText(Detail.ProductName).Bold.Size(FONT_SIZE_TITLE).MaxLines(1),

                SkText(Detail.SpecName).Size(FONT_SIZE_SUB).Color($FF8A8A8E)

              ]),

            VStack.Spacing(2).AlignEnd

              .Children([

                SkText('¥' + FormatFloat('0.00', Detail.Price)).Bold.Size(FONT_SIZE_TITLE).Color($FF1A1A1A),

                SkText('x' + Detail.Quantity.ToString).Size(FONT_SIZE_SUB).Color($FF8A8A8E)

              ])

          ])

      );

    end;



    // ---------------------------------------------------------

    // 3. 组尾：合计汇总信息与业务动作按钮（绑定子热区 ID）

    // ---------------------------------------------------------

    CardNodes.Add(

      HStack.Between.AlignCenter.Padding(0, 10, 0, 0)

        .Children([

          SkText(Format('共 %d 件  实付 ¥%.2f', [Order.TotalQty, Order.TotalAmount])).Bold.Size(FONT_SIZE_BODY).Color($FF1A1A1A),

          HStack.Spacing(8).AlignCenter

            .Children([

              SkBadge('查看物流').FontSize(FONT_SIZE_SUB).Padding(10, 5).Radius(12)

                .Fill($FFF5F5F7).TextColor($FF4A4A4E)

                .OnClick(ZONE_BTN_LOGISTICS),

              SkBadge('去支付').FontSize(FONT_SIZE_SUB).Padding(12, 5).Radius(12)

                .Fill($FFE6432E).TextColor($FFFFFFFF)

                .OnClick(ZONE_BTN_PAY)

            ])

        ])

    );



    // ---------------------------------------------------------

    // 4. 外层容器：统一构建白底、圆角与阴影卡片

    // ---------------------------------------------------------

    Result := Box

      .Fill($FFFFFFFF)

      .Radius(10)

      .Shadow(True)

      .Padding(12, 12, 12, 12)

      .Child(

        VStack.Children(CardNodes.ToArray)

      );

  finally

    CardNodes.Free;

  end;

end;



end.