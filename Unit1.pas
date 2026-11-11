unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Generics.Collections, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.StdCtrls, FMX.DialogService,
  SkVirtualList.Core, SkCardRenderers.Biz, FMX.Controls.Presentation,
  FMX.Objects,
  Biz.OrderModel, Biz.OrderRenderer, SkAsync, SkImageCache;

type
  TViewMode = (vmProduct, vmMerchant, vmMixed, vmOrder);

  TForm1 = class(TForm)
    LayoutTopBar: TLayout;
    BtnSingleProduct: TButton;
    BtnDoubleMerchant: TButton;
    LayoutContainer: TLayout;
    HorzScrollBox1: THorzScrollBox;
    procedure FormCreate(Sender: TObject);
    procedure BtnSingleProductClick(Sender: TObject);
    procedure BtnDoubleMerchantClick(Sender: TObject);
  private
    FListView: TSkVirtualListView;
    FRendererProduct: ISkCardRenderer;
    FRendererMerchant: ISkCardRenderer;
    FRendererOrder: ISkCardRenderer;
    FCurrentMode: TViewMode;
    BtnToggleCruise: TButton;
    BtnSimulateError: TButton;
    BtnTestPartial: TButton;
    BtnTestBadImage: TButton;
    FSimulateError: Boolean;

    procedure LoadProductData;
    procedure LoadMerchantData;
    procedure LoadMixedData;
    procedure LoadOrderData;
    procedure BtnMixedClick(Sender: TObject);
    procedure BtnOrderClick(Sender: TObject);
    procedure HandleItemClick(Sender: TObject; AIndex: Integer; AItem: TObject; AZoneID: Integer);
    procedure HandlePageFetch(Sender: TObject; const APage: Integer; const AIsRefresh: Boolean);
    procedure HandleEmptyClick(Sender: TObject);
    procedure HandleToggleCruiseClick(Sender: TObject);
    procedure HandleToggleErrorClick(Sender: TObject);
    procedure HandlePartialUpdateClick(Sender: TObject);
    procedure HandleBadImageClick(Sender: TObject);
  public
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited MouseWheel(Shift, WheelDelta, Handled);
  if not Handled and (FListView <> nil) then
    FListView.MouseWheel(Shift, WheelDelta, Handled);
end;

// 从 merchant.html 提取的 8 张真实商品图片
const
  ProductImages: array[0..7] of string = (
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Feitian%20Moutai%20baijiu%20white%20porcelain%20bottle%20with%20red%20cap%20and%20red%20ribbon%20next%20to%20gold%20gift%20box%2C%20premium%20product%20photography%2C%20studio%20lighting%2C%20light%20grey%20background&image_size=square',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=glass%20jar%20of%20Chinese%20spicy%20pork%20sauce%20babao%20jiang%20with%20red%20chili%20oil%20topping%2C%20appetizing%20product%20photography%2C%20light%20background&image_size=square',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=tofu%20skin%20roll%20stuffed%20with%20shepherd''s%20purse%20and%20bamboo%20shoots%20on%20white%20plate%2C%20fresh%20food%20photography%2C%20light%20background&image_size=square',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Budweiser%20beer%20red%20aluminum%20cans%20in%20six%20pack%20with%20condensation%20drops%2C%20product%20photography%2C%20light%20background&image_size=square',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Wuchang%20daohuaxiang%20premium%20rice%205kg%20vacuum%20bag%20with%20rice%20grains%20and%20wooden%20scoop%2C%20product%20photography%2C%20light%20background&image_size=square',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Yunnan%20sweet%20oranges%20fresh%20with%20green%20leaves%20in%20wicker%20basket%2C%20one%20cut%20in%20half%20showing%20juicy%20flesh%2C%20fruit%20photography%2C%20light%20background&image_size=square',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Arowana%20brand%20golden%20corn%20oil%20bottle%205L%20with%20corn%20kernels%20beside%2C%20product%20photography%2C%20light%20background&image_size=square',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=Mengniu%20pure%20milk%20cartons%20blue%20and%20white%20packaging%20with%20glass%20of%20milk%20and%20milk%20splash%2C%20product%20photography%2C%20light%20background&image_size=square'
  );

// 从 merchant-list.html 提取的 6 张真实商家封面图片
const
  MerchantImages: array[0..5] of string = (
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=bright%20fruit%20store%20front%20with%20colorful%20fresh%20fruits%20displayed%20in%20crates%2C%20apples%20oranges%20watermelons%2C%20street%20photography%2C%20daylight&image_size=landscape_4_3',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=modern%20supermarket%20entrance%20with%20glass%20doors%20and%20shopping%20carts%2C%20bright%20signage%2C%20street%20view%2C%20daylight&image_size=landscape_4_3',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=cozy%20Chinese%20noodle%20shop%20storefront%20with%20red%20lanterns%20and%20steaming%20bowls%20visible%20inside%2C%20warm%20lighting%2C%20street%20photography&image_size=landscape_4_3',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=clean%20modern%20pharmacy%20storefront%20with%20green%20cross%20sign%20and%20glass%20windows%2C%20medicine%20shelves%20visible%2C%20daylight&image_size=landscape_4_3',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=cute%20pet%20store%20front%20with%20paw%20print%20sign%20and%20pet%20supplies%20in%20window%20display%2C%20a%20cat%20in%20the%20window%2C%20daylight&image_size=landscape_4_3',
    'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=traditional%20Chinese%20grain%20and%20oil%20shop%20with%20rice%20sacks%20and%20oil%20bottles%20at%20the%20entrance%2C%20street%20photography%2C%20daylight&image_size=landscape_4_3'
  );

  BaseTitles: array[0..7] of string = (
    '飞天茅台酒53度500ml',
    '八宝酱辣肉酱200g',
    '腐皮笋丁荠菜卷400g',
    '百威啤酒330ml×6听',
    '五常稻花香大米5kg',
    '云南冰糖橙5斤装',
    '金龙鱼玉米胚芽油5L',
    '蒙牛纯牛奶250ml×12盒'
  );
  Tags: array[0..3] of string = ('官方补贴', '热卖', '新鲜直达', '新人专享');
  BottomTags: array[0..3] of string = ('假一赔十', '破损包赔', '冷链配送', '假一赔四');
  PriceTags: array[0..2] of string = ('补贴价', '新客价', '专享价');
  Prices: array[0..7] of Currency = (1678.9, 27.9, 41.9, 69.9, 89.9, 29.9, 69.9, 55.9);
  OldPrices: array[0..7] of Currency = (1099.0, 35.0, 49.0, 89.0, 129.0, 39.9, 89.0, 69.0);

procedure TForm1.FormCreate(Sender: TObject);
var
  BtnEmptyState, BtnMixed: TButton;
  BtnOrder: TButton;
begin
  Caption := 'Skia 虚拟化解耦列表 (声明式 DSL / 多图轮播 / 下拉刷新 / 骨架屏 / 单双列同屏混排)';

  // 配置顶部水平滚动导航条：隐藏滚动条保持精致，支持触控横向滑动
  HorzScrollBox1.ShowScrollBars := False;

  // 1. 模式切换按钮组
  BtnSingleProduct.Parent := HorzScrollBox1;
  BtnSingleProduct.Align := TAlignLayout.Left;
  BtnSingleProduct.Width := 46;
  BtnSingleProduct.Margins.Left := 6;
  BtnSingleProduct.Margins.Top := 8;
  BtnSingleProduct.Margins.Bottom := 8;
  BtnSingleProduct.Margins.Right := 2;
  BtnSingleProduct.Text := '单列';

  BtnDoubleMerchant.Parent := HorzScrollBox1;
  BtnDoubleMerchant.Align := TAlignLayout.Left;
  BtnDoubleMerchant.Width := 46;
  BtnDoubleMerchant.Margins.Left := 4;
  BtnDoubleMerchant.Margins.Top := 8;
  BtnDoubleMerchant.Margins.Bottom := 8;
  BtnDoubleMerchant.Margins.Right := 2;
  BtnDoubleMerchant.Text := '双列';

  // 动态创建“同屏混排”模式切换按钮
  BtnMixed := TButton.Create(Self);
  BtnMixed.Parent := HorzScrollBox1;
  BtnMixed.Align := TAlignLayout.Left;
  BtnMixed.Width := 46;
  BtnMixed.Margins.Left := 4;
  BtnMixed.Margins.Top := 8;
  BtnMixed.Margins.Bottom := 8;
  BtnMixed.Margins.Right := 2;
  BtnMixed.Text := '混排';
  BtnMixed.OnClick := BtnMixedClick;

  // 动态创建“订单分组”模式切换按钮 (方案 A 复合单据卡片)
  BtnOrder := TButton.Create(Self);
  BtnOrder.Parent := HorzScrollBox1;
  BtnOrder.Align := TAlignLayout.Left;
  BtnOrder.Width := 46;
  BtnOrder.Margins.Left := 4;
  BtnOrder.Margins.Top := 8;
  BtnOrder.Margins.Bottom := 8;
  BtnOrder.Margins.Right := 2;
  BtnOrder.Text := '订单';
  BtnOrder.OnClick := BtnOrderClick;

  // 2. 功能测试按钮组（顺排在 HorzScrollBox1 内，横向自由滑动）
  BtnEmptyState := TButton.Create(Self);
  BtnEmptyState.Parent := HorzScrollBox1;
  BtnEmptyState.Align := TAlignLayout.Left;
  BtnEmptyState.Width := 58;
  BtnEmptyState.Margins.Left := 4;
  BtnEmptyState.Margins.Top := 8;
  BtnEmptyState.Margins.Bottom := 8;
  BtnEmptyState.Margins.Right := 2;
  BtnEmptyState.Text := '空状态';
  BtnEmptyState.OnClick := HandleEmptyClick;

  // 动态创建并挂载“自动巡航控制开关”按钮
  BtnToggleCruise := TButton.Create(Self);
  BtnToggleCruise.Parent := HorzScrollBox1;
  BtnToggleCruise.Align := TAlignLayout.Left;
  BtnToggleCruise.Width := 68;
  BtnToggleCruise.Margins.Left := 4;
  BtnToggleCruise.Margins.Top := 8;
  BtnToggleCruise.Margins.Bottom := 8;
  BtnToggleCruise.Margins.Right := 2;
  BtnToggleCruise.Text := '巡航:开';
  BtnToggleCruise.OnClick := HandleToggleCruiseClick;

  // 动态创建并挂载“模拟接口异常”测试按钮
  FSimulateError := False;
  BtnSimulateError := TButton.Create(Self);
  BtnSimulateError.Parent := HorzScrollBox1;
  BtnSimulateError.Align := TAlignLayout.Left;
  BtnSimulateError.Width := 60;
  BtnSimulateError.Margins.Left := 4;
  BtnSimulateError.Margins.Top := 8;
  BtnSimulateError.Margins.Bottom := 8;
  BtnSimulateError.Margins.Right := 2;
  BtnSimulateError.Text := '故障:关';
  BtnSimulateError.OnClick := HandleToggleErrorClick;

  // 动态创建并挂载“局部刷新”测试按钮（等高 O(1) 原地刷新）
  BtnTestPartial := TButton.Create(Self);
  BtnTestPartial.Parent := HorzScrollBox1;
  BtnTestPartial.Align := TAlignLayout.Left;
  BtnTestPartial.Width := 68;
  BtnTestPartial.Margins.Left := 4;
  BtnTestPartial.Margins.Top := 8;
  BtnTestPartial.Margins.Bottom := 8;
  BtnTestPartial.Margins.Right := 2;
  BtnTestPartial.Text := '局部改价';
  BtnTestPartial.OnClick := HandlePartialUpdateClick;

  // 动态创建并挂载“坏图兜底”测试按钮（离线脉冲与失败回退测试）
  BtnTestBadImage := TButton.Create(Self);
  BtnTestBadImage.Parent := HorzScrollBox1;
  BtnTestBadImage.Align := TAlignLayout.Left;
  BtnTestBadImage.Width := 68;
  BtnTestBadImage.Margins.Left := 4;
  BtnTestBadImage.Margins.Top := 8;
  BtnTestBadImage.Margins.Bottom := 8;
  BtnTestBadImage.Margins.Right := 8;
  BtnTestBadImage.Text := '坏图测试';
  BtnTestBadImage.OnClick := HandleBadImageClick;

  // 1. 初始化各业务卡片渲染器
  FRendererProduct := TSingleProductCardRenderer.Create;
  FRendererMerchant := TDoubleMerchantCardRenderer.Create;
  FRendererOrder := TOrderCardRenderer.Create;

  // 2. 创建并挂载通用虚拟列表引擎
  FListView := TSkVirtualListView.Create(Self);
  FListView.Parent := LayoutContainer;
  FListView.Align := TAlignLayout.Client;
  FListView.ItemSpacing := 8;

  // 3. 注册多类型数据实体与专属渲染器映射关系 (实现单双列同屏混排与单据分组)
  FListView.RegisterRenderer(TProductItem, FRendererProduct);
  FListView.RegisterRenderer(TMerchantItem, FRendererMerchant);
  FListView.RegisterRenderer(TOrder, FRendererOrder);

  LayoutTopBar.BringToFront;
  LayoutContainer.ClipChildren := True;

  // 4. 绑定统一精准点击事件与现代分页控制器回调 (OnPageFetch 统一接管下拉刷新归位与上拉分页递增)
  FListView.OnItemClick := HandleItemClick;
  FListView.OnPageFetch := HandlePageFetch;

  Randomize;

  // 默认启动进入“同屏混排”模式，先展示 600ms 骨架屏，再异步呈现混排数据流
  FCurrentMode := vmMixed;
  FListView.IsLoading := True;
  FListView.UpdateLayout;

  TThread.CreateAnonymousThread(procedure
  begin
    Sleep(600);
    TThread.Synchronize(nil, procedure
    begin
      LoadMixedData;
    end);
  end).Start;
end;

procedure TForm1.BtnSingleProductClick(Sender: TObject);
begin
  FCurrentMode := vmProduct;
  FListView.Clear;
  FListView.Renderer := FRendererProduct;
  FListView.IsLoading := True;
  FListView.UpdateLayout;

  TThread.CreateAnonymousThread(procedure
  begin
    Sleep(350);
    TThread.Synchronize(nil, procedure
    begin
      LoadProductData;
    end);
  end).Start;
end;

procedure TForm1.BtnDoubleMerchantClick(Sender: TObject);
begin
  FCurrentMode := vmMerchant;
  FListView.Clear;
  FListView.Renderer := FRendererMerchant;
  FListView.IsLoading := True;
  FListView.UpdateLayout;

  TThread.CreateAnonymousThread(procedure
  begin
    Sleep(350);
    TThread.Synchronize(nil, procedure
    begin
      LoadMerchantData;
    end);
  end).Start;
end;

procedure TForm1.BtnMixedClick(Sender: TObject);
begin
  FCurrentMode := vmMixed;
  FListView.Clear;
  FListView.IsLoading := True;
  FListView.UpdateLayout;

  TThread.CreateAnonymousThread(procedure
  begin
    Sleep(350);
    TThread.Synchronize(nil, procedure
    begin
      LoadMixedData;
    end);
  end).Start;
end;

procedure TForm1.BtnOrderClick(Sender: TObject);
begin
  FCurrentMode := vmOrder;
  FListView.Clear;
  FListView.Renderer := FRendererOrder;
  FListView.IsLoading := True;
  FListView.UpdateLayout;

  TThread.CreateAnonymousThread(procedure
  begin
    Sleep(300);
    TThread.Synchronize(nil, procedure
    begin
      LoadOrderData;
    end);
  end).Start;
end;

procedure TForm1.LoadOrderData;
var
  Order: TOrder;
begin
  FListView.Clear;
  FListView.Renderer := FRendererOrder;

  // 订单 1：2 件高单价商品
  Order := TOrder.Create('YT202611030001', '2026-11-03 14:20', '待发货');
  Order.AddDetail('飞天茅台酒53度500ml', ProductImages[0], '官方正品 500ml 单瓶装', 1678.9, 1);
  Order.AddDetail('五常稻花香大米5kg', ProductImages[4], '2026新米 真空包装', 89.9, 2);
  FListView.Items.Add(Order);

  // 订单 2：1 件生鲜水果
  Order := TOrder.Create('YT202611030002', '2026-11-03 15:10', '待付款');
  Order.AddDetail('云南冰糖橙5斤装', ProductImages[5], '果园现摘 甜润多汁 单箱装', 29.9, 3);
  FListView.Items.Add(Order);

  // 订单 3：3 件快消食品（展示自适应撑高）
  Order := TOrder.Create('YT202611030003', '2026-11-03 16:45', '配送中');
  Order.AddDetail('八宝酱辣肉酱200g', ProductImages[1], '传统风味 浓郁香辣 200g/罐', 27.9, 2);
  Order.AddDetail('腐皮笋丁荠菜卷400g', ProductImages[2], '速冻保鲜 鲜香爽口 400g/袋', 41.9, 1);
  Order.AddDetail('百威啤酒330ml×6听', ProductImages[3], '清爽纯正 6听组合装', 69.9, 1);
  FListView.Items.Add(Order);

  // 订单 4：1 件粮油
  Order := TOrder.Create('YT202611030004', '2026-11-02 09:30', '已完成');
  Order.AddDetail('金龙鱼玉米胚芽油5L', ProductImages[6], '非转基因 物理压榨 5L大桶装', 69.9, 1);
  FListView.Items.Add(Order);

  // 订单 5：2 件饮品
  Order := TOrder.Create('YT202611030005', '2026-11-01 18:05', '已完成');
  Order.AddDetail('蒙牛纯牛奶250ml×12盒', ProductImages[7], '优质乳蛋白 整箱特惠装', 55.9, 2);
  Order.AddDetail('百威啤酒330ml×6听', ProductImages[3], '清爽纯正 6听组合装', 69.9, 2);
  FListView.Items.Add(Order);

  FListView.IsLoading := False;
  FListView.UpdateLayout;
end;

procedure TForm1.HandleEmptyClick(Sender: TObject);
begin
  FListView.Clear;
  FListView.IsLoading := False;
  FListView.EmptyPrompt := '没有找到符合条件的商品或商家';
  FListView.ScrollToTop;
  FListView.UpdateLayout;
end;

procedure TForm1.HandleToggleCruiseClick(Sender: TObject);
begin
  FListView.EnableAutoCruise := not FListView.EnableAutoCruise;
  if FListView.EnableAutoCruise then
    BtnToggleCruise.Text := '巡航:开'
  else
    BtnToggleCruise.Text := '巡航:关';
end;

procedure TForm1.HandleToggleErrorClick(Sender: TObject);
begin
  FSimulateError := not FSimulateError;
  if FSimulateError then
    BtnSimulateError.Text := '故障:开'
  else
    BtnSimulateError.Text := '故障:关';
end;

procedure TForm1.HandlePartialUpdateClick(Sender: TObject);
var
  TargetItem: TObject;
  Prod: TProductItem;
  Merch: TMerchantItem;
  Order: TOrder;
begin
  if FListView.Items.Count = 0 then Exit;
  // 选取第 1 个单品/卡片进行等高属性变动
  TargetItem := FListView.Items[0];
  if TargetItem is TProductItem then
  begin
    Prod := TProductItem(TargetItem);
    Prod.Price := Max(1.0, Prod.Price - 10.0);
    Prod.Title := '【热销点赞+1】' + BaseTitles[0];
    Prod.TagTop := '降价特惠';
    // O(1) 等高局部刷新：不重排布局，清除该项 DSL 编译树并原地零闪烁重绘
    FListView.NotifyItemChanged(0, False);
  end
  else if TargetItem is TMerchantItem then
  begin
    Merch := TMerchantItem(TargetItem);
    Merch.Title := '【爆款特惠】' + Merch.Title;
    Merch.Rating := Min(5.0, Merch.Rating + 0.1);
    FListView.NotifyItemChanged(0, False);
  end
  else if TargetItem is TOrder then
  begin
    Order := TOrder(TargetItem);
    Order.StatusText := '已付款(局部秒刷)';
    Order.TotalAmount := Max(0.01, Order.TotalAmount - 10.0);
    FListView.NotifyItemChanged(0, False);
  end;
end;

procedure TForm1.HandleBadImageClick(Sender: TObject);
var
  TargetIdx, I: Integer;
  Prod: TProductItem;
begin
  if FListView.Items.Count = 0 then Exit;

  // 优先选取首个带有画廊轮播的商品大卡进行测试
  TargetIdx := -1;
  for I := 0 to FListView.Items.Count - 1 do
  begin
    if FListView.Items[I] is TProductItem then
    begin
      TargetIdx := I;
      Break;
    end;
  end;

  if TargetIdx >= 0 then
  begin
    Prod := TProductItem(FListView.Items[TargetIdx]);
    // 注入 404 失效地址，并将当前轮播图全部设为坏图，重置手势位移
    Prod.ImageUrl := 'https://trae-api-cn.mchost.guru/404_invalid_image.jpg';
    Prod.Images := [
      'https://trae-api-cn.mchost.guru/404_invalid_image.jpg',
      'https://trae-api-cn.mchost.guru/404_invalid_image_2.jpg',
      'https://trae-api-cn.mchost.guru/404_invalid_image_3.jpg'
    ];
    Prod.ActiveImageIndex := 0;
    Prod.ImageScrollOffset := 0;

    // 清理失败冷却表与可能存在的历史坏文件
    TSkImageCache.RetryUrl('https://trae-api-cn.mchost.guru/404_invalid_image.jpg');
    TSkImageCache.RetryUrl('https://trae-api-cn.mchost.guru/404_invalid_image_2.jpg');
    TSkImageCache.RetryUrl('https://trae-api-cn.mchost.guru/404_invalid_image_3.jpg');

    // 触发局部重绘：立即使 DSL 编译缓存失效，展现加载中脉冲动效，并随后回退到失败兜底图
    FListView.NotifyItemChanged(TargetIdx, False);
  end;
end;

procedure TForm1.LoadProductData;
var
  I: Integer;
  Item: TProductItem;
begin
  FListView.Clear;
  FListView.Renderer := FRendererProduct;

  for I := 1 to 20 do
  begin
    Item := TProductItem.Create;
    Item.ID := I.ToString;
    Item.Title := BaseTitles[(I - 1) mod 8];
    Item.ShopTag := '小店好货';
    Item.Subtitle := '起始日期：2026-10-01　终止日期：2026-10-30';
    Item.ShelfLife := Format('%d天', [30 + (I mod 3) * 30]);
    Item.Road := '科技大道';
    if I = 2 then
    begin
      // 演示：长地址开启折行，卡片自适应撑高
      Item.Address := '地址：高新区科技大道88号创新产业大厦A座18层1808室（靠近地铁1号线科技中心站B出口东侧100米）'+
           '2@高新区科技大道88号创新产业大厦A座18层1808室（靠近地铁1号线科技中心站B出口东侧100米）'+
           '3@高新区科技大道88号创新产业大厦A座18层1808室（靠近地铁1号线科技中心站B出口东侧100米）'+
           '4@高新区科技大道88号创新产业大厦A座18层1808室（靠近地铁1号线科技中心站B出口东侧100米）'+
           '5@高新区科技大道88号创新产业大厦A座18层1808室（靠近地铁1号线科技中心站B出口东侧100米）';
      Item.MultiLineAddress := True;
    end
    else if I = 4 then
    begin
      // 演示：超长三行地址，卡片自适应撑高
      Item.Address := '地址：高新技术产业园区科技南路100号智能创新中心B栋二单元601室仓储物流综合提货中心服务站';
      Item.MultiLineAddress := True;
    end
    else if I = 3 then
    begin
      // 演示：长地址但保持默认单行截断（高度保持142px不变）
      Item.Address := '地址：高新区科技大道88号创新产业大厦A座18层1808室（未开启折行截断演示）';
      Item.MultiLineAddress := False;
    end
    else
      Item.Address := Format('地址：科技大道%d号创新大厦1019室', [I mod 20 + 1]);
    Item.Price := Prices[(I - 1) mod 8];
    Item.OriginalPrice := OldPrices[(I - 1) mod 8];
    Item.PriceTag := PriceTags[(I - 1) mod 3];
    Item.TagTop := Tags[(I - 1) mod 4];
    Item.BottomTag := BottomTags[(I - 1) mod 4];
    Item.ImageUrl := ProductImages[(I - 1) mod 8];
    // 提供 3 张图片支持左右滑动轮播
    Item.Images := [
      ProductImages[(I - 1) mod 8],
      ProductImages[((I - 1) + 1) mod 8],
      ProductImages[((I - 1) + 2) mod 8]
    ];
    Item.AutoCruise := i = 1;
    Item.ActiveImageIndex := 0;
    Item.ImageScrollOffset := 0;
    FListView.Items.Add(Item);
  end;

  FListView.IsLoading := False;
  FListView.ScrollToTop;
  FListView.UpdateLayout;
  if FListView.CanFocus then
    FListView.SetFocus;
  FListView.Redraw;
end;

procedure TForm1.LoadMerchantData;
var
  I: Integer;
  Item: TMerchantItem;
const
  Stores: array[0..5] of string = (
    '鲜丰水果（科技路店）',
    '永辉生活超市（时代广场店）',
    '传统特色面馆（科技路店）',
    '同心堂大药房（科技路店）',
    '萌宠之家宠物店',
    '便民粮油店（科技路店）'
  );
  Rates: array[0..5] of Single = (4.8, 4.7, 4.9, 4.6, 4.5, 4.4);
  Sales: array[0..5] of string = ('月售 1200+', '月售 3200+', '月售 800+', '月售 500+', '月售 260+', '月售 950+');
begin
  FListView.Clear;
  FListView.Renderer := FRendererMerchant;

  for I := 1 to 60 do
  begin
    Item := TMerchantItem.Create;
    Item.ID := I.ToString;
    Item.Title := Stores[I mod 6];
    Item.Road := '科技大道';
    Item.Address := '科技大道88号创新大厦1019室';
    Item.SalesVolume := Sales[I mod 6];
    Item.Rating := Rates[I mod 6];
    Item.ImageUrl := MerchantImages[Random(6)];
    FListView.Items.Add(Item);
  end;

  FListView.IsLoading := False;
  FListView.ScrollToTop;
  FListView.UpdateLayout;
  if FListView.CanFocus then
    FListView.SetFocus;
  FListView.Redraw;
end;

procedure TForm1.LoadMixedData;
var
  I: Integer;
  ProdItem: TProductItem;
  MerchItem: TMerchantItem;
const
  Stores: array[0..5] of string = (
    '鲜丰水果（科技路店）',
    '永辉生活超市（时代广场店）',
    '传统特色面馆（科技路店）',
    '同心堂大药房（科技路店）',
    '萌宠之家宠物店',
    '便民粮油店（科技路店）'
  );
  Rates: array[0..5] of Single = (4.8, 4.7, 4.9, 4.6, 4.5, 4.4);
  Sales: array[0..5] of string = ('月售 1200+', '月售 3200+', '月售 800+', '月售 500+', '月售 260+', '月售 950+');
begin
  FListView.Clear;

  // 1. 顶部插入 2 个单列爆款轮播大卡 (SpanCount = 1)
  for I := 1 to 2 do
  begin
    ProdItem := TProductItem.Create;
    ProdItem.ID := 'P_' + I.ToString;
    if I = 1 then
      ProdItem.Title := '【今日爆款推荐】' + BaseTitles[0]
    else
      ProdItem.Title := '【限时特惠抢购】' + BaseTitles[4];
    ProdItem.ShopTag := '官方严选';
    ProdItem.Subtitle := '起始日期：2026-10-01　终止日期：2026-10-30';
    ProdItem.ShelfLife := '保质期365天';
    ProdItem.Road := '科技大道商业中心';
    ProdItem.Address := '地址：科技大道88号创新大厦1019室';
    ProdItem.Price := Prices[(I - 1) * 4];
    ProdItem.OriginalPrice := OldPrices[(I - 1) * 4];
    ProdItem.PriceTag := '同屏爆款价';
    ProdItem.TagTop := '单列通栏';
    ProdItem.BottomTag := '顺丰冷链包邮';
    ProdItem.ImageUrl := ProductImages[(I - 1) * 4];
    ProdItem.Images := [
      ProductImages[(I - 1) * 4],
      ProductImages[((I - 1) * 4 + 1) mod 8],
      ProductImages[((I - 1) * 4 + 2) mod 8]
    ];
    ProdItem.ActiveImageIndex := 0;
    ProdItem.ImageScrollOffset := 0;
    ProdItem.AutoCruise := i = 1; // 每个 Item 均可独立配置：True 开启智能巡航，False 保持静止
    FListView.Items.Add(ProdItem);
  end;

  // 2. 紧接着插入 30 家双列网格店铺卡 (SpanCount = 2)
  for I := 1 to 30 do
  begin
    MerchItem := TMerchantItem.Create;
    MerchItem.ID := 'M_' + I.ToString;
    MerchItem.Title := Stores[I mod 6] + Format(' (第%d店)', [I]);
    MerchItem.Road := '科技大道商业街';
    MerchItem.Address := Format('科技大道%d号时代广场', [I mod 15 + 1]);
    MerchItem.SalesVolume := Sales[I mod 6];
    MerchItem.Rating := Rates[I mod 6];
    MerchItem.ImageUrl := MerchantImages[Random(6)];
    FListView.Items.Add(MerchItem);
  end;

  FListView.IsLoading := False;
  FListView.ScrollToTop;
  FListView.UpdateLayout;
  if FListView.CanFocus then
    FListView.SetFocus;
  FListView.Redraw;
end;

procedure TForm1.HandlePageFetch(Sender: TObject; const APage: Integer; const AIsRefresh: Boolean);
begin
  // 使用轻量原生执行器 TAsync.Run 异步调度后台线程池调用接口
  TAsync.Run<TArray<TObject>>(
    function: TArray<TObject>
    var
      StartIdx, J: Integer;
      ProdItem: TProductItem;
      MerchItem: TMerchantItem;
      NewOrder: TOrder;
      LItems: TList<TObject>;
    const
      Stores: array[0..5] of string = (
        '鲜丰水果（科技路店）',
        '永辉生活超市（时代广场店）',
        '传统特色面馆（科技路店）',
        '同心堂大药房（科技路店）',
        '萌宠之家宠物店',
        '便民粮油店（科技路店）'
      );
      Rates: array[0..5] of Single = (4.8, 4.7, 4.9, 4.6, 4.5, 4.4);
      Sales: array[0..5] of string = ('月售 1200+', '月售 3200+', '月售 800+', '月售 500+', '月售 260+', '月售 950+');
    begin
      // 1. 【子线程执行】模拟网络 I/O 延迟
      Sleep(350);

      // 故障注入测试：若用户开启了“故障模拟”开关，在后台抛出网络或接口异常
      if FSimulateError then
        raise Exception.Create('远程接口请求超时 [HTTP 504 Gateway Timeout]，服务器无响应！');

      LItems := TList<TObject>.Create;
      try
        // 若为下拉刷新，重载第 1 批基础数据
        if AIsRefresh then
          StartIdx := 1
        else
          StartIdx := (APage - 1) * 10 + 1;

        if FCurrentMode = vmProduct then
        begin
          for J := StartIdx to StartIdx + 9 do
          begin
            ProdItem := TProductItem.Create;
            ProdItem.ID := J.ToString;
            ProdItem.Title := BaseTitles[(J - 1) mod 8] + Format(' (第%d页)', [APage]);
            ProdItem.ShopTag := '小店好货';
            ProdItem.Subtitle := '起始日期：2026-10-01　终止日期：2026-10-30';
            ProdItem.ShelfLife := Format('%d天', [30 + (J mod 3) * 30]);
            ProdItem.Road := '科技大道';
            ProdItem.Address := Format('地址：科技大道%d号创新大厦1019室', [J mod 20 + 1]);
            ProdItem.Price := Prices[(J - 1) mod 8];
            ProdItem.OriginalPrice := OldPrices[(J - 1) mod 8];
            ProdItem.PriceTag := PriceTags[(J - 1) mod 3];
            ProdItem.TagTop := Tags[(J - 1) mod 4];
            ProdItem.BottomTag := BottomTags[(J - 1) mod 4];
            ProdItem.ImageUrl := ProductImages[(J - 1) mod 8];
            ProdItem.Images := [
              ProductImages[(J - 1) mod 8],
              ProductImages[((J - 1) + 1) mod 8],
              ProductImages[((J - 1) + 2) mod 8]
            ];
            ProdItem.ActiveImageIndex := 0;
            ProdItem.ImageScrollOffset := 0;
            ProdItem.AutoCruise := False;
            LItems.Add(ProdItem);
          end;
        end
        else if FCurrentMode = vmMerchant then
        begin
          for J := StartIdx to StartIdx + 9 do
          begin
            MerchItem := TMerchantItem.Create;
            MerchItem.ID := J.ToString;
            MerchItem.Title := Stores[J mod 6] + Format(' (第%d页-%d)', [APage, J]);
            MerchItem.Road := '科技大道';
            MerchItem.Address := Format('科技大道%d号创新大厦1019室', [J mod 20 + 1]);
            MerchItem.SalesVolume := Sales[J mod 6];
            MerchItem.Rating := Rates[J mod 6];
            MerchItem.ImageUrl := MerchantImages[Random(6)];
            LItems.Add(MerchItem);
          end;
        end
        else if FCurrentMode = vmOrder then
        begin
          for J := 1 to 3 do
          begin
            NewOrder := TOrder.Create('YT20261103' + Format('%.4d', [StartIdx + J]), '2026-11-03', '已完成');
            NewOrder.AddDetail(Format('追加商品(第%d页) - ', [APage]) + BaseTitles[(StartIdx + J) mod 8],
              ProductImages[(StartIdx + J) mod 8], '规格标准版', Prices[(StartIdx + J) mod 8], 1 + (J mod 2));
            if J mod 2 = 0 then
              NewOrder.AddDetail('赠品 - 蒙牛纯牛奶250ml', ProductImages[7], '随单赠送', 0.0, 1);
            LItems.Add(NewOrder);
          end;
        end
        else
        begin
          // 混排模式追加
          ProdItem := TProductItem.Create;
          ProdItem.ID := 'P_' + StartIdx.ToString;
          ProdItem.Title := Format('【第%d页爆款】', [APage]) + BaseTitles[(StartIdx - 1) mod 8];
          ProdItem.ShopTag := '超级精选';
          ProdItem.Subtitle := '起始日期：2026-10-01　终止日期：2026-10-30';
          ProdItem.ShelfLife := '60天';
          ProdItem.Road := '科技大道';
          ProdItem.Address := '科技大道特1号';
          ProdItem.Price := Prices[(StartIdx - 1) mod 8];
          ProdItem.OriginalPrice := OldPrices[(StartIdx - 1) mod 8];
          ProdItem.PriceTag := '直降补贴';
          ProdItem.TagTop := '单列通栏';
          ProdItem.BottomTag := '正品包邮';
          ProdItem.ImageUrl := ProductImages[(StartIdx - 1) mod 8];
          ProdItem.Images := [
            ProductImages[(StartIdx - 1) mod 8],
            ProductImages[((StartIdx - 1) + 1) mod 8],
            ProductImages[((StartIdx - 1) + 2) mod 8]
          ];
          ProdItem.ActiveImageIndex := 0;
          ProdItem.ImageScrollOffset := 0;
          ProdItem.AutoCruise := (StartIdx = 1);
          LItems.Add(ProdItem);

          for J := StartIdx + 1 to StartIdx + 6 do
          begin
            MerchItem := TMerchantItem.Create;
            MerchItem.ID := 'M_' + J.ToString;
            MerchItem.Title := Stores[J mod 6] + Format(' (第%d页-%d)', [APage, J]);
            MerchItem.Road := '科技大道';
            MerchItem.Address := '科技大道商业街';
            MerchItem.SalesVolume := Sales[J mod 6];
            MerchItem.Rating := Rates[J mod 6];
            MerchItem.ImageUrl := MerchantImages[Random(6)];
            LItems.Add(MerchItem);
          end;
        end;

        Result := LItems.ToArray;
      finally
        LItems.Free;
      end;
    end)
    .OnSuccess(procedure(AItems: TArray<TObject>)
    var
      Item: TObject;
      HasNextPage: Boolean;
    begin
      // 2. 【UI 主线程安全回调】渲染数据到列表
      if AIsRefresh then
        FListView.Clear;

      for Item in AItems do
        FListView.Items.Add(Item);

      // 模拟在第 3 页达到上限（HasNextPage := False，底部自绘“— 已显示全部内容 —”）
      HasNextPage := (APage < 3);
      FListView.FinishFetch(True, HasNextPage);
    end)
    .OnError(procedure(E: Exception)
    begin
      // 3. 【UI 主线程安全回调】拦截异常、弹窗提示并收敛分页状态
      FListView.FinishFetch(False, False);
      TDialogService.ShowMessage('接口拉取失败: ' + E.Message);
    end);
end;

procedure TForm1.HandleItemClick(Sender: TObject; AIndex: Integer; AItem: TObject; AZoneID: Integer);
var
  Product: TProductItem;
  Merchant: TMerchantItem;
begin
  if AItem is TProductItem then
  begin
    Product := TProductItem(AItem);
    if AZoneID = ZONE_ACTION_BUY then
    begin
      TDialogService.ShowMessage('已成功加入购物车: ' + Product.Title +
        ' (¥' + Format('%.1f', [Product.Price]) + ')');
    end
    else if AZoneID = ZONE_IMAGE_CAROUSEL then
    begin
      // 若当前图片包含 404 或失效，触发重试下载并无感刷新
      if Product.ImageUrl.Contains('404') then
      begin
        TSkImageCache.RetryUrl(Product.ImageUrl);
        FListView.NotifyItemChanged(AIndex, False);
      end;
      TDialogService.ShowMessage('点击了商品多图轮播画廊: ' + Product.Title +
        Format(' (当前显示第 %d/3 张图，可直接在图片上左右划动切换)', [Product.ActiveImageIndex + 1]));
    end
    else
    begin
      TDialogService.ShowMessage('点击商品卡片进入详情: ' + Product.Title);
    end;
  end
  else if AItem is TMerchantItem then
  begin
    Merchant := TMerchantItem(AItem);
    TDialogService.ShowMessage('点击商家卡片进入主页: ' + Merchant.Title +
      ' [评分: ' + Format('%.1f', [Merchant.Rating]) + ']');
  end
  else if AItem is TOrder then
  begin
    var OrderItem := TOrder(AItem);
    case AZoneID of
      ZONE_BTN_LOGISTICS:
        TDialogService.ShowMessage('【物流追踪】订单号：' + OrderItem.OrderId + #13#10 + '顺丰速运火速配送中，请保持电话畅通！');
      ZONE_BTN_PAY:
        TDialogService.ShowMessage('【收银台】正在为订单 ' + OrderItem.OrderId + ' 调起支付' + #13#10 +
          '实付金额：¥' + FormatFloat('0.00', OrderItem.TotalAmount));
      ZONE_BTN_CANCEL:
        TDialogService.ShowMessage('【取消订单】订单号：' + OrderItem.OrderId + ' 已申请取消');
    else
      TDialogService.ShowMessage('【订单详情】点击进入订单详情卡片：' + OrderItem.OrderId + #13#10 +
        '包含商品：' + OrderItem.TotalQty.ToString + ' 件，实付：¥' + FormatFloat('0.00', OrderItem.TotalAmount));
    end;
  end;
end;

end.
