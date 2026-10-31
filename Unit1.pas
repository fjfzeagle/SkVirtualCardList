unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.StdCtrls, FMX.DialogService,
  SkVirtualList.Core, SkCardRenderers.Biz, FMX.Controls.Presentation,
  FMX.Objects;

type
  TViewMode = (vmProduct, vmMerchant, vmMixed);

  TForm1 = class(TForm)
    LayoutTopBar: TLayout;
    BtnSingleProduct: TButton;
    BtnDoubleMerchant: TButton;
    LayoutContainer: TLayout;
    procedure FormCreate(Sender: TObject);
    procedure BtnSingleProductClick(Sender: TObject);
    procedure BtnDoubleMerchantClick(Sender: TObject);
  private
    FListView: TSkVirtualListView;
    FRendererProduct: ISkCardRenderer;
    FRendererMerchant: ISkCardRenderer;
    FCurrentMode: TViewMode;
    BtnToggleCruise: TButton;

    procedure LoadProductData;
    procedure LoadMerchantData;
    procedure LoadMixedData;
    procedure BtnMixedClick(Sender: TObject);
    procedure HandleItemClick(Sender: TObject; AIndex: Integer; AItem: TObject; AZoneID: Integer);
    procedure HandleLoadMore(Sender: TObject);
    procedure HandleRefresh(Sender: TObject);
    procedure HandleEmptyClick(Sender: TObject);
    procedure HandleToggleCruiseClick(Sender: TObject);
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
begin
  Caption := 'Skia 虚拟化解耦列表 (声明式 DSL / 多图轮播 / 下拉刷新 / 骨架屏 / 单双列同屏混排)';
  BtnSingleProduct.Text := '单列';
  BtnSingleProduct.Width := 36;
  BtnDoubleMerchant.Text := '双列';
  BtnDoubleMerchant.Width := 36;

  // 动态创建“同屏混排”模式切换按钮
  BtnMixed := TButton.Create(Self);
  BtnMixed.Parent := BtnSingleProduct.Parent;
  BtnMixed.Align := TAlignLayout.Left;
  BtnMixed.Width := 36;
  BtnMixed.Margins.Left := 4;
  BtnMixed.Margins.Top := 8;
  BtnMixed.Margins.Bottom := 8;
  BtnMixed.Text := '混排';
  BtnMixed.OnClick := BtnMixedClick;

  // 动态创建并挂载“空状态”测试按钮
  BtnEmptyState := TButton.Create(Self);
  BtnEmptyState.Parent := BtnSingleProduct.Parent;
  BtnEmptyState.Align := TAlignLayout.Right;
  BtnEmptyState.Width := 56;
  BtnEmptyState.Margins.Right := 6;
  BtnEmptyState.Margins.Top := 8;
  BtnEmptyState.Margins.Bottom := 8;
  BtnEmptyState.Text := '空状态';
  BtnEmptyState.OnClick := HandleEmptyClick;

  // 动态创建并挂载“自动巡航控制开关”按钮
  BtnToggleCruise := TButton.Create(Self);
  BtnToggleCruise.Parent := BtnSingleProduct.Parent;
  BtnToggleCruise.Align := TAlignLayout.Right;
  BtnToggleCruise.Width := 68;
  BtnToggleCruise.Margins.Right := 4;
  BtnToggleCruise.Margins.Top := 8;
  BtnToggleCruise.Margins.Bottom := 8;
  BtnToggleCruise.Text := '巡航:开';
  BtnToggleCruise.OnClick := HandleToggleCruiseClick;

  // 1. 初始化各业务卡片渲染器
  FRendererProduct := TSingleProductCardRenderer.Create;
  FRendererMerchant := TDoubleMerchantCardRenderer.Create;

  // 2. 创建并挂载通用虚拟列表引擎
  FListView := TSkVirtualListView.Create(Self);
  FListView.Parent := LayoutContainer;
  FListView.Align := TAlignLayout.Client;
  FListView.ItemSpacing := 8;

  // 3. 注册多类型数据实体与专属渲染器映射关系 (实现单双列同屏混排)
  FListView.RegisterRenderer(TProductItem, FRendererProduct);
  FListView.RegisterRenderer(TMerchantItem, FRendererMerchant);

  LayoutTopBar.BringToFront;
  LayoutContainer.ClipChildren := True;

  // 4. 绑定统一精准点击事件、下拉刷新与触底加载更多回调
  FListView.OnItemClick := HandleItemClick;
  FListView.OnLoadMore := HandleLoadMore;
  FListView.OnRefresh := HandleRefresh;

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

procedure TForm1.HandleRefresh(Sender: TObject);
begin
  // 模拟异步下拉刷新（600ms 后重载数据并调用 FinishRefreshing 平滑回弹）
  TThread.CreateAnonymousThread(procedure
  begin
    Sleep(600);
    TThread.Synchronize(nil, procedure
    begin
      if FCurrentMode = vmProduct then
        LoadProductData
      else if FCurrentMode = vmMerchant then
        LoadMerchantData
      else
        LoadMixedData;
      FListView.FinishRefreshing;
    end);
  end).Start;
end;

procedure TForm1.HandleLoadMore(Sender: TObject);
begin
  // 模拟异步拉取分页数据（350ms 后追加数据）
  TThread.CreateAnonymousThread(procedure
  begin
    Sleep(350);
    TThread.Synchronize(nil, procedure
    var
      StartIdx, J: Integer;
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
      StartIdx := FListView.Items.Count + 1;
      if FCurrentMode = vmProduct then
      begin
        for J := StartIdx to StartIdx + 9 do
        begin
          ProdItem := TProductItem.Create;
          ProdItem.ID := J.ToString;
          ProdItem.Title := BaseTitles[(J - 1) mod 8] + Format(' (第%d批)', [J div 10]);
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
          ProdItem.AutoCruise := False; // 追加的普通分页商品默认不开启巡航
          FListView.Items.Add(ProdItem);
        end;
      end
      else if FCurrentMode = vmMerchant then
      begin
        for J := StartIdx to StartIdx + 9 do
        begin
          MerchItem := TMerchantItem.Create;
          MerchItem.ID := J.ToString;
          MerchItem.Title := Stores[J mod 6] + Format(' (分店%d)', [J]);
          MerchItem.Road := '科技大道';
          MerchItem.Address := Format('科技大道%d号创新大厦1019室', [J mod 20 + 1]);
          MerchItem.SalesVolume := Sales[J mod 6];
          MerchItem.Rating := Rates[J mod 6];
          MerchItem.ImageUrl := MerchantImages[Random(6)];
          FListView.Items.Add(MerchItem);
        end;
      end
      else
      begin
        // 混排模式追加：1个爆款单列通栏卡 + 6家双列网格店铺卡
        ProdItem := TProductItem.Create;
        ProdItem.ID := 'P_' + StartIdx.ToString;
        ProdItem.Title := '【追加爆款】' + BaseTitles[(StartIdx - 1) mod 8];
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
        ProdItem.AutoCruise := False; // 混排追加的爆款卡默认不开启巡航
        FListView.Items.Add(ProdItem);

        for J := StartIdx + 1 to StartIdx + 6 do
        begin
          MerchItem := TMerchantItem.Create;
          MerchItem.ID := 'M_' + J.ToString;
          MerchItem.Title := Stores[J mod 6] + Format(' (混排推荐%d)', [J]);
          MerchItem.Road := '科技大道';
          MerchItem.Address := '科技大道商业街';
          MerchItem.SalesVolume := Sales[J mod 6];
          MerchItem.Rating := Rates[J mod 6];
          MerchItem.ImageUrl := MerchantImages[Random(6)];
          FListView.Items.Add(MerchItem);
        end;
      end;

      FListView.IsLoadingMore := False;
      FListView.UpdateLayout;
    end);
  end).Start;
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
  end;
end;

end.
