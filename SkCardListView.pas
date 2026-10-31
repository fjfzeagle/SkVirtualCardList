unit SkCardListView;

{==============================================================================
  [Legacy / Prototype Notice - 历史原型归档说明]
  此单元为项目第一代单体自绘原型验证版本。
  生产环境与当前项目已全面升级至四层解耦工业级架构：
    1. 核心虚拟化容器引擎：SkVirtualList.Core.pas (TSkVirtualListView)
    2. 声明式流式排版 DSL：SkUiDsl.pas (HStack, VStack, Box, Svg, Carousel)
    3. 业务卡片渲染器策略：SkCardRenderers.Biz.pas
    4. 异步并发安全图片缓存：SkImageCache.pas
  本文件仅保留供历史参考与对比基准测试使用。
==============================================================================}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Generics.Collections, System.Threading, System.Net.HttpClient,
  System.IOUtils, System.Hash,
  System.Skia, FMX.Skia,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.InertialMovement;

type
  // 卡片展示模式：单列商品卡 (merchant.html) 或 双列商家卡 (merchant-list.html)
  TCardViewMode = (vmSingleProduct, vmDoubleMerchant);

  // 统一测试数据实体
  TCardItem = class
  public
    ID: string;
    Title: string;
    Subtitle: string;     // 如: "起始日期：2026-10-01 终止日期：..."
    Road: string;         // 如: "科技大道"
    ShelfLife: string;    // 如: "30天"
    Address: string;      // 如: "科技大道88号创新大厦1019室"
    TagTop: string;       // 如: "新人专享" / "百亿补贴"
    ImageUrl: string;     // 在线图片 URL
    // 单列商品特有字段
    Price: Currency;      // 现价
    OriginalPrice: Currency; // 原价
    PriceTag: string;     // 如: "补贴价"
    // 双列商家特有字段
    SalesVolume: string;  // 如: "月售 1200+"
    Rating: Single;       // 评分 (如 4.8)

    // 内部命中区域计算缓存（点击判断）
    LastCardRect: TRectF;
    LastActionBtnRect: TRectF;
  end;

  TOnCardItemEvent = procedure(Sender: TObject; AItem: TCardItem) of object;
  TImageLoadedProc = reference to procedure;

  // 具备 LRU (Least Recently Used) 淘汰与磁盘持久化二级缓存的图片管理器
  TSkImageCache = class
  public const
    MAX_LRU_CAPACITY = 60; // 内存最多驻留 60 张图片，超出自动淘汰最久未访问的图片
  private
    class var FCache: TDictionary<string, ISkImage>; // 内存缓存字典 O(1) 查询
    class var FLruOrder: TList<string>;             // 访问时间序队列（0 为最久未访问，末尾为最新）
    class var FDownloading: TList<string>;          // 正在异步下载中的 URL 列表
    class var FLock: TObject;                       // 线程并发安全锁
    class var FDiskCacheDir: string;                // 本地磁盘持久化目录

    class constructor Create;
    class destructor Destroy;
    class procedure TouchLRU(const AUrl: string);
    class procedure PutImage(const AUrl: string; const AImage: ISkImage);
    class function GetDiskCacheFilePath(const AUrl: string): string;
  public
    class function GetImage(const AUrl: string; const AOnLoaded: TImageLoadedProc): ISkImage;
    class function MemoryCount: Integer;
    class procedure ClearMemoryCache;
  end;

  TSkCardListView = class(TSkPaintBox)
  private
    FAniCalculations: TAniCalculations;
    FItems: TObjectList<TCardItem>;
    FViewMode: TCardViewMode;
    FItemSpacing: Single;

    // 鼠标/触控拖拽与点击跟踪
    FIsMouseDown: Boolean;
    FDownPos: TPointF;
    FLastMousePos: TPointF;
    FHasDragged: Boolean;

    FOnCardClick: TOnCardItemEvent;
    FOnActionClick: TOnCardItemEvent;

    // 缓存中文字体族
    FRegularTypeface: ISkTypeface;
    FBoldTypeface: ISkTypeface;

    procedure InitTypefaces;
    procedure HandleAniChange(Sender: TObject);
    function GetTotalContentHeight: Single;
    procedure ScrollByDelta(const ADeltaY: Single);
    procedure DrawEllipsisText(const ACanvas: ISkCanvas; const AText: string;
      const X, Y, AMaxWidth: Single; const AFont: ISkFont; const APaint: ISkPaint);
    procedure DrawStarRating(const ACanvas: ISkCanvas; const ARect: TRectF; const ARate: Single);
    procedure DrawSingleProductCard(const ACanvas: ISkCanvas; AItem: TCardItem; const ARect: TRectF);
    procedure DrawDoubleMerchantCard(const ACanvas: ISkCanvas; AItem: TCardItem; const ARect: TRectF);
    procedure SetViewMode(const Value: TCardViewMode);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure UpdateLayout;

    property Items: TObjectList<TCardItem> read FItems;
    property ViewMode: TCardViewMode read FViewMode write SetViewMode;
    property ItemSpacing: Single read FItemSpacing write FItemSpacing;
    property OnCardClick: TOnCardItemEvent read FOnCardClick write FOnCardClick;
    property OnActionClick: TOnCardItemEvent read FOnActionClick write FOnActionClick;
  end;

implementation

{ TSkImageCache }

class constructor TSkImageCache.Create;
begin
  FCache := TDictionary<string, ISkImage>.Create;
  FLruOrder := TList<string>.Create;
  FDownloading := TList<string>.Create;
  FLock := TObject.Create;

  // 初始化本地磁盘缓存目录
  FDiskCacheDir := TPath.Combine(TPath.GetCachePath, 'SkiaImgCache');
  if not TDirectory.Exists(FDiskCacheDir) then
    ForceDirectories(FDiskCacheDir);
end;

class destructor TSkImageCache.Destroy;
begin
  FCache.Free;
  FLruOrder.Free;
  FDownloading.Free;
  FLock.Free;
end;

class function TSkImageCache.GetDiskCacheFilePath(const AUrl: string): string;
var
  UrlHash: string;
begin
  // 使用 MD5 哈希作为磁盘缓存文件名
  UrlHash := THashMD5.GetHashString(AUrl);
  Result := TPath.Combine(FDiskCacheDir, UrlHash + '.cache');
end;

// 访问命中时将该 URL 移至队列末尾（表示最近使用）
class procedure TSkImageCache.TouchLRU(const AUrl: string);
begin
  FLruOrder.Remove(AUrl);
  FLruOrder.Add(AUrl);
end;

// 放入新图片时执行 LRU 容量检查与淘汰
class procedure TSkImageCache.PutImage(const AUrl: string; const AImage: ISkImage);
var
  OldestUrl: string;
begin
  if AImage = nil then Exit;

  // 若超出最大容量，循环淘汰最久未访问的图片
  while FCache.Count >= MAX_LRU_CAPACITY do
  begin
    if FLruOrder.Count > 0 then
    begin
      OldestUrl := FLruOrder[0];
      FLruOrder.Delete(0);
      FCache.Remove(OldestUrl); // 从内存字典淘汰，由 ARC 自动释放图片句柄
    end
    else
      Break;
  end;

  FCache.AddOrSetValue(AUrl, AImage);
  TouchLRU(AUrl);
end;

class function TSkImageCache.GetImage(const AUrl: string; const AOnLoaded: TImageLoadedProc): ISkImage;
var
  DiskFile: string;
begin
  Result := nil;
  if AUrl.Trim.IsEmpty then Exit;

  // 1. 检查一级缓存：内存 LRU 命中
  TMonitor.Enter(FLock);
  try
    if FCache.TryGetValue(AUrl, Result) then
    begin
      TouchLRU(AUrl); // 刷新访问时间戳
      Exit;
    end;

    // 若当前已在后台下载管道中，直接退出并等待回调
    if FDownloading.Contains(AUrl) then
      Exit;

    FDownloading.Add(AUrl);
  finally
    TMonitor.Exit(FLock);
  end;

  // 2. 抛入后台任务池：二级磁盘缓存读取 或 网络异步下载
  DiskFile := GetDiskCacheFilePath(AUrl);

  TTask.Run(procedure
  var
    LHttp: THTTPClient;
    LStream: TMemoryStream;
    LSkImage: ISkImage;
  begin
    LSkImage := nil;

    try
      // A. 先检查本地磁盘二级缓存
      if TFile.Exists(DiskFile) then
      begin
        try
          LSkImage := TSkImage.MakeFromEncodedFile(DiskFile);
        except
          LSkImage := nil;
        end;
      end;

      // B. 磁盘未命中，走网络 HTTP 下载并写入磁盘
      if LSkImage = nil then
      begin
        LHttp := THTTPClient.Create;
        LStream := TMemoryStream.Create;
        try
          try
            LHttp.ConnectionTimeout := 10000;
            LHttp.ResponseTimeout := 10000;
            if LHttp.Get(AUrl, LStream).StatusCode = 200 then
            begin
              LStream.Position := 0;
              // 异步写入本地磁盘缓存文件
              try
                LStream.SaveToFile(DiskFile);
              except
                // 磁盘写入失败不影响内存解码
              end;

              LStream.Position := 0;
              LSkImage := TSkImage.MakeFromEncodedStream(LStream);
            end;
          except
            LSkImage := nil;
          end;
        finally
          LStream.Free;
          LHttp.Free;
        end;
      end;

      // C. 存入内存 LRU 队列并移除下载标记
      TMonitor.Enter(FLock);
      try
        if LSkImage <> nil then
          PutImage(AUrl, LSkImage);
        FDownloading.Remove(AUrl);
      finally
        TMonitor.Exit(FLock);
      end;

      // D. 回到主线程通知局部重绘
      if (LSkImage <> nil) and Assigned(AOnLoaded) then
      begin
        TThread.Queue(nil, procedure
        begin
          AOnLoaded();
        end);
      end;
    except
      TMonitor.Enter(FLock);
      try
        FDownloading.Remove(AUrl);
      finally
        TMonitor.Exit(FLock);
      end;
    end;
  end);
end;

class function TSkImageCache.MemoryCount: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := FCache.Count;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSkImageCache.ClearMemoryCache;
begin
  TMonitor.Enter(FLock);
  try
    FCache.Clear;
    FLruOrder.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TSkCardListView }

constructor TSkCardListView.Create(AOwner: TComponent);
begin
  inherited;
  HitTest := True;
  AutoCapture := True;
  CanFocus := True;

  FItems := TObjectList<TCardItem>.Create(True);
  FViewMode := vmSingleProduct;
  FItemSpacing := 8;
  FIsMouseDown := False;
  FHasDragged := False;

  InitTypefaces;

  FAniCalculations := TAniCalculations.Create(nil);
  FAniCalculations.Animation := True;
  FAniCalculations.Averaging := True;
  FAniCalculations.TouchTracking := [ttVertical];
  FAniCalculations.OnChanged := HandleAniChange;
end;

destructor TSkCardListView.Destroy;
begin
  FAniCalculations.Free;
  FItems.Free;
  inherited;
end;

procedure TSkCardListView.InitTypefaces;
begin
  {$IFDEF MSWINDOWS}
  FRegularTypeface := TSkTypeface.MakeFromName('Microsoft YaHei', TSkFontStyle.Normal);
  FBoldTypeface := TSkTypeface.MakeFromName('Microsoft YaHei', TSkFontStyle.Bold);
  if FRegularTypeface = nil then
    FRegularTypeface := TSkTypeface.MakeFromName('SimHei', TSkFontStyle.Normal);
  if FBoldTypeface = nil then
    FBoldTypeface := TSkTypeface.MakeFromName('SimHei', TSkFontStyle.Bold);
  {$ENDIF}

  {$IFDEF ANDROID}
  FRegularTypeface := TSkTypeface.MakeFromName('Noto Sans CJK SC', TSkFontStyle.Normal);
  FBoldTypeface := TSkTypeface.MakeFromName('Noto Sans CJK SC', TSkFontStyle.Bold);
  if FRegularTypeface = nil then
    FRegularTypeface := TSkTypeface.MakeFromName('sans-serif', TSkFontStyle.Normal);
  if FBoldTypeface = nil then
    FBoldTypeface := TSkTypeface.MakeFromName('sans-serif', TSkFontStyle.Bold);
  {$ENDIF}

  {$IF defined(IOS) or defined(MACOS)}
  FRegularTypeface := TSkTypeface.MakeFromName('PingFang SC', TSkFontStyle.Normal);
  FBoldTypeface := TSkTypeface.MakeFromName('PingFang SC', TSkFontStyle.Bold);
  {$ENDIF}

  if FRegularTypeface = nil then
    FRegularTypeface := TSkTypeface.MakeDefault;
  if FBoldTypeface = nil then
    FBoldTypeface := TSkTypeface.MakeFromName('', TSkFontStyle.Bold);
  if FBoldTypeface = nil then
    FBoldTypeface := FRegularTypeface;
end;

procedure TSkCardListView.SetViewMode(const Value: TCardViewMode);
begin
  if FViewMode <> Value then
  begin
    FViewMode := Value;
    FAniCalculations.ViewportPosition := TPointD.Create(0, 0);
    UpdateLayout;
  end;
end;

procedure TSkCardListView.Resize;
begin
  inherited;
  UpdateLayout;
end;

procedure TSkCardListView.HandleAniChange(Sender: TObject);
begin
  Redraw;
end;

function TSkCardListView.GetTotalContentHeight: Single;
var
  TotalRows: Integer;
  CardHeight, ColWidth: Single;
begin
  Result := 0;
  if (Width <= 0) or (FItems.Count = 0) then Exit;

  if FViewMode = vmSingleProduct then
  begin
    CardHeight := 142;
    TotalRows := FItems.Count;
    Result := TotalRows * (CardHeight + FItemSpacing) + FItemSpacing;
  end
  else
  begin
    ColWidth := (Width - 3 * FItemSpacing) / 2;
    CardHeight := ColWidth * 0.75 + 92;
    TotalRows := Ceil(FItems.Count / 2);
    Result := TotalRows * (CardHeight + FItemSpacing) + FItemSpacing;
  end;
end;

procedure TSkCardListView.ScrollByDelta(const ADeltaY: Single);
var
  NewY, MaxY: Single;
begin
  MaxY := Max(0, GetTotalContentHeight - Height);
  NewY := EnsureRange(FAniCalculations.ViewportPosition.Y + ADeltaY, 0, MaxY);
  FAniCalculations.ViewportPosition := TPointD.Create(0, NewY);
  Redraw;
end;

procedure TSkCardListView.UpdateLayout;
var
  TotalHeight: Single;
  Targets: array[0..1] of TAniCalculations.TTarget;
begin
  TotalHeight := GetTotalContentHeight;
  if TotalHeight <= 0 then Exit;

  Targets[0].TargetType := TAniCalculations.TTargetType.Min;
  Targets[0].Point := TPointD.Create(0, 0);
  Targets[1].TargetType := TAniCalculations.TTargetType.Max;
  Targets[1].Point := TPointD.Create(0, Max(0, TotalHeight - Height));
  FAniCalculations.SetTargets(Targets);

  Redraw;
end;

procedure TSkCardListView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if Button = TMouseButton.mbLeft then
  begin
    FIsMouseDown := True;
    FDownPos := PointF(X, Y);
    FLastMousePos := PointF(X, Y);
    FHasDragged := False;
    Capture;
    FAniCalculations.MouseDown(X, Y);
  end;
end;

procedure TSkCardListView.MouseMove(Shift: TShiftState; X, Y: Single);
var
  CurPos: TPointF;
  DeltaY: Single;
begin
  inherited;
  if FIsMouseDown then
  begin
    CurPos := PointF(X, Y);
    if CurPos.Distance(FDownPos) > 6 then
      FHasDragged := True;

    DeltaY := CurPos.Y - FLastMousePos.Y;
    if Abs(DeltaY) > 0.1 then
    begin
      ScrollByDelta(-DeltaY);
      FLastMousePos := CurPos;
    end;

    FAniCalculations.MouseMove(X, Y);
  end;
end;

procedure TSkCardListView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
  ClickPoint: TPointF;
  Item: TCardItem;
  BtnHitRect: TRectF;
begin
  inherited;
  if Button = TMouseButton.mbLeft then
  begin
    ReleaseCapture;
    FIsMouseDown := False;
    FAniCalculations.MouseUp(X, Y);

    if not FHasDragged then
    begin
      ClickPoint := PointF(X, Y);
      for I := 0 to FItems.Count - 1 do
      begin
        Item := FItems[I];
        if Item.LastCardRect.Contains(ClickPoint) then
        begin
          BtnHitRect := Item.LastActionBtnRect;
          BtnHitRect.Inflate(6, 6);

          if (FViewMode = vmSingleProduct) and BtnHitRect.Contains(ClickPoint) then
          begin
            if Assigned(FOnActionClick) then
              FOnActionClick(Self, Item);
          end
          else
          begin
            if Assigned(FOnCardClick) then
              FOnCardClick(Self, Item);
          end;
          Break;
        end;
      end;
    end;
  end;
end;

procedure TSkCardListView.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  ScrollByDelta(-WheelDelta * 0.8);
  Handled := True;
end;

procedure TSkCardListView.DrawEllipsisText(const ACanvas: ISkCanvas; const AText: string;
  const X, Y, AMaxWidth: Single; const AFont: ISkFont; const APaint: ISkPaint);
var
  CurText: string;
  Len: Integer;
begin
  if AFont.MeasureText(AText) <= AMaxWidth then
  begin
    ACanvas.DrawSimpleText(AText, X, Y, AFont, APaint);
    Exit;
  end;

  CurText := AText;
  Len := CurText.Length;
  while (Len > 1) and (AFont.MeasureText(CurText + '...') > AMaxWidth) do
  begin
    Dec(Len);
    CurText := AText.Substring(0, Len);
  end;
  ACanvas.DrawSimpleText(CurText + '...', X, Y, AFont, APaint);
end;

procedure TSkCardListView.DrawStarRating(const ACanvas: ISkCanvas; const ARect: TRectF; const ARate: Single);
const
  StarGlyph: WideChar = #$2605; // ★
var
  I: Integer;
  StarLeft: Single;
  LPaint: ISkPaint;
  LFont: ISkFont;
begin
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LFont := TSkFont.Create(FRegularTypeface, 10);

  for I := 1 to 5 do
  begin
    StarLeft := ARect.Left + (I - 1) * 11;
    if I <= Floor(ARate) then
    begin
      LPaint.Color := $FFE6432E; // 实心红
      ACanvas.DrawSimpleText(string(StarGlyph), StarLeft, ARect.Top + 10, LFont, LPaint);
    end
    else
    begin
      LPaint.Color := $FFE0E0E4; // 空心灰
      ACanvas.DrawSimpleText(string(StarGlyph), StarLeft, ARect.Top + 10, LFont, LPaint);
    end;
  end;

  LPaint.Color := $FFE6432E;
  LFont.Size := 10.5;
  ACanvas.DrawSimpleText(Format('%.1f', [ARate]), ARect.Left + 56, ARect.Top + 10, LFont, LPaint);
end;

procedure TSkCardListView.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
var
  ScrollY, CardHeight, ColWidth: Single;
  StartRow, EndRow, R, C, Idx: Integer;
  CardRect: TRectF;
  Item: TCardItem;
begin
  inherited;
  if FItems.Count = 0 then Exit;

  // 严格开启视口裁切，防止卡片绘制溢出到顶部导航栏
  ACanvas.Save;
  try
    ACanvas.ClipRect(ADest);

    ScrollY := FAniCalculations.ViewportPosition.Y;

    if FViewMode = vmSingleProduct then
    begin
      CardHeight := 142;
      StartRow := Max(0, Floor(ScrollY / (CardHeight + FItemSpacing)));
      EndRow := Min(FItems.Count - 1, Ceil((ScrollY + Height) / (CardHeight + FItemSpacing)));

      for R := StartRow to EndRow do
      begin
        Item := FItems[R];
        CardRect := RectF(
          FItemSpacing,
          FItemSpacing + R * (CardHeight + FItemSpacing) - ScrollY,
          Width - FItemSpacing,
          FItemSpacing + R * (CardHeight + FItemSpacing) + CardHeight - ScrollY
        );
        Item.LastCardRect := CardRect;
        DrawSingleProductCard(ACanvas, Item, CardRect);
      end;
    end
    else
    begin
      ColWidth := (Width - 3 * FItemSpacing) / 2;
      CardHeight := ColWidth * 0.75 + 92;

      StartRow := Max(0, Floor(ScrollY / (CardHeight + FItemSpacing)));
      EndRow := Min(Ceil(FItems.Count / 2) - 1, Ceil((ScrollY + Height) / (CardHeight + FItemSpacing)));

      for R := StartRow to EndRow do
      begin
        for C := 0 to 1 do
        begin
          Idx := R * 2 + C;
          if Idx >= FItems.Count then Break;

          Item := FItems[Idx];
          CardRect := RectF(
            FItemSpacing + C * (ColWidth + FItemSpacing),
            FItemSpacing + R * (CardHeight + FItemSpacing) - ScrollY,
            FItemSpacing + C * (ColWidth + FItemSpacing) + ColWidth,
            FItemSpacing + R * (CardHeight + FItemSpacing) + CardHeight - ScrollY
          );
          Item.LastCardRect := CardRect;
          DrawDoubleMerchantCard(ACanvas, Item, CardRect);
        end;
      end;
    end;
  finally
    ACanvas.Restore;
  end;
end;

procedure TSkCardListView.DrawSingleProductCard(const ACanvas: ISkCanvas; AItem: TCardItem; const ARect: TRectF);
var
  LPaint: ISkPaint;
  LFont: ISkFont;
  LImg: ISkImage;
  ImgRect, TagRect, BtnRect: TRectF;
  TextLeft, TextY, RightBoundary: Single;
begin
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  // 1. 卡片白底背景与轻微圆角
  LPaint.Color := TAlphaColors.White;
  LPaint.Style := TSkPaintStyle.Fill;
  ACanvas.DrawRoundRect(TSkRoundRect.Create(ARect, 8, 8), LPaint);

  // 2. 左侧主图区域 (固定 96x108 比例)
  ImgRect := RectF(ARect.Left + 8, ARect.Top + 8, ARect.Left + 104, ARect.Top + 116);

  ACanvas.Save;
  try
    ACanvas.ClipRoundRect(TSkRoundRect.Create(ImgRect, 6, 6), TSkClipOp.Intersect, True);

    // 从 LRU 图片缓存中获取已下载的 Skia 图像
    LImg := TSkImageCache.GetImage(AItem.ImageUrl, procedure
    begin
      Redraw; // 异步下载完成后刷新画板
    end);

    if LImg <> nil then
      ACanvas.DrawImageRect(LImg, ImgRect)
    else
    begin
      LPaint.Color := $FFF0F0F2; // 下载中显示浅灰占位底色
      ACanvas.DrawRect(ImgRect, LPaint);
    end;

    // 左上角角标
    if not AItem.TagTop.IsEmpty then
    begin
      TagRect := RectF(ImgRect.Left, ImgRect.Top, ImgRect.Left + 48, ImgRect.Top + 16);
      LPaint.Color := $EBE6432E; // 补贴红
      ACanvas.DrawRoundRect(TSkRoundRect.Create(TagRect, 2, 2), LPaint);

      LFont := TSkFont.Create(FRegularTypeface, 9);
      LPaint.Color := TAlphaColors.White;
      ACanvas.DrawSimpleText(AItem.TagTop, TagRect.Left + 4, TagRect.Top + 12, LFont, LPaint);
    end;
  finally
    ACanvas.Restore;
  end;

  // 3. 右侧信息排版
  TextLeft := ImgRect.Right + 10;
  RightBoundary := ARect.Right - 8;
  TextY := ARect.Top + 22;

  // 标题前的 "小店好货" 描边微标
  TagRect := RectF(TextLeft, TextY - 11, TextLeft + 44, TextY + 3);
  LPaint.Style := TSkPaintStyle.Stroke;
  LPaint.StrokeWidth := 1;
  LPaint.Color := $FFF3B8AE;
  ACanvas.DrawRoundRect(TSkRoundRect.Create(TagRect, 3, 3), LPaint);
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := $FFE6432E;
  LFont := TSkFont.Create(FBoldTypeface, 9);
  ACanvas.DrawSimpleText('小店好货', TagRect.Left + 3, TagRect.Top + 10.5, LFont, LPaint);

  // 商品标题
  LFont := TSkFont.Create(FBoldTypeface, 13.5);
  LPaint.Color := $FF1A1A1A;
  DrawEllipsisText(ACanvas, AItem.Title, TextLeft + 48, TextY, RightBoundary - (TextLeft + 48), LFont, LPaint);

  // 起止日期
  TextY := TextY + 18;
  LFont := TSkFont.Create(FRegularTypeface, 10.5);
  LPaint.Color := $FF6A6A6E;
  DrawEllipsisText(ACanvas, AItem.Subtitle, TextLeft, TextY, RightBoundary - TextLeft, LFont, LPaint);

  // 保质期 & 路段
  TextY := TextY + 16;
  LPaint.Color := $FFE6432E;
  ACanvas.DrawSimpleText(Format('保质期限：%s    路段：%s', [AItem.ShelfLife, AItem.Road]), TextLeft, TextY, LFont, LPaint);

  // 地址
  TextY := TextY + 16;
  LPaint.Color := $FF9A9A9E;
  DrawEllipsisText(ACanvas, '地址：' + AItem.Address, TextLeft, TextY, RightBoundary - TextLeft, LFont, LPaint);

  // 4. 底部现价、划线原价
  TextY := ARect.Bottom - 14;
  LFont := TSkFont.Create(FBoldTypeface, 16);
  LPaint.Color := $FFE6432E;
  ACanvas.DrawSimpleText(Format('¥%.1f', [AItem.Price]), TextLeft, TextY, LFont, LPaint);

  // 划线原价
  LFont := TSkFont.Create(FRegularTypeface, 10);
  LPaint.Color := $FFB5B5B9;
  ACanvas.DrawSimpleText(Format('¥%.0f', [AItem.OriginalPrice]), TextLeft + 72, TextY - 1, LFont, LPaint);
  LPaint.Style := TSkPaintStyle.Stroke;
  LPaint.StrokeWidth := 1;
  ACanvas.DrawLine(PointF(TextLeft + 72, TextY - 4), PointF(TextLeft + 108, TextY - 4), LPaint);
  LPaint.Style := TSkPaintStyle.Fill;

  // 5. 加入购物车按钮
  BtnRect := RectF(ARect.Right - 76, ARect.Bottom - 34, ARect.Right - 8, ARect.Bottom - 10);
  AItem.LastActionBtnRect := BtnRect;

  LPaint.Color := $FFE6432E;
  ACanvas.DrawRoundRect(TSkRoundRect.Create(BtnRect, 5, 5), LPaint);
  LFont := TSkFont.Create(FBoldTypeface, 10.5);
  LPaint.Color := TAlphaColors.White;
  ACanvas.DrawSimpleText('加入购物车', BtnRect.Left + 8, BtnRect.Top + 16.5, LFont, LPaint);
end;

procedure TSkCardListView.DrawDoubleMerchantCard(const ACanvas: ISkCanvas; AItem: TCardItem; const ARect: TRectF);
var
  LPaint: ISkPaint;
  LFont: ISkFont;
  LImg: ISkImage;
  ImgRect, FootRect: TRectF;
  ImgHeight, TextLeft, TextY: Single;
begin
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  // 1. 卡片圆角白底
  LPaint.Color := TAlphaColors.White;
  LPaint.Style := TSkPaintStyle.Fill;
  ACanvas.DrawRoundRect(TSkRoundRect.Create(ARect, 10, 10), LPaint);

  // 2. 顶部封面图 (4:3 比例)
  ImgHeight := ARect.Width * 0.75;
  ImgRect := RectF(ARect.Left, ARect.Top, ARect.Right, ARect.Top + ImgHeight);

  ACanvas.Save;
  try
    ACanvas.ClipRoundRect(TSkRoundRect.Create(ARect, 10, 10), TSkClipOp.Intersect, True);

    LImg := TSkImageCache.GetImage(AItem.ImageUrl, procedure
    begin
      Redraw;
    end);

    if LImg <> nil then
      ACanvas.DrawImageRect(LImg, ImgRect)
    else
    begin
      LPaint.Color := $FFEAEAEA; // 占位浅灰底色
      ACanvas.DrawRect(ImgRect, LPaint);
    end;
  finally
    ACanvas.Restore;
  end;

  // 3. 商家信息
  TextLeft := ARect.Left + 8;
  TextY := ImgRect.Bottom + 16;

  // 商家名
  LFont := TSkFont.Create(FBoldTypeface, 12.5);
  LPaint.Color := $FF1A1A1A;
  DrawEllipsisText(ACanvas, AItem.Title, TextLeft, TextY, ARect.Width - 16, LFont, LPaint);

  // 路段
  TextY := TextY + 16;
  LFont := TSkFont.Create(FRegularTypeface, 10.5);
  LPaint.Color := $FFE6432E;
  ACanvas.DrawSimpleText('路段：' + AItem.Road, TextLeft, TextY, LFont, LPaint);

  // 地址
  TextY := TextY + 15;
  LFont := TSkFont.Create(FRegularTypeface, 10);
  LPaint.Color := $FF8A8A8E;
  DrawEllipsisText(ACanvas, '地址：' + AItem.Address, TextLeft, TextY, ARect.Width - 16, LFont, LPaint);

  // 4. 底部月售与星级
  FootRect := RectF(TextLeft, ARect.Bottom - 18, ARect.Right - 8, ARect.Bottom - 4);
  LPaint.Color := $FF9A9A9E;
  ACanvas.DrawSimpleText(AItem.SalesVolume, FootRect.Left, FootRect.Top + 10, LFont, LPaint);

  // 星级评分
  DrawStarRating(ACanvas, RectF(FootRect.Right - 80, FootRect.Top, FootRect.Right, FootRect.Bottom), AItem.Rating);
end;

end.
