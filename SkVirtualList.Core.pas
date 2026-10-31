unit SkVirtualList.Core;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Generics.Collections, System.IOUtils, System.Skia, FMX.Skia,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.InertialMovement,
  SkImageCache;

const
  SVG_EMPTY_BOX = 'M20.54 5.23l-1.39-1.68C18.88 3.21 18.47 3 18 3H6c-.47 0-.88.21-1.16.55L3.46 5.23C3.17 5.57 3 6.02 3 6.5V19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6.5c0-.48-.17-.93-.46-1.27zM6.24 5h11.52l.83 1H5.42l.82-1zM5 19V8h14v11H5zm3-7h8v2H8z';

type
  // 共享渲染上下文：跨卡片复用画笔、字体与矢量缓存，实现 120 FPS 绘制零堆内存分配
  TSkRenderContext = class
  private
    FRegularTypeface: ISkTypeface;
    FBoldTypeface: ISkTypeface;

    // 复用画笔对象
    FPaintFill: ISkPaint;
    FPaintStroke: ISkPaint;
    FPaintShadow: ISkPaint;
    FFontRegular: ISkFont;
    FFontBold: ISkFont;

    // SVG 路径解析缓存
    FSvgCache: TDictionary<string, ISkPath>;
    FOnNeedRedraw: TProc;

    procedure InitTypefaces;
  public
    constructor Create;
    destructor Destroy; override;

    // 画笔与字体复用获取器
    function FillPaint(const AColor: TAlphaColor): ISkPaint;
    function StrokePaint(const AColor: TAlphaColor; const AWidth: Single): ISkPaint;
    function Font(const ASize: Single; const ABold: Boolean = False): ISkFont;

    // 字体度量辅助
    function GetCenterBaseline(const AFont: ISkFont; const ARect: TRectF): Single;
    function GetFontHeight(const AFont: ISkFont): Single;

    // 常用高效 UI 绘制原语
    procedure DrawCardBox(const ACanvas: ISkCanvas; const ARect: TRectF;
      const AFillColor: TAlphaColor; const ARadius: Single;
      const AStrokeColor: TAlphaColor = 0; const AStrokeWidth: Single = 0;
      const AHasShadow: Boolean = True);

    procedure DrawFastText(const ACanvas: ISkCanvas; const AText: string;
      const ARect: TRectF; const AFontSize: Single; const AColor: TAlphaColor;
      const ABold: Boolean = False; const ACenterVert: Boolean = True;
      const AStrikethrough: Boolean = False);

    procedure DrawEllipsisText(const ACanvas: ISkCanvas; const AText: string;
      const X, Y, AMaxWidth: Single; const AFontSize: Single;
      const AColor: TAlphaColor; const ABold: Boolean = False);

    procedure DrawSvgPath(const ACanvas: ISkCanvas; const ASvgPathStr: string;
      const ADestRect: TRectF; const AColor: TAlphaColor);

    property OnNeedRedraw: TProc read FOnNeedRedraw write FOnNeedRedraw;
  end;

  // 渲染器策略契约接口：解耦业务外观、几何尺寸、命中测试与滚动引擎
  ISkCardRenderer = interface
    ['{8B4F2A10-5C3E-4D9A-9F1B-2E6D8C7A0E31}']
    function GetSpanCount: Integer; // 列数 (1=单列通栏, 2=双列网格)
    function GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject = nil): Single;
    procedure DrawCard(const ACanvas: ISkCanvas; AContext: TSkRenderContext;
      AItem: TObject; const ARect: TRectF; AIsPressed: Boolean; APressedZoneID: Integer);
    function HitTestCard(AItem: TObject; const ARect: TRectF; const APoint: TPointF): Integer;
    procedure ClearCache;

    // 手势画廊轮播扩展协议
    function CanSwipeImage(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean;
    function CanAutoCruise(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean;
    procedure OnImageSwipe(AItem: TObject; const ADeltaX: Single);
    procedure OnImageSwipeEnd(AItem: TObject; const ADeltaX, AImgWidth: Single);
    function ResolveSwipeTarget(AItem: TObject; const ADeltaX, AImgWidth: Single;
      out ATargetOffset: Single; out AIndexDelta: Integer): Boolean;
    procedure OnImageSwipeFinished(AItem: TObject; const AIndexDelta: Integer);
  end;

const
  ZONE_CARD_MAIN      = 0;
  ZONE_ACTION_BUY     = 1001;
  ZONE_IMAGE_CAROUSEL = 1002;

type
  TTouchMode = (tmNone, tmDeciding, tmVerticalScroll, tmHorizontalSwipe);

  TOnVirtualItemEvent = procedure(Sender: TObject; AIndex: Integer; AItem: TObject; AZoneID: Integer) of object;

  // 轮播图平滑缓动动画单元
  TSnapAnimation = record
    Item: TObject;
    StartOffset: Single;
    TargetOffset: Single;
    IndexDelta: Integer;
    StartTime: UInt64;
    DurationMs: Single;
  end;

  // 虚拟卡片槽位（紧凑值类型记录，100% 连续内存无 GC 抖动）
  TVirtualSlot = record
    Rect: TRectF;
    Renderer: ISkCardRenderer;
  end;

  // 高性能通用虚拟滚动列表引擎
  TSkVirtualListView = class(TSkPaintBox)
  private
    FAniCalculations: TAniCalculations;
    FContext: TSkRenderContext;
    FItems: TObjectList<TObject>;
    FRenderer: ISkCardRenderer;
    FRendererMap: TDictionary<TClass, ISkCardRenderer>;
    FSlots: TArray<TVirtualSlot>;
    FTotalContentHeight: Single;
    FItemSpacing: Single;
    FScrollY: Single; // 滚动偏移量核心权威状态

    // 触控交互与精准命中测试状态
    FIsMouseDown: Boolean;
    FDownPos: TPointF;
    FLastMousePos: TPointF;
    FHasDragged: Boolean;
    FPressedIndex: Integer;
    FPressedZoneID: Integer;
    FTouchMode: TTouchMode;
    FActiveSwipeItem: TObject;
    FSwipeImgWidth: Single;

    // 轮播图平滑缓动动画队列 (支持手势回弹与视口内多卡片独立可控巡航)
    FActiveSnaps: TList<TSnapAnimation>;

    // 1. 回到顶部悬浮自绘按钮与平滑回滚微动画
    FBackToTopAlpha: Single;
    FIsScrollingToTop: Boolean;
    FScrollToTopStart: Single;
    FScrollToTopStartTime: UInt64;
    FScrollToTopDuration: Single;
    FBackToTopPressed: Boolean;

    // 2. 爆款轮播大卡自动巡航状态
    FEnableAutoCruise: Boolean;
    FAutoCruiseIntervalMs: Cardinal;
    FLastUserActionTime: UInt64;
    FLastAutoCruiseTime: UInt64;

    // 上拉加载更多
    FOnLoadMore: TNotifyEvent;
    FIsLoadingMore: Boolean;
    FHasMore: Boolean;

    // 下拉刷新
    FOnRefresh: TNotifyEvent;
    FIsRefreshing: Boolean;
    FEnablePullRefresh: Boolean;

    // 骨架屏与空状态
    FIsLoading: Boolean;
    FEmptyPrompt: string;
    FShimmerPhase: Single;

    FOnItemClick: TOnVirtualItemEvent;

    FAnimationTimer: TTimer;
    procedure HandleAnimationTimer(Sender: TObject);
    procedure StartSnapAnimation(AItem: TObject; const AStartOffset, ATargetOffset: Single;
      const AIndexDelta: Integer; const ADurationMs: Single);
    procedure SetEnableAutoCruise(const AValue: Boolean);
    procedure SetIsLoading(const AValue: Boolean);
    procedure DrawSkeleton(const ACanvas: ISkCanvas);
    procedure DrawEmptyState(const ACanvas: ISkCanvas);
    procedure HandleAniChange(Sender: TObject);
    procedure ScrollByDelta(const ADeltaY: Single);
    function GetTotalContentHeight: Single;
    procedure InternalHitTest(const AScreenPt: TPointF; out AHitIdx, AHitZoneID: Integer);
    procedure CheckLoadMore;
    function GetBackToTopRect: TRectF;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure RegisterRenderer(const AItemClass: TClass; const ARenderer: ISkCardRenderer);
    function GetRendererForItem(AItem: TObject): ISkCardRenderer;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure UpdateLayout;
    procedure Clear;
    procedure ScrollToTop;
    procedure SmoothScrollToTop;
    procedure TriggerEntranceAnimation;
    procedure FinishRefreshing;

    property Context: TSkRenderContext read FContext;
    property Items: TObjectList<TObject> read FItems;
    property Renderer: ISkCardRenderer read FRenderer write FRenderer;
    property ItemSpacing: Single read FItemSpacing write FItemSpacing;
    property OnItemClick: TOnVirtualItemEvent read FOnItemClick write FOnItemClick;
    property OnLoadMore: TNotifyEvent read FOnLoadMore write FOnLoadMore;
    property IsLoadingMore: Boolean read FIsLoadingMore write FIsLoadingMore;
    property HasMore: Boolean read FHasMore write FHasMore;
    property OnRefresh: TNotifyEvent read FOnRefresh write FOnRefresh;
    property IsRefreshing: Boolean read FIsRefreshing;
    property EnablePullRefresh: Boolean read FEnablePullRefresh write FEnablePullRefresh;
    property IsLoading: Boolean read FIsLoading write SetIsLoading;
    property EmptyPrompt: string read FEmptyPrompt write FEmptyPrompt;
    property EnableAutoCruise: Boolean read FEnableAutoCruise write SetEnableAutoCruise;
    property AutoCruiseIntervalMs: Cardinal read FAutoCruiseIntervalMs write FAutoCruiseIntervalMs;
  end;

implementation

{ TSkRenderContext }

constructor TSkRenderContext.Create;
begin
  inherited Create;
  FSvgCache := TDictionary<string, ISkPath>.Create;

  FPaintFill := TSkPaint.Create;
  FPaintFill.AntiAlias := True;
  FPaintFill.Style := TSkPaintStyle.Fill;

  FPaintStroke := TSkPaint.Create;
  FPaintStroke.AntiAlias := True;
  FPaintStroke.Style := TSkPaintStyle.Stroke;

  FPaintShadow := TSkPaint.Create;
  FPaintShadow.AntiAlias := True;
  FPaintShadow.Style := TSkPaintStyle.Fill;
  FPaintShadow.Color := $12000000;
  FPaintShadow.MaskFilter := TSkMaskFilter.MakeBlur(TSkBlurStyle.Normal, 4);

  InitTypefaces;

  FFontRegular := TSkFont.Create(FRegularTypeface, 12);
  FFontBold := TSkFont.Create(FBoldTypeface, 12);
end;

destructor TSkRenderContext.Destroy;
begin
  FSvgCache.Free;
  inherited Destroy;
end;

procedure TSkRenderContext.InitTypefaces;
const
  // 1. Android 官方与各大主流厂商系统自带中文字体路径（优先级从高到低）
  AndroidRegularFonts: array[0..8] of string = (
    '/system/fonts/NotoSansCJK-Regular.ttc',
    '/system/fonts/NotoSansSC-Regular.otf',
    '/system/fonts/NotoSansSC-Regular.ttf',
    '/system/fonts/MiSans-Regular.ttf',
    '/system/fonts/MiSans-Normal.ttf',
    '/system/fonts/HarmonyOS_Sans_SC.ttf',
    '/system/fonts/OPlusSans-Regular.ttf',
    '/system/fonts/SourceHanSansCN-Regular.otf',
    '/system/fonts/DroidSansFallback.ttf'
  );
  AndroidBoldFonts: array[0..6] of string = (
    '/system/fonts/NotoSansCJK-Bold.ttc',
    '/system/fonts/NotoSansSC-Bold.otf',
    '/system/fonts/NotoSansSC-Bold.ttf',
    '/system/fonts/MiSans-Bold.ttf',
    '/system/fonts/HarmonyOS_Sans_SC_Bold.ttf',
    '/system/fonts/OPlusSans-Bold.ttf',
    '/system/fonts/SourceHanSansCN-Bold.otf'
  );
  // 2. 桌面平台（Windows / macOS）字体族候选名
  DesktopCandidates: array[0..4] of string = (
    'Microsoft YaHei', 'PingFang SC', 'Source Han Sans CN',
    'Noto Sans CJK SC', 'SimHei'
  );
var
  FontName, LowerName: string;
  {$IFDEF ANDROID}
  FontPath: string;
  {$ENDIF}
  Tf: ISkTypeface;
begin
  FRegularTypeface := nil;
  FBoldTypeface := nil;

  {$IFDEF ANDROID}
  // 在 Android 上优先从系统字体目录直接挂载真实中文字库
  for FontPath in AndroidRegularFonts do
  begin
    if TFile.Exists(FontPath) then
    begin
      FRegularTypeface := TSkTypeface.MakeFromFile(FontPath);
      if FRegularTypeface <> nil then Break;
    end;
  end;

  for FontPath in AndroidBoldFonts do
  begin
    if TFile.Exists(FontPath) then
    begin
      FBoldTypeface := TSkTypeface.MakeFromFile(FontPath);
      if FBoldTypeface <> nil then Break;
    end;
  end;

  // 若未找到独立粗体字库，复用常规字体
  if (FBoldTypeface = nil) and (FRegularTypeface <> nil) then
    FBoldTypeface := FRegularTypeface;

  // 深度扫描兜底：若前序未命中，遍历 /system/fonts 寻找包含中文字征的文件
  if (FRegularTypeface = nil) and TDirectory.Exists('/system/fonts') then
  begin
    for FontPath in TDirectory.GetFiles('/system/fonts') do
    begin
      LowerName := ExtractFileName(FontPath).ToLower;
      if LowerName.Contains('cjk') or LowerName.Contains('hans') or
         LowerName.Contains('sc') or LowerName.Contains('chinese') or
         LowerName.Contains('fallback') or LowerName.Contains('misans') or
         LowerName.Contains('harmony') or LowerName.Contains('oplus') then
      begin
        FRegularTypeface := TSkTypeface.MakeFromFile(FontPath);
        if FRegularTypeface <> nil then
        begin
          FBoldTypeface := FRegularTypeface;
          Break;
        end;
      end;
    end;
  end;
  {$ENDIF}

  // Windows / macOS / iOS 桌面候选，或 Android 降级策略
  if FRegularTypeface = nil then
  begin
    for FontName in DesktopCandidates do
    begin
      Tf := TSkTypeface.MakeFromName(FontName, TSkFontStyle.Normal);
      if Tf <> nil then
      begin
        LowerName := Tf.FamilyName.ToLower;
        // 严格校验 FamilyName 是否真的匹配目标中文字体，防止被系统 Fallback（如 Roboto）假命中
        if LowerName.Contains('yahei') or LowerName.Contains('pingfang') or
           LowerName.Contains('simhei') or LowerName.Contains('cjk') or
           LowerName.Contains('han') then
        begin
          FRegularTypeface := Tf;
          FBoldTypeface := TSkTypeface.MakeFromName(FontName, TSkFontStyle.Bold);
          Break;
        end;
      end;
    end;
  end;

  if FRegularTypeface = nil then
    FRegularTypeface := TSkTypeface.MakeDefault;
  if FBoldTypeface = nil then
    FBoldTypeface := FRegularTypeface;
end;

function TSkRenderContext.FillPaint(const AColor: TAlphaColor): ISkPaint;
begin
  FPaintFill.Color := AColor;
  Result := FPaintFill;
end;

function TSkRenderContext.StrokePaint(const AColor: TAlphaColor; const AWidth: Single): ISkPaint;
begin
  FPaintStroke.Color := AColor;
  FPaintStroke.StrokeWidth := AWidth;
  Result := FPaintStroke;
end;

function TSkRenderContext.Font(const ASize: Single; const ABold: Boolean): ISkFont;
begin
  if ABold then
  begin
    FFontBold.Size := ASize;
    Result := FFontBold;
  end
  else
  begin
    FFontRegular.Size := ASize;
    Result := FFontRegular;
  end;
end;

function TSkRenderContext.GetCenterBaseline(const AFont: ISkFont; const ARect: TRectF): Single;
var
  M: TSkFontMetrics;
begin
  AFont.GetMetrics(M);
  Result := ARect.CenterPoint.Y - (M.Ascent + M.Descent) / 2;
end;

function TSkRenderContext.GetFontHeight(const AFont: ISkFont): Single;
var
  M: TSkFontMetrics;
begin
  AFont.GetMetrics(M);
  Result := M.Descent - M.Ascent;
end;

procedure TSkRenderContext.DrawCardBox(const ACanvas: ISkCanvas; const ARect: TRectF;
  const AFillColor: TAlphaColor; const ARadius: Single;
  const AStrokeColor: TAlphaColor; const AStrokeWidth: Single;
  const AHasShadow: Boolean);
var
  RRect: TSkRoundRect;
  ShadowRect: TRectF;
begin
  if AHasShadow then
  begin
    ShadowRect := ARect;
    ShadowRect.Offset(0, 2);
    ACanvas.DrawRoundRect(TSkRoundRect.Create(ShadowRect, ARadius, ARadius), FPaintShadow);
  end;

  RRect := TSkRoundRect.Create(ARect, ARadius, ARadius);
  ACanvas.DrawRoundRect(RRect, FillPaint(AFillColor));

  if (AStrokeColor <> 0) and (AStrokeWidth > 0) then
    ACanvas.DrawRoundRect(RRect, StrokePaint(AStrokeColor, AStrokeWidth));
end;

procedure TSkRenderContext.DrawFastText(const ACanvas: ISkCanvas; const AText: string;
  const ARect: TRectF; const AFontSize: Single; const AColor: TAlphaColor;
  const ABold: Boolean; const ACenterVert: Boolean; const AStrikethrough: Boolean);
var
  LFont: ISkFont;
  LPaint: ISkPaint;
  BaselineY: Single;
  TextW: Single;
  M: TSkFontMetrics;
  StrikeY: Single;
begin
  if AText.IsEmpty then Exit;

  LFont := Font(AFontSize, ABold);
  LPaint := FillPaint(AColor);
  LFont.GetMetrics(M);

  if ACenterVert then
    BaselineY := ARect.CenterPoint.Y - (M.Ascent + M.Descent) / 2
  else
    BaselineY := ARect.Top - M.Ascent;

  ACanvas.DrawSimpleText(AText, ARect.Left, BaselineY, LFont, LPaint);

  if AStrikethrough then
  begin
    TextW := LFont.MeasureText(AText);
    StrikeY := BaselineY + (M.Ascent * 0.35);
    ACanvas.DrawLine(PointF(ARect.Left, StrikeY), PointF(ARect.Left + TextW, StrikeY),
      StrokePaint(AColor, 1.0));
  end;
end;

procedure TSkRenderContext.DrawEllipsisText(const ACanvas: ISkCanvas; const AText: string;
  const X, Y, AMaxWidth: Single; const AFontSize: Single;
  const AColor: TAlphaColor; const ABold: Boolean);
var
  LFont: ISkFont;
  LPaint: ISkPaint;
  Ellipsis: string;
  EllipsisW: Single;
  AvailableW: Single;
  LowIdx, HighIdx, MidIdx, BestIdx: Integer;
  SubStr: string;
begin
  if AText.IsEmpty or (AMaxWidth <= 0) then Exit;

  LFont := Font(AFontSize, ABold);
  LPaint := FillPaint(AColor);

  if LFont.MeasureText(AText) <= AMaxWidth then
  begin
    ACanvas.DrawSimpleText(AText, X, Y, LFont, LPaint);
    Exit;
  end;

  Ellipsis := '...';
  EllipsisW := LFont.MeasureText(Ellipsis);
  AvailableW := AMaxWidth - EllipsisW;
  if AvailableW <= 0 then Exit;

  LowIdx := 1;
  HighIdx := Length(AText);
  BestIdx := 1;

  while LowIdx <= HighIdx do
  begin
    MidIdx := (LowIdx + HighIdx) div 2;
    SubStr := Copy(AText, 1, MidIdx);
    if LFont.MeasureText(SubStr) <= AvailableW then
    begin
      BestIdx := MidIdx;
      LowIdx := MidIdx + 1;
    end
    else
      HighIdx := MidIdx - 1;
  end;

  ACanvas.DrawSimpleText(Copy(AText, 1, BestIdx) + Ellipsis, X, Y, LFont, LPaint);
end;

procedure TSkRenderContext.DrawSvgPath(const ACanvas: ISkCanvas; const ASvgPathStr: string;
  const ADestRect: TRectF; const AColor: TAlphaColor);
var
  LPath: ISkPath;
  ScaleX, ScaleY: Single;
  Bounds: TRectF;
begin
  if ASvgPathStr.IsEmpty or (ADestRect.Width <= 0) or (ADestRect.Height <= 0) then Exit;

  if not FSvgCache.TryGetValue(ASvgPathStr, LPath) then
  begin
    try
      LPath := TSkPath.Create(ASvgPathStr);
      if LPath <> nil then
        FSvgCache.Add(ASvgPathStr, LPath);
    except
      LPath := nil;
    end;
  end;

  if LPath = nil then Exit;

  Bounds := LPath.Bounds;
  if (Bounds.Width <= 0) or (Bounds.Height <= 0) then Exit;

  ScaleX := ADestRect.Width / Bounds.Width;
  ScaleY := ADestRect.Height / Bounds.Height;

  ACanvas.Save;
  try
    ACanvas.Translate(ADestRect.Left - Bounds.Left * ScaleX,
                      ADestRect.Top - Bounds.Top * ScaleY);
    ACanvas.Scale(ScaleX, ScaleY);
    ACanvas.DrawPath(LPath, FillPaint(AColor));
  finally
    ACanvas.Restore;
  end;
end;

{ TSkVirtualListView }

constructor TSkVirtualListView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  HitTest := True;
  CanFocus := True;
  AutoCapture := True;

  FContext := TSkRenderContext.Create;
  FContext.OnNeedRedraw := procedure
  begin
    Redraw;
  end;
  FItems := TObjectList<TObject>.Create(True);
  FRendererMap := TDictionary<TClass, ISkCardRenderer>.Create;
  FItemSpacing := 8;
  FScrollY := 0;
  FPressedIndex := -1;
  FPressedZoneID := -1;
  FTouchMode := tmNone;
  FActiveSwipeItem := nil;
  FSwipeImgWidth := 0;

  FIsLoadingMore := False;
  FHasMore := True;
  FIsRefreshing := False;
  FEnablePullRefresh := True;
  FIsLoading := False;
  FEmptyPrompt := '暂无相关数据';
  FShimmerPhase := 0;
  FActiveSnaps := TList<TSnapAnimation>.Create;
  FTotalContentHeight := 0;

  FBackToTopAlpha := 0;
  FIsScrollingToTop := False;
  FBackToTopPressed := False;
  FEnableAutoCruise := True;
  FAutoCruiseIntervalMs := 3500;
  FLastUserActionTime := TThread.GetTickCount64;
  FLastAutoCruiseTime := TThread.GetTickCount64;

  FAniCalculations := TAniCalculations.Create(nil);
  FAniCalculations.Animation := True;
  FAniCalculations.Averaging := True;
  FAniCalculations.TouchTracking := [ttVertical];
  FAniCalculations.OnChanged := HandleAniChange;

  FAnimationTimer := TTimer.Create(Self);
  FAnimationTimer.Interval := 20; // 50 FPS 现代动画高精度驱动心跳
  FAnimationTimer.OnTimer := HandleAnimationTimer;
  FAnimationTimer.Enabled := True;
end;

destructor TSkVirtualListView.Destroy;
begin
  FAnimationTimer.Free;
  FActiveSnaps.Free;
  TSkImageCache.Unsubscribe(Self);
  FAniCalculations.Free;
  FItems.Free;
  FRendererMap.Free;
  FContext.Free;
  inherited Destroy;
end;

procedure TSkVirtualListView.SetEnableAutoCruise(const AValue: Boolean);
begin
  if FEnableAutoCruise <> AValue then
  begin
    FEnableAutoCruise := AValue;
    FLastAutoCruiseTime := TThread.GetTickCount64;
  end;
end;

procedure TSkVirtualListView.StartSnapAnimation(AItem: TObject; const AStartOffset, ATargetOffset: Single;
  const AIndexDelta: Integer; const ADurationMs: Single);
var
  I: Integer;
  Anim: TSnapAnimation;
begin
  if AItem = nil then Exit;
  for I := 0 to FActiveSnaps.Count - 1 do
  begin
    if FActiveSnaps[I].Item = AItem then
    begin
      Anim := FActiveSnaps[I];
      Anim.StartOffset := AStartOffset;
      Anim.TargetOffset := ATargetOffset;
      Anim.IndexDelta := AIndexDelta;
      Anim.StartTime := TThread.GetTickCount64;
      Anim.DurationMs := ADurationMs;
      FActiveSnaps[I] := Anim;
      Exit;
    end;
  end;

  Anim.Item := AItem;
  Anim.StartOffset := AStartOffset;
  Anim.TargetOffset := ATargetOffset;
  Anim.IndexDelta := AIndexDelta;
  Anim.StartTime := TThread.GetTickCount64;
  Anim.DurationMs := ADurationMs;
  FActiveSnaps.Add(Anim);
end;

procedure TSkVirtualListView.HandleAnimationTimer(Sender: TObject);
var
  NowTick, SnapElapsed, ScrollElapsed: UInt64;
  CruiseRenderer, ItemRenderer: ISkCardRenderer;
  CruiseImgW, AutoTargetOffset, SnapProgress, SnapEaseT, SnapCurOffset: Single;
  AutoIndexDelta, I: Integer;
  SnapAnim: TSnapAnimation;
  HasTriggered: Boolean;
  CruiseItem: TObject;
  ScrollProgress, ScrollEaseT: Single;
begin
  NowTick := TThread.GetTickCount64;

  // 1. 若当前处于回到顶部平滑回滚动画中，由 20ms 定时器独立高频推进 (260ms Cubic-Ease-Out)
  if FIsScrollingToTop then
  begin
    ScrollElapsed := NowTick - FScrollToTopStartTime;
    ScrollProgress := Min(1.0, ScrollElapsed / FScrollToTopDuration);
    ScrollEaseT := 1.0 - Power(1.0 - ScrollProgress, 3);
    FScrollY := FScrollToTopStart * (1.0 - ScrollEaseT);
    FAniCalculations.ViewportPosition := TPointD.Create(0, FScrollY);
    if ScrollProgress >= 1.0 then
    begin
      FIsScrollingToTop := False;
      FScrollY := 0;
      FAniCalculations.ViewportPosition := TPointD.Create(0, 0);
    end;
    Redraw;
    Exit;
  end;

  if FIsMouseDown then Exit;
  if (Length(FSlots) = 0) or (FItems.Count = 0) then Exit;

  // 2. 若当前存在轮播图平滑缓动动画，由 20ms 定时器逐帧推进各 Item
  if FActiveSnaps.Count > 0 then
  begin
    for I := FActiveSnaps.Count - 1 downto 0 do
    begin
      SnapAnim := FActiveSnaps[I];
      ItemRenderer := GetRendererForItem(SnapAnim.Item);
      SnapElapsed := NowTick - SnapAnim.StartTime;
      SnapProgress := Min(1.0, SnapElapsed / SnapAnim.DurationMs);
      SnapEaseT := 1.0 - Power(1.0 - SnapProgress, 3);
      SnapCurOffset := SnapAnim.StartOffset + (SnapAnim.TargetOffset - SnapAnim.StartOffset) * SnapEaseT;

      if ItemRenderer <> nil then
        ItemRenderer.OnImageSwipe(SnapAnim.Item, SnapCurOffset);

      if SnapProgress >= 1.0 then
      begin
        if ItemRenderer <> nil then
          ItemRenderer.OnImageSwipeFinished(SnapAnim.Item, SnapAnim.IndexDelta);
        FActiveSnaps.Delete(I);
      end;
    end;
    Redraw;
    Exit;
  end;

  // 3. 检查是否触发下一次自动巡航（仅在 FEnableAutoCruise 开启时生效：静止保护 3 秒 + 巡航周期 3.5 秒）
  if FEnableAutoCruise and (NowTick - FLastUserActionTime >= 3000) and (NowTick - FLastAutoCruiseTime >= FAutoCruiseIntervalMs) then
  begin
    HasTriggered := False;
    // 遍历当前落在屏幕可视区域内的所有 Item，分别检测各个 Item 的巡航许可
    for I := 0 to Min(High(FSlots), FItems.Count - 1) do
    begin
      if (FSlots[I].Rect.Bottom > FScrollY) and (FSlots[I].Rect.Top < FScrollY + Height) then
      begin
        CruiseItem := FItems[I];
        CruiseRenderer := GetRendererForItem(CruiseItem);
        // 精确判定：仅在当前 Item 明确开启了巡航开关（AutoCruise = True）时触发滑切
        if (CruiseRenderer <> nil) and CruiseRenderer.CanAutoCruise(CruiseItem, ZONE_IMAGE_CAROUSEL, CruiseImgW) then
        begin
          if CruiseRenderer.ResolveSwipeTarget(CruiseItem, -CruiseImgW * 0.35, CruiseImgW, AutoTargetOffset, AutoIndexDelta) then
          begin
            StartSnapAnimation(CruiseItem, 0, AutoTargetOffset, AutoIndexDelta, 240.0);
            HasTriggered := True;
          end;
        end;
      end;
    end;

    if HasTriggered then
    begin
      FLastAutoCruiseTime := NowTick;
      Redraw;
    end;
  end;
end;

function TSkVirtualListView.GetBackToTopRect: TRectF;
begin
  // 右下角悬浮按钮（直径 38px，右边距 14px，底边距 18px）
  Result := RectF(Width - 52, Height - 56, Width - 14, Height - 18);
end;

procedure TSkVirtualListView.SmoothScrollToTop;
begin
  if FScrollY <= 1 then Exit;
  FIsScrollingToTop := True;
  FScrollToTopStart := FScrollY;
  FScrollToTopStartTime := TThread.GetTickCount64;
  FScrollToTopDuration := 260.0;
  FBackToTopAlpha := 0.0; // 点击回到顶部后，悬浮按钮立即隐藏，不残留
  FBackToTopPressed := False;
  Redraw;
end;

procedure TSkVirtualListView.TriggerEntranceAnimation;
begin
  Redraw;
end;

procedure TSkVirtualListView.RegisterRenderer(const AItemClass: TClass; const ARenderer: ISkCardRenderer);
begin
  FRendererMap.AddOrSetValue(AItemClass, ARenderer);
end;

function TSkVirtualListView.GetRendererForItem(AItem: TObject): ISkCardRenderer;
var
  Pair: TPair<TClass, ISkCardRenderer>;
begin
  Result := nil;
  if AItem = nil then Exit;

  // 优先匹配已注册的类或其派生类
  for Pair in FRendererMap do
  begin
    if AItem.InheritsFrom(Pair.Key) then
      Exit(Pair.Value);
  end;

  // 回退至全局默认渲染器
  Result := FRenderer;
end;

function TSkVirtualListView.GetTotalContentHeight: Single;
begin
  Result := FTotalContentHeight;
end;

procedure TSkVirtualListView.CheckLoadMore;
var
  TotalH: Single;
begin
  if (not FIsLoadingMore) and FHasMore and Assigned(FOnLoadMore) then
  begin
    TotalH := GetTotalContentHeight;
    if (TotalH > Height) and ((FScrollY + Height) >= (TotalH - 80)) then
    begin
      FIsLoadingMore := True;
      FOnLoadMore(Self);
      Redraw;
    end;
  end;
end;

procedure TSkVirtualListView.HandleAniChange(Sender: TObject);
var
  MinY, MaxY: Single;
begin
  if FIsRefreshing then
    MinY := -60
  else if FEnablePullRefresh then
    MinY := -100
  else
    MinY := 0;

  MaxY := Max(0, GetTotalContentHeight - Height);
  FScrollY := EnsureRange(FAniCalculations.ViewportPosition.Y, MinY, MaxY);
  FLastUserActionTime := TThread.GetTickCount64;
  CheckLoadMore;
  Redraw;
end;

procedure TSkVirtualListView.ScrollByDelta(const ADeltaY: Single);
var
  MinY, MaxY: Single;
begin
  if FIsRefreshing then
    MinY := -60
  else if FEnablePullRefresh then
    MinY := -100
  else
    MinY := 0;

  MaxY := Max(0, GetTotalContentHeight - Height);
  FScrollY := EnsureRange(FScrollY + ADeltaY, MinY, MaxY);
  FAniCalculations.ViewportPosition := TPointD.Create(0, FScrollY);
  CheckLoadMore;
  Redraw;
end;

procedure TSkVirtualListView.ScrollToTop;
begin
  FScrollY := 0;
  FAniCalculations.ViewportPosition := TPointD.Create(0, 0);
  Redraw;
end;

procedure TSkVirtualListView.Clear;
var
  Pair: TPair<TClass, ISkCardRenderer>;
begin
  FActiveSnaps.Clear;
  FItems.Clear;
  if FRenderer <> nil then
    FRenderer.ClearCache;
  for Pair in FRendererMap do
    Pair.Value.ClearCache;
  UpdateLayout;
end;

procedure TSkVirtualListView.FinishRefreshing;
var
  Targets: array[0..1] of TAniCalculations.TTarget;
begin
  if not FIsRefreshing then Exit;
  FIsRefreshing := False;
  Targets[0].TargetType := TAniCalculations.TTargetType.Min;
  Targets[0].Point := TPointD.Create(0, 0);
  Targets[1].TargetType := TAniCalculations.TTargetType.Max;
  Targets[1].Point := TPointD.Create(0, Max(0, GetTotalContentHeight - Height));
  FAniCalculations.SetTargets(Targets);
  FAniCalculations.ViewportPosition := TPointD.Create(0, 0);
  FScrollY := 0;
  Redraw;
end;

procedure TSkVirtualListView.UpdateLayout;
var
  I, SpanCount: Integer;
  ColWidth, ItemH, CurY: Single;
  ColX: array of Single;
  ColBottomY: array of Single;
  CurCol, C: Integer;
  TotalCols: Integer;
  ItemRenderer: ISkCardRenderer;
  Targets: array[0..1] of TAniCalculations.TTarget;
begin
  SetLength(FSlots, FItems.Count);
  if FItems.Count = 0 then
  begin
    FTotalContentHeight := 0;
    Targets[0].TargetType := TAniCalculations.TTargetType.Min;
    Targets[0].Point := TPointD.Create(0, 0);
    Targets[1].TargetType := TAniCalculations.TTargetType.Max;
    Targets[1].Point := TPointD.Create(0, 0);
    FAniCalculations.SetTargets(Targets);
    Redraw;
    Exit;
  end;

  // 1. 基准列宽与多列定位计算（以 2 列作为网格基准分栏）
  TotalCols := 2;
  SetLength(ColX, TotalCols);
  SetLength(ColBottomY, TotalCols);
  ColWidth := Max(10, (Width - (FItemSpacing * (TotalCols + 1))) / TotalCols);
  for C := 0 to TotalCols - 1 do
  begin
    ColX[C] := FItemSpacing + C * (ColWidth + FItemSpacing);
    ColBottomY[C] := FItemSpacing;
  end;

  for I := 0 to FItems.Count - 1 do
  begin
    ItemRenderer := GetRendererForItem(FItems[I]);
    FSlots[I].Renderer := ItemRenderer;

    if ItemRenderer = nil then
    begin
      FSlots[I].Rect := TRectF.Empty;
      Continue;
    end;

    SpanCount := ItemRenderer.GetSpanCount;
    if SpanCount <= 1 then
    begin
      // --- 单列全宽项 (SpanCount = 1) ---
      // 对齐到两列当前最大 Y
      CurY := Max(ColBottomY[0], ColBottomY[1]);

      ItemH := ItemRenderer.GetItemHeight(FContext, Width - (FItemSpacing * 2), FItems[I]);
      FSlots[I].Rect := RectF(FItemSpacing, CurY, Width - FItemSpacing, CurY + ItemH);
      CurY := CurY + ItemH + FItemSpacing;

      // 统一拉齐多列底线
      ColBottomY[0] := CurY;
      ColBottomY[1] := CurY;
    end
    else
    begin
      // --- 双列网格瀑布流 (SpanCount >= 2) - 贪心选取当前最短列 ---
      if ColBottomY[0] <= ColBottomY[1] then
        CurCol := 0
      else
        CurCol := 1;

      ItemH := ItemRenderer.GetItemHeight(FContext, ColWidth, FItems[I]);
      FSlots[I].Rect := RectF(ColX[CurCol], ColBottomY[CurCol], ColX[CurCol] + ColWidth, ColBottomY[CurCol] + ItemH);
      ColBottomY[CurCol] := ColBottomY[CurCol] + ItemH + FItemSpacing;
    end;
  end;

  // 2. 精确计算总体内容高度
  FTotalContentHeight := Max(ColBottomY[0], ColBottomY[1]);
  if FIsLoadingMore then
    FTotalContentHeight := FTotalContentHeight + 38;

  // 3. 更新惯性滚动 Targets 边界
  Targets[0].TargetType := TAniCalculations.TTargetType.Min;
  Targets[0].Point := TPointD.Create(0, 0);
  Targets[1].TargetType := TAniCalculations.TTargetType.Max;
  Targets[1].Point := TPointD.Create(0, Max(0, FTotalContentHeight - Height));
  FAniCalculations.SetTargets(Targets);
  Redraw;
end;

procedure TSkVirtualListView.Resize;
begin
  inherited Resize;
  UpdateLayout;
end;

procedure TSkVirtualListView.InternalHitTest(const AScreenPt: TPointF; out AHitIdx, AHitZoneID: Integer);
var
  I: Integer;
  AbsPt: TPointF;
  CardRect: TRectF;
begin
  AHitIdx := -1;
  AHitZoneID := 0;
  if (Length(FSlots) = 0) or (FItems.Count = 0) then Exit;

  AbsPt := PointF(AScreenPt.X, AScreenPt.Y + FScrollY);

  for I := 0 to High(FSlots) do
  begin
    if FSlots[I].Rect.Bottom < FScrollY then Continue;
    // 增加 300px 安全冗余缓冲，防止双列不等高瀑布流中某列项因微小交错而被提前 Break 误杀
    if FSlots[I].Rect.Top > (FScrollY + Height + 300) then Break;

    if FSlots[I].Rect.Contains(AbsPt) then
    begin
      AHitIdx := I;
      CardRect := RectF(
        FSlots[I].Rect.Left,
        FSlots[I].Rect.Top - FScrollY,
        FSlots[I].Rect.Right,
        FSlots[I].Rect.Bottom - FScrollY
      );
      if FSlots[I].Renderer <> nil then
        AHitZoneID := FSlots[I].Renderer.HitTestCard(FItems[I], CardRect, AScreenPt)
      else
        AHitZoneID := 0;
      Break;
    end;
  end;
end;

procedure TSkVirtualListView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  HitIdx, HitZoneID: Integer;
  ItemRenderer: ISkCardRenderer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = TMouseButton.mbLeft then
  begin
    // 1. 优先拦截点击回到顶部悬浮按钮 (只要滚动超过 180px 且在按钮区域内，100% 立即响应)
    if (FScrollY > 180) and GetBackToTopRect.Contains(PointF(X, Y)) then
    begin
      if CanFocus then SetFocus;
      FBackToTopPressed := True;
      Capture;
      Redraw;
      Exit;
    end;

    if CanFocus then SetFocus;
    FIsMouseDown := True;
    FDownPos := PointF(X, Y);
    FLastMousePos := FDownPos;
    FHasDragged := False;
    FTouchMode := tmDeciding;
    FActiveSwipeItem := nil;
    FSwipeImgWidth := 0;
    FIsScrollingToTop := False;
    FLastUserActionTime := TThread.GetTickCount64;
    Capture;

    InternalHitTest(FDownPos, HitIdx, HitZoneID);
    FPressedIndex := HitIdx;
    FPressedZoneID := HitZoneID;

    // 探测当前卡片是否支持图片手势轮播
    if (HitIdx >= 0) and (HitIdx < FItems.Count) then
    begin
      ItemRenderer := GetRendererForItem(FItems[HitIdx]);
      if (ItemRenderer <> nil) and ItemRenderer.CanSwipeImage(FItems[HitIdx], HitZoneID, FSwipeImgWidth) then
        FActiveSwipeItem := FItems[HitIdx];
    end;

    // 桥接惯性动力学计算引擎
    FAniCalculations.MouseDown(X, Y);
  end;
end;

procedure TSkVirtualListView.MouseMove(Shift: TShiftState; X, Y: Single);
var
  CurPos: TPointF;
  DeltaX, DeltaY: Single;
  ItemRenderer: ISkCardRenderer;
begin
  inherited MouseMove(Shift, X, Y);
  if FBackToTopPressed then
  begin
    Redraw;
    Exit;
  end;
  if not FIsMouseDown then Exit;

  FLastUserActionTime := TThread.GetTickCount64;
  CurPos := PointF(X, Y);

  // 处于仲裁阶段且移动超过 6px 阈值：进行 45° 向量裁决
  if (FTouchMode = tmDeciding) and (CurPos.Distance(FDownPos) > 6) then
  begin
    FHasDragged := True;
    FPressedIndex := -1;
    FPressedZoneID := -1;

    DeltaX := CurPos.X - FDownPos.X;
    DeltaY := CurPos.Y - FDownPos.Y;

    if (FActiveSwipeItem <> nil) and (Abs(DeltaX) > Abs(DeltaY)) then
      FTouchMode := tmHorizontalSwipe
    else
      FTouchMode := tmVerticalScroll;
  end;

  case FTouchMode of
    tmVerticalScroll:
      begin
        DeltaY := CurPos.Y - FLastMousePos.Y;
        if Abs(DeltaY) > 0.1 then
        begin
          ScrollByDelta(-DeltaY);
          FLastMousePos := CurPos;
        end;
        FAniCalculations.MouseMove(X, Y);
      end;

    tmHorizontalSwipe:
      begin
        if FActiveSwipeItem <> nil then
        begin
          ItemRenderer := GetRendererForItem(FActiveSwipeItem);
          if ItemRenderer <> nil then
          begin
            ItemRenderer.OnImageSwipe(FActiveSwipeItem, CurPos.X - FDownPos.X);
            Redraw;
          end;
        end;
      end;
  end;
end;

procedure TSkVirtualListView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  HitIdx, HitZoneID, NextIndexDelta: Integer;
  DeltaX, TargetOffset: Single;
  ItemRenderer: ISkCardRenderer;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = TMouseButton.mbLeft then
  begin
    ReleaseCapture;
    if FBackToTopPressed then
    begin
      FBackToTopPressed := False;
      if GetBackToTopRect.Contains(PointF(X, Y)) then
        SmoothScrollToTop;
      Redraw;
      Exit;
    end;

    FIsMouseDown := False;
    FLastUserActionTime := TThread.GetTickCount64;

    if (FTouchMode = tmHorizontalSwipe) and (FActiveSwipeItem <> nil) then
    begin
      DeltaX := PointF(X, Y).X - FDownPos.X;
      ItemRenderer := GetRendererForItem(FActiveSwipeItem);
      if (ItemRenderer <> nil) and ItemRenderer.ResolveSwipeTarget(FActiveSwipeItem, DeltaX, FSwipeImgWidth, TargetOffset, NextIndexDelta) then
      begin
        StartSnapAnimation(FActiveSwipeItem, DeltaX, TargetOffset, NextIndexDelta, 160.0);
      end
      else if ItemRenderer <> nil then
        ItemRenderer.OnImageSwipeEnd(FActiveSwipeItem, DeltaX, FSwipeImgWidth);

      FActiveSwipeItem := nil;
      Redraw;
    end
    else
    begin
      // 触发纵向惯性物理甩动
      FAniCalculations.MouseUp(X, Y);

      // 下拉刷新判定：若下拉超过 50px 且松手
      if FEnablePullRefresh and (not FIsRefreshing) and Assigned(FOnRefresh) and (FScrollY <= -50) then
      begin
        FIsRefreshing := True;
        FScrollY := -60;
        FAniCalculations.ViewportPosition := TPointD.Create(0, -60);
        FOnRefresh(Self);
      end
      else if not FHasDragged then
      begin
        InternalHitTest(PointF(X, Y), HitIdx, HitZoneID);
        if (HitIdx >= 0) and Assigned(FOnItemClick) then
          FOnItemClick(Self, HitIdx, FItems[HitIdx], HitZoneID);
      end;
    end;

    FTouchMode := tmNone;
    FPressedIndex := -1;
    FPressedZoneID := -1;
    Redraw;
  end;
end;

procedure TSkVirtualListView.SetIsLoading(const AValue: Boolean);
begin
  if FIsLoading <> AValue then
  begin
    FIsLoading := AValue;
    FShimmerPhase := 0;
    Redraw;
  end;
end;

procedure TSkVirtualListView.DrawSkeleton(const ACanvas: ISkCanvas);
var
  SpanCount, R, C: Integer;
  ColWidth, CardHeight: Single;
  CardRect: TRectF;
  ShimmerColor: TAlphaColor;
  ShimmerPaint: ISkPaint;
  CRec: TAlphaColorRec;
  GrayVal: Integer;
begin
  SpanCount := 1;
  if FRenderer <> nil then
    SpanCount := Max(1, FRenderer.GetSpanCount);

  CRec.A := $FF;

  if SpanCount = 1 then
  begin
    ColWidth := Max(10, Width - (FItemSpacing * 2));
    CardHeight := 142;
    if FRenderer <> nil then
      CardHeight := FRenderer.GetItemHeight(FContext, ColWidth);

    for R := 0 to 4 do
    begin
      CardRect := RectF(
        FItemSpacing,
        FItemSpacing + R * (CardHeight + FItemSpacing) - FScrollY,
        FItemSpacing + ColWidth,
        FItemSpacing + R * (CardHeight + FItemSpacing) + CardHeight - FScrollY
      );
      if (CardRect.Bottom < 0) or (CardRect.Top > Height) then Continue;

      // 1. 骨架白色底卡片
      FContext.DrawCardBox(ACanvas, CardRect, TAlphaColors.White, 8, 0, 0, True);

      // 2. 呼吸流光颜色计算 (230 ~ 246 之间平滑正弦波动)
      GrayVal := EnsureRange(Round(236 + 10 * Sin(FShimmerPhase * Pi + R * 0.4)), 0, 255);
      CRec.R := GrayVal;
      CRec.G := GrayVal;
      CRec.B := GrayVal;
      ShimmerColor := CRec.Color;
      ShimmerPaint := FContext.FillPaint(ShimmerColor);

      // 3. 左侧封面图占位块
      ACanvas.DrawRoundRect(TSkRoundRect.Create(
        RectF(CardRect.Left + 8, CardRect.Top + 8, CardRect.Left + 104, CardRect.Top + 122), 6, 6),
        ShimmerPaint);

      // 4. 右侧标题长条占位
      ACanvas.DrawRoundRect(TSkRoundRect.Create(
        RectF(CardRect.Left + 114, CardRect.Top + 12, CardRect.Right - 36, CardRect.Top + 28), 4, 4),
        ShimmerPaint);

      // 5. 右侧副标题占位条
      ACanvas.DrawRoundRect(TSkRoundRect.Create(
        RectF(CardRect.Left + 114, CardRect.Top + 36, CardRect.Right - 90, CardRect.Top + 48), 4, 4),
        ShimmerPaint);

      // 6. 右侧标签占位条
      ACanvas.DrawRoundRect(TSkRoundRect.Create(
        RectF(CardRect.Left + 114, CardRect.Top + 58, CardRect.Left + 176, CardRect.Top + 70), 3, 3),
        ShimmerPaint);

      // 7. 底部价格占位条
      ACanvas.DrawRoundRect(TSkRoundRect.Create(
        RectF(CardRect.Left + 114, CardRect.Bottom - 30, CardRect.Left + 180, CardRect.Bottom - 12), 4, 4),
        ShimmerPaint);

      // 8. 底部加购按钮占位块
      ACanvas.DrawRoundRect(TSkRoundRect.Create(
        RectF(CardRect.Right - 82, CardRect.Bottom - 34, CardRect.Right - 8, CardRect.Bottom - 8), 4, 4),
        ShimmerPaint);
    end;
  end
  else
  begin
    // 双列网格骨架屏 (SpanCount = 2)
    ColWidth := Max(10, (Width - (FItemSpacing * (SpanCount + 1))) / SpanCount);
    CardHeight := 202;
    if FRenderer <> nil then
      CardHeight := FRenderer.GetItemHeight(FContext, ColWidth);

    for R := 0 to 2 do
    begin
      for C := 0 to SpanCount - 1 do
      begin
        CardRect := RectF(
          FItemSpacing + C * (ColWidth + FItemSpacing),
          FItemSpacing + R * (CardHeight + FItemSpacing) - FScrollY,
          FItemSpacing + C * (ColWidth + FItemSpacing) + ColWidth,
          FItemSpacing + R * (CardHeight + FItemSpacing) + CardHeight - FScrollY
        );
        if (CardRect.Bottom < 0) or (CardRect.Top > Height) then Continue;

        FContext.DrawCardBox(ACanvas, CardRect, TAlphaColors.White, 8, 0, 0, True);

        GrayVal := EnsureRange(Round(236 + 10 * Sin(FShimmerPhase * Pi + (R * SpanCount + C) * 0.4)), 0, 255);
        CRec.R := GrayVal;
        CRec.G := GrayVal;
        CRec.B := GrayVal;
        ShimmerColor := CRec.Color;
        ShimmerPaint := FContext.FillPaint(ShimmerColor);

        // 封面图
        ACanvas.DrawRoundRect(TSkRoundRect.Create(
          RectF(CardRect.Left + 8, CardRect.Top + 8, CardRect.Right - 8, CardRect.Top + 120), 6, 6),
          ShimmerPaint);

        // 店名
        ACanvas.DrawRoundRect(TSkRoundRect.Create(
          RectF(CardRect.Left + 8, CardRect.Top + 130, CardRect.Right - 24, CardRect.Top + 146), 4, 4),
          ShimmerPaint);

        // 地址
        ACanvas.DrawRoundRect(TSkRoundRect.Create(
          RectF(CardRect.Left + 8, CardRect.Top + 154, CardRect.Right - 48, CardRect.Top + 166), 4, 4),
          ShimmerPaint);

        // 评分与月售
        ACanvas.DrawRoundRect(TSkRoundRect.Create(
          RectF(CardRect.Left + 8, CardRect.Top + 176, CardRect.Left + 72, CardRect.Bottom - 8), 4, 4),
          ShimmerPaint);
      end;
    end;
  end;
end;

procedure TSkVirtualListView.DrawEmptyState(const ACanvas: ISkCanvas);
var
  CenterX, CenterY: Single;
  BoxRect: TRectF;
  Prompt: string;
  LFont: ISkFont;
  TextW: Single;
begin
  CenterX := Width / 2;
  CenterY := Height / 2 - 20;

  // 1. 绘制空状态矢量箱子图标 (60x60)
  BoxRect := RectF(CenterX - 30, CenterY - 40, CenterX + 30, CenterY + 20);
  FContext.DrawSvgPath(ACanvas, SVG_EMPTY_BOX, BoxRect, $FFCCCCCC);

  // 2. 居中绘制提示文本
  Prompt := FEmptyPrompt;
  if Prompt.IsEmpty then
    Prompt := '暂无相关数据';

  LFont := FContext.Font(12.0, False);
  TextW := LFont.MeasureText(Prompt);
  ACanvas.DrawSimpleText(Prompt, Max(0, (Width - TextW) / 2), CenterY + 42, LFont,
    FContext.FillPaint($FF9E9E9E));
end;

procedure TSkVirtualListView.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited MouseWheel(Shift, WheelDelta, Handled);
  FLastUserActionTime := TThread.GetTickCount64;
  // 接入 FAniCalculations 惯性物理模型，实现带平滑阻尼缓动的现代滚轮滚动
  FAniCalculations.MouseWheel(0, -WheelDelta * 0.6);
  Handled := True;
end;

procedure TSkVirtualListView.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
var
  I: Integer;
  CardRect, LoadingRect, HeaderRect, BackToTopRect: TRectF;
  LFont: ISkFont;
  LoadText, RefreshText: string;
  Baseline, TextW, PullH, ViewTop, ViewBottom: Single;
  ItemRenderer: ISkCardRenderer;
  TargetAlpha, BtnCenterX, BtnCenterY: Single;
  CRec: TAlphaColorRec;
  ArrowPaint: ISkPaint;
begin
  ACanvas.Save;
  try
    ACanvas.ClipRect(ADest);

    // 1. 绘制顶部“下拉刷新”自绘提示
    if (FScrollY < 0) or FIsRefreshing then
    begin
      PullH := Max(0, -FScrollY);
      if PullH > 4 then
      begin
        HeaderRect := RectF(0, 0, Width, PullH);
        LFont := FContext.Font(11.0, False);
        Baseline := FContext.GetCenterBaseline(LFont, HeaderRect);
        if FIsRefreshing then
          RefreshText := '正在刷新数据...'
        else if PullH >= 50 then
          RefreshText := '释放立即刷新'
        else
          RefreshText := '下拉即可刷新...';

        TextW := LFont.MeasureText(RefreshText);
        ACanvas.DrawSimpleText(RefreshText, Max(0, (Width - TextW) / 2), Baseline, LFont,
          FContext.FillPaint($FF888888));
      end;
    end;

    if (FRenderer = nil) and (FRendererMap.Count = 0) then Exit;

    // 空数据拦截：若处于加载中则绘制呼吸微光骨架屏，若加载完毕无数据则绘制空状态
    if FItems.Count = 0 then
    begin
      if FIsLoading then
      begin
        DrawSkeleton(ACanvas);
        FShimmerPhase := FShimmerPhase + 0.035;
        if FShimmerPhase > 2.0 then
          FShimmerPhase := FShimmerPhase - 2.0;
        Redraw;
      end
      else
        DrawEmptyState(ACanvas);
      Exit;
    end;

    // 5. 遍历 FSlots 槽位进行快速视口裁剪与卡片渲染 (稳定绝对物理锚定，零抖动、零跳跃)
    ViewTop := FScrollY;
    ViewBottom := FScrollY + Height;

    for I := 0 to High(FSlots) do
    begin
      if FSlots[I].Rect.Bottom < ViewTop then Continue;
      // 增加 300px 安全冗余缓冲，确保双列网格与混排模式下所有可视卡片 100% 完整绘制
      if FSlots[I].Rect.Top > (ViewBottom + 300) then Break;

      CardRect := RectF(
        FSlots[I].Rect.Left,
        FSlots[I].Rect.Top - FScrollY,
        FSlots[I].Rect.Right,
        FSlots[I].Rect.Bottom - FScrollY
      );

      if FSlots[I].Renderer <> nil then
        FSlots[I].Renderer.DrawCard(ACanvas, FContext, FItems[I], CardRect,
          (FPressedIndex = I), FPressedZoneID);
    end;

    // 6. 绘制底部“正在加载更多...”提示
    if FIsLoadingMore and (FTotalContentHeight > 0) then
    begin
      LoadingRect := RectF(0, FTotalContentHeight - FScrollY - 34, Width, FTotalContentHeight - FScrollY);
      LFont := FContext.Font(10.5, False);
      Baseline := FContext.GetCenterBaseline(LFont, LoadingRect);
      LoadText := '正在加载更多商品...';
      TextW := LFont.MeasureText(LoadText);
      ACanvas.DrawSimpleText(LoadText, Max(0, (Width - TextW) / 2), Baseline, LFont,
        FContext.FillPaint($FF999999));
    end;

    // 7. 绘制回到顶部悬浮自绘按钮 (超过 180px 显示，回到顶部时瞬间隐去，绝不残留)
    if (not FIsScrollingToTop) and (FScrollY > 180) then
      FBackToTopAlpha := 1.0
    else
      FBackToTopAlpha := 0.0;

    if FBackToTopAlpha > 0.01 then
    begin
      BackToTopRect := GetBackToTopRect;
      ACanvas.Save;
      try
        ACanvas.ClipRect(RectF(0, 0, Width, Height));

        // 7.1 半透明磨砂纯白底托（带微阴影）
        CRec.A := EnsureRange(Round(FBackToTopAlpha * 242), 0, 255);
        if FBackToTopPressed then
        begin
          CRec.R := 236; CRec.G := 236; CRec.B := 236;
        end
        else
        begin
          CRec.R := 255; CRec.G := 255; CRec.B := 255;
        end;
        FContext.DrawCardBox(ACanvas, BackToTopRect, CRec.Color, BackToTopRect.Width / 2, 0, 0, True);

        // 7.2 居中自绘加粗橙红色向上矢量箭头
        CRec.A := EnsureRange(Round(FBackToTopAlpha * 255), 0, 255);
        CRec.R := 230; CRec.G := 67; CRec.B := 46;
        ArrowPaint := FContext.StrokePaint(CRec.Color, 2.2);
        ArrowPaint.StrokeCap := TSkStrokeCap.Round;
        ArrowPaint.StrokeJoin := TSkStrokeJoin.Round;

        BtnCenterX := BackToTopRect.CenterPoint.X;
        BtnCenterY := BackToTopRect.CenterPoint.Y;

        ACanvas.DrawLine(PointF(BtnCenterX - 5.5, BtnCenterY + 2), PointF(BtnCenterX, BtnCenterY - 3.5), ArrowPaint);
        ACanvas.DrawLine(PointF(BtnCenterX, BtnCenterY - 3.5), PointF(BtnCenterX + 5.5, BtnCenterY + 2), ArrowPaint);
        ACanvas.DrawLine(PointF(BtnCenterX, BtnCenterY - 3.5), PointF(BtnCenterX, BtnCenterY + 6), ArrowPaint);
      finally
        ACanvas.Restore;
      end;
    end;
  finally
    ACanvas.Restore;
  end;
end;

end.
