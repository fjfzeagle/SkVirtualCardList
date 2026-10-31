unit SkUiDsl;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Generics.Collections, System.Skia,
  SkImageCache, SkVirtualList.Core;

type
  TUiAlignment = (alLeading, alCenter, alTrailing, alStretch);
  TUiJustify = (juStart, juCenter, juEnd, juBetween);

  // 声明式节点核心接口
  IUiNode = interface
    ['{A6724CB0-99E8-41DB-85F0-5C6D14DFEF50}']
    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
    procedure Layout(const ARect: TRectF);
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
    function GetDesiredSize: TSizeF;
    function GetFlex: Single;
    function GetZoneID: Integer;
    function HitTest(const APoint: TPointF): Integer;
    function FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean;
  end;

  // 节点抽象基类
  TUiNode = class(TInterfacedObject, IUiNode)
  protected
    FDesiredSize: TSizeF;
    FLayoutBounds: TRectF;
    FFlex: Single;
    FZoneID: Integer;
  public
    constructor Create; virtual;
    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; virtual; abstract;
    procedure Layout(const ARect: TRectF); virtual;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); virtual; abstract;

    function GetDesiredSize: TSizeF;
    function GetFlex: Single;
    function GetZoneID: Integer;

    function Flex(const AVal: Single): TUiNode;
    function OnClick(const AZoneID: Integer): TUiNode;

    function HitTest(const APoint: TPointF): Integer; virtual;
    function FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean; virtual;
  end;

  // 水平排列容器 (HStack)
  THStack = class(TUiNode)
  private
    FSpacing: Single;
    FPaddingLeft, FPaddingTop, FPaddingRight, FPaddingBottom: Single;
    FAlignItems: TUiAlignment;
    FJustify: TUiJustify;
    FChildren: TList<IUiNode>;
  public
    constructor Create; override;
    destructor Destroy; override;

    function Spacing(const AVal: Single): THStack;
    function Padding(const L, T, R, B: Single): THStack; overload;
    function Padding(const H, V: Single): THStack; overload;
    function Padding(const AAll: Single): THStack; overload;
    function AlignCenter: THStack;
    function AlignStart: THStack;
    function AlignEnd: THStack;
    function AlignStretch: THStack;
    function Between: THStack;
    function Children(const AList: array of IUiNode): THStack;
    function Flex(const AVal: Single): THStack;
    function OnClick(const AZoneID: Integer): THStack;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Layout(const ARect: TRectF); override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
    function HitTest(const APoint: TPointF): Integer; override;
    function FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean; override;
  end;

  // 垂直排列容器 (VStack)
  TVStack = class(TUiNode)
  private
    FSpacing: Single;
    FPaddingLeft, FPaddingTop, FPaddingRight, FPaddingBottom: Single;
    FAlignItems: TUiAlignment;
    FChildren: TList<IUiNode>;
  public
    constructor Create; override;
    destructor Destroy; override;

    function Spacing(const AVal: Single): TVStack;
    function Padding(const L, T, R, B: Single): TVStack; overload;
    function Padding(const H, V: Single): TVStack; overload;
    function Padding(const AAll: Single): TVStack; overload;
    function AlignCenter: TVStack;
    function AlignStart: TVStack;
    function AlignEnd: TVStack;
    function AlignStretch: TVStack;
    function Children(const AList: array of IUiNode): TVStack;
    function Flex(const AVal: Single): TVStack;
    function OnClick(const AZoneID: Integer): TVStack;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Layout(const ARect: TRectF); override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
    function HitTest(const APoint: TPointF): Integer; override;
    function FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean; override;
  end;

  // 样式盒容器 (Box / Container)
  TBoxNode = class(TUiNode)
  private
    FFillColor: TAlphaColor;
    FStrokeColor: TAlphaColor;
    FStrokeWidth: Single;
    FCornerRadius: Single;
    FHasShadow: Boolean;
    FHasFill: Boolean;
    FPaddingLeft, FPaddingTop, FPaddingRight, FPaddingBottom: Single;
    FFixedWidth, FFixedHeight: Single;
    FChild: IUiNode;
  public
    constructor Create; override;
    destructor Destroy; override;

    function Fill(const AColor: TAlphaColor): TBoxNode;
    function Stroke(const AColor: TAlphaColor; const AWidth: Single): TBoxNode;
    function Radius(const ARadius: Single): TBoxNode;
    function Shadow(const AEnable: Boolean = True): TBoxNode;
    function Padding(const L, T, R, B: Single): TBoxNode; overload;
    function Padding(const H, V: Single): TBoxNode; overload;
    function Padding(const AAll: Single): TBoxNode; overload;
    function Width(const AVal: Single): TBoxNode;
    function Height(const AVal: Single): TBoxNode;
    function Size(const W, H: Single): TBoxNode;
    function Child(const ANode: IUiNode): TBoxNode;
    function Children(const AList: array of IUiNode): TBoxNode;
    function Flex(const AVal: Single): TBoxNode;
    function OnClick(const AZoneID: Integer): TBoxNode;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Layout(const ARect: TRectF); override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
    function HitTest(const APoint: TPointF): Integer; override;
    function FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean; override;
  end;

  // 弹簧占位符 (Spacer)
  TSpacerNode = class(TUiNode)
  private
    FWidth, FHeight: Single;
  public
    constructor Create(const W: Single = 0; const H: Single = 0); reintroduce;
    function Width(const AVal: Single): TSpacerNode;
    function Height(const AVal: Single): TSpacerNode;
    function Flex(const AVal: Single): TSpacerNode;
    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
  end;

  // 文本节点 (SkText)
  TTextNode = class(TUiNode)
  private
    FText: string;
    FFontSize: Single;
    FColor: TAlphaColor;
    FBold: Boolean;
    FStrikethrough: Boolean;
    FMaxLines: Integer;
    FWrap: Boolean;
  public
    constructor Create(const AText: string); reintroduce;
    function Size(const AVal: Single): TTextNode;
    function Color(const AColor: TAlphaColor): TTextNode;
    function Bold(const AVal: Boolean = True): TTextNode;
    function Strikethrough(const AVal: Boolean = True): TTextNode;
    function MaxLines(const AVal: Integer): TTextNode;
    function Wrap(const AVal: Boolean = True): TTextNode;
    function Flex(const AVal: Single): TTextNode;

    property IsWrap: Boolean read FWrap;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
  end;

  // 异步网络图片节点 (AsyncImage)
  TImageNode = class(TUiNode)
  private
    FUrl: string;
    FWidth, FHeight: Single;
    FFillWidth: Boolean;
    FCornerRadius: Single;
    FImgRadiusTL, FImgRadiusTR, FImgRadiusBR, FImgRadiusBL: Single;
    FPlaceholderColor: TAlphaColor;
    FBadgeText: string;
    FBadgeBgColor: TAlphaColor;
    FBadgeTextColor: TAlphaColor;
    FBadgeRadiusTL: Single;
    FBadgeRadiusTR: Single;
    FBadgeRadiusBR: Single;
    FBadgeRadiusBL: Single;
    FBadgeHeight: Single;
    FBadgeFontSize: Single;
    FBadgePaddingH: Single;
    FBadgeFloating: Boolean;
    FBadgeFloatOffset: Single;
    FBottomBarText: string;
    FBottomBarBgColor: TAlphaColor;
    FOwner: TObject;
  public
    constructor Create(const AUrl: string; const AOwner: TObject = nil); reintroduce;
    function Width(const AVal: Single): TImageNode;
    function Height(const AVal: Single): TImageNode;
    function Size(const W, H: Single): TImageNode;
    function FillWidth(const AVal: Boolean = True): TImageNode;
    function Radius(const ARadius: Single): TImageNode; overload;
    function Radius(const ATL, ATR, ABR, ABL: Single): TImageNode; overload;
    function RadiusTop(const ARadius: Single): TImageNode;
    function Placeholder(const AColor: TAlphaColor): TImageNode;
    function Badge(const AText: string;
                   const ABgColor: TAlphaColor = $EBE6432E;
                   const ARadiusBR: Single = 6;
                   const AHeight: Single = 16): TImageNode;
    function BadgeRadius(const AAll: Single): TImageNode; overload;
    function BadgeRadius(const ATL, ATR, ABR, ABL: Single): TImageNode; overload;
    function BadgeRadiusTopLeft(const AVal: Single): TImageNode;
    function BadgeRadiusTopRight(const AVal: Single): TImageNode;
    function BadgeRadiusBottomRight(const AVal: Single): TImageNode;
    function BadgeRadiusBottomLeft(const AVal: Single): TImageNode;
    function BadgeRadiusTL(const AVal: Single): TImageNode;
    function BadgeRadiusTR(const AVal: Single): TImageNode;
    function BadgeRadiusBR(const AVal: Single): TImageNode;
    function BadgeRadiusBL(const AVal: Single): TImageNode;
    function BadgeHeight(const AHeight: Single): TImageNode;
    function BadgeFontSize(const ASize: Single): TImageNode;
    function BadgePadding(const APaddingH: Single): TImageNode;
    function BadgeColor(const AColor: TAlphaColor): TImageNode;
    function BadgeTextColor(const AColor: TAlphaColor): TImageNode;
    function BadgeFloating(const AIsFloating: Boolean = True; const AOffset: Single = 4): TImageNode;
    function BottomBar(const AText: string; const ABgColor: TAlphaColor = $B0202022): TImageNode;
    function Flex(const AVal: Single): TImageNode;
    function OnClick(const AZoneID: Integer): TImageNode;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
  end;

  // 轮播图节点 (Carousel)
  TCarouselNode = class(TUiNode)
  private
    FImages: TArray<string>;
    FActiveIndex: Integer;
    FScrollOffset: Single;
    FWidth, FHeight: Single;
    FFillWidth: Boolean;
    FCornerRadius: Single;
    FPlaceholderColor: TAlphaColor;
    FBadgeText: string;
    FBadgeBgColor: TAlphaColor;
    FBadgeTextColor: TAlphaColor;
    FBadgeRadiusBR: Single;
    FBadgeHeight: Single;
    FBadgeFontSize: Single;
    FBadgePaddingH: Single;
    FBottomBarText: string;
    FBottomBarBgColor: TAlphaColor;
    FOwner: TObject;
    FShowIndicator: Boolean;
    FAutoCruise: Boolean;
  public
    constructor Create(const AImages: array of string; const AOwner: TObject = nil); reintroduce; overload;
    constructor Create(const AImages: TArray<string>; const AOwner: TObject = nil); reintroduce; overload;
    function Width(const AVal: Single): TCarouselNode;
    function Height(const AVal: Single): TCarouselNode;
    function Size(const W, H: Single): TCarouselNode;
    function FillWidth(const AVal: Boolean = True): TCarouselNode;
    function Radius(const ARadius: Single): TCarouselNode;
    function ActiveIndex(const AIndex: Integer): TCarouselNode;
    function ScrollOffset(const AOffset: Single): TCarouselNode;
    function AutoCruise(const AVal: Boolean = True): TCarouselNode;
    function Badge(const AText: string;
                   const ABgColor: TAlphaColor = $EBE6432E;
                   const ARadiusBR: Single = 6;
                   const AHeight: Single = 16): TCarouselNode;
    function BottomBar(const AText: string; const ABgColor: TAlphaColor = $B0202022): TCarouselNode;
    function ShowIndicator(const AVal: Boolean = True): TCarouselNode;
    function Flex(const AVal: Single): TCarouselNode;
    function OnClick(const AZoneID: Integer): TCarouselNode;

    property IsAutoCruise: Boolean read FAutoCruise;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
  end;

  // 矢量 SVG Path 图标节点 (SkSvg)
  TSvgNode = class(TUiNode)
  private
    FSvgPath: string;
    FWidth, FHeight: Single;
    FColor: TAlphaColor;
  public
    constructor Create(const ASvgPath: string); reintroduce;
    function Size(const W, H: Single): TSvgNode;
    function Color(const AColor: TAlphaColor): TSvgNode;
    function OnClick(const AZoneID: Integer): TSvgNode;
    function Flex(const AVal: Single): TSvgNode;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
  end;

  // 圆形节点 (SkCircle)
  TCircleNode = class(TUiNode)
  private
    FRadius: Single;
    FFillColor: TAlphaColor;
    FStrokeColor: TAlphaColor;
    FStrokeWidth: Single;
  public
    constructor Create(const ARadius: Single); reintroduce;
    function Fill(const AColor: TAlphaColor): TCircleNode;
    function Stroke(const AColor: TAlphaColor; const AWidth: Single): TCircleNode;
    function OnClick(const AZoneID: Integer): TCircleNode;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
  end;

  // 便捷标签节点 (SkBadge)
  TBadgeNode = class(TUiNode)
  private
    FText: string;
    FFontSize: Single;
    FTextColor: TAlphaColor;
    FFillColor: TAlphaColor;
    FStrokeColor: TAlphaColor;
    FStrokeWidth: Single;
    FCornerRadius: Single;
    FPaddingH, FPaddingV: Single;
  public
    constructor Create(const AText: string); reintroduce;
    function TextColor(const AColor: TAlphaColor): TBadgeNode;
    function Fill(const AColor: TAlphaColor): TBadgeNode;
    function Stroke(const AColor: TAlphaColor; const AWidth: Single): TBadgeNode;
    function Radius(const ARadius: Single): TBadgeNode;
    function FontSize(const ASize: Single): TBadgeNode;
    function Padding(const H, V: Single): TBadgeNode;

    function Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF; override;
    procedure Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext); override;
  end;

  TCachedLayout = record
    Node: IUiNode;
    Width: Single;
    Height: Single;
  end;

  // 声明式渲染器基类：提供直观的 BuildLayout 模板方法与高性能排版复用
  TDeclarativeCardRenderer = class(TInterfacedObject, ISkCardRenderer)
  protected
    FSpanCount: Integer;
    FItemHeight: Single;
    FCache: TDictionary<TObject, TCachedLayout>;
  public
    constructor Create(const ASpanCount: Integer = 1; const AItemHeight: Single = 142);
    destructor Destroy; override;
    procedure ClearCache; virtual;
    function GetSpanCount: Integer; virtual;
    function GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject = nil): Single; virtual;
    function BuildLayout(AItem: TObject): IUiNode; virtual; abstract;
    procedure DrawCard(const ACanvas: ISkCanvas; AContext: TSkRenderContext;
      AItem: TObject; const ARect: TRectF; AIsPressed: Boolean; APressedZoneID: Integer); virtual;
    function HitTestCard(AItem: TObject; const ARect: TRectF; const APoint: TPointF): Integer; virtual;

    function CanSwipeImage(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean; virtual;
    function CanAutoCruise(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean; virtual;
    procedure OnImageSwipe(AItem: TObject; const ADeltaX: Single); virtual;
    procedure OnImageSwipeEnd(AItem: TObject; const ADeltaX, AImgWidth: Single); virtual;
    function ResolveSwipeTarget(AItem: TObject; const ADeltaX, AImgWidth: Single;
      out ATargetOffset: Single; out AIndexDelta: Integer): Boolean; virtual;
    procedure OnImageSwipeFinished(AItem: TObject; const AIndexDelta: Integer); virtual;
  end;

// 全局 DSL 构造入口函数
function HStack: THStack;
function VStack: TVStack;
function Box: TBoxNode;
function Spacer(const W: Single = 0; const H: Single = 0): TSpacerNode;
function SkText(const AText: string): TTextNode;
function AsyncImage(const AUrl: string; const AOwner: TObject = nil): TImageNode;
function Carousel(const AImages: array of string; const AOwner: TObject = nil): TCarouselNode; overload;
function Carousel(const AImages: TArray<string>; const AOwner: TObject = nil): TCarouselNode; overload;
function SkSvg(const ASvgPath: string): TSvgNode;
function SkCircle(const ARadius: Single): TCircleNode;
function SkBadge(const AText: string): TBadgeNode;
function SplitTextLines(const AText: string; const AFont: ISkFont; const AMaxWidth: Single): TArray<string>;

implementation

function HStack: THStack;
begin
  Result := THStack.Create;
end;

function VStack: TVStack;
begin
  Result := TVStack.Create;
end;

function Box: TBoxNode;
begin
  Result := TBoxNode.Create;
end;

function Spacer(const W, H: Single): TSpacerNode;
begin
  Result := TSpacerNode.Create(W, H);
end;

function SkText(const AText: string): TTextNode;
begin
  Result := TTextNode.Create(AText);
end;

function AsyncImage(const AUrl: string; const AOwner: TObject): TImageNode;
begin
  Result := TImageNode.Create(AUrl, AOwner);
end;

function Carousel(const AImages: array of string; const AOwner: TObject): TCarouselNode;
begin
  Result := TCarouselNode.Create(AImages, AOwner);
end;

function Carousel(const AImages: TArray<string>; const AOwner: TObject): TCarouselNode;
begin
  Result := TCarouselNode.Create(AImages, AOwner);
end;

function SkSvg(const ASvgPath: string): TSvgNode;
begin
  Result := TSvgNode.Create(ASvgPath);
end;

function SkCircle(const ARadius: Single): TCircleNode;
begin
  Result := TCircleNode.Create(ARadius);
end;

function SkBadge(const AText: string): TBadgeNode;
begin
  Result := TBadgeNode.Create(AText);
end;

{ TUiNode }

constructor TUiNode.Create;
begin
  inherited Create;
  FDesiredSize := TSizeF.Create(0, 0);
  FLayoutBounds := TRectF.Empty;
  FFlex := 0;
  FZoneID := 0;
end;

function TUiNode.GetDesiredSize: TSizeF;
begin
  Result := FDesiredSize;
end;

function TUiNode.GetFlex: Single;
begin
  Result := FFlex;
end;

function TUiNode.GetZoneID: Integer;
begin
  Result := FZoneID;
end;

function TUiNode.Flex(const AVal: Single): TUiNode;
begin
  FFlex := AVal;
  Result := Self;
end;

function TUiNode.OnClick(const AZoneID: Integer): TUiNode;
begin
  FZoneID := AZoneID;
  Result := Self;
end;

procedure TUiNode.Layout(const ARect: TRectF);
begin
  FLayoutBounds := ARect;
end;

function TUiNode.HitTest(const APoint: TPointF): Integer;
begin
  if (FZoneID <> 0) and FLayoutBounds.Contains(APoint) then
    Result := FZoneID
  else
    Result := 0;
end;

function TUiNode.FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean;
begin
  if (FZoneID <> 0) and (FZoneID = AZoneID) then
  begin
    ABounds := FLayoutBounds;
    ARadius := 0;
    Result := True;
  end
  else
    Result := False;
end;

{ THStack }

constructor THStack.Create;
begin
  inherited Create;
  FSpacing := 0;
  FPaddingLeft := 0;
  FPaddingTop := 0;
  FPaddingRight := 0;
  FPaddingBottom := 0;
  FAlignItems := alCenter;
  FJustify := juStart;
  FChildren := TList<IUiNode>.Create;
end;

destructor THStack.Destroy;
begin
  FChildren.Free;
  inherited Destroy;
end;

function THStack.Spacing(const AVal: Single): THStack;
begin
  FSpacing := AVal;
  Result := Self;
end;

function THStack.Padding(const L, T, R, B: Single): THStack;
begin
  FPaddingLeft := L;
  FPaddingTop := T;
  FPaddingRight := R;
  FPaddingBottom := B;
  Result := Self;
end;

function THStack.Padding(const H, V: Single): THStack;
begin
  Result := Padding(H, V, H, V);
end;

function THStack.Padding(const AAll: Single): THStack;
begin
  Result := Padding(AAll, AAll, AAll, AAll);
end;

function THStack.AlignCenter: THStack;
begin
  FAlignItems := alCenter;
  Result := Self;
end;

function THStack.AlignStart: THStack;
begin
  FAlignItems := alLeading;
  Result := Self;
end;

function THStack.AlignEnd: THStack;
begin
  FAlignItems := alTrailing;
  Result := Self;
end;

function THStack.AlignStretch: THStack;
begin
  FAlignItems := alStretch;
  Result := Self;
end;

function THStack.Between: THStack;
begin
  FJustify := juBetween;
  Result := Self;
end;

function THStack.Children(const AList: array of IUiNode): THStack;
var
  Node: IUiNode;
begin
  for Node in AList do
    if Node <> nil then
      FChildren.Add(Node);
  Result := Self;
end;

function THStack.Flex(const AVal: Single): THStack;
begin
  FFlex := AVal;
  Result := Self;
end;

function THStack.OnClick(const AZoneID: Integer): THStack;
begin
  FZoneID := AZoneID;
  Result := Self;
end;

function THStack.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
var
  Child: IUiNode;
  ChildSize: TSizeF;
  TotalW, MaxH: Single;
  I: Integer;
  FixedW, AvailForFlex, TotalFlex, FlexUnitW, ChildFlexW: Single;
begin
  MaxH := 0;
  FixedW := 0;
  TotalFlex := 0;

  // 第 1 趟：先度量所有固定宽度的子节点 (GetFlex = 0)
  for I := 0 to FChildren.Count - 1 do
  begin
    Child := FChildren[I];
    if Child.GetFlex > 0 then
      TotalFlex := TotalFlex + Child.GetFlex
    else
    begin
      ChildSize := Child.Measure(AContext, AMaxWidth - (FPaddingLeft + FPaddingRight), AMaxHeight);
      FixedW := FixedW + ChildSize.cx;
      MaxH := Max(MaxH, ChildSize.cy);
    end;
  end;

  // 扣除兄弟项之间的间隔
  if FChildren.Count > 1 then
    FixedW := FixedW + (FSpacing * (FChildren.Count - 1));

  // 计算可供弹性子节点瓜分的剩余可用宽度
  AvailForFlex := Max(0, AMaxWidth - (FPaddingLeft + FPaddingRight) - FixedW);
  if TotalFlex > 0 then
    FlexUnitW := AvailForFlex / TotalFlex
  else
    FlexUnitW := 0;

  // 第 2 趟：为弹性子节点 (GetFlex > 0) 传入其实际分得的精确宽度进行度量！
  for I := 0 to FChildren.Count - 1 do
  begin
    Child := FChildren[I];
    if Child.GetFlex > 0 then
    begin
      ChildFlexW := Child.GetFlex * FlexUnitW;
      ChildSize := Child.Measure(AContext, ChildFlexW, AMaxHeight);
      MaxH := Max(MaxH, ChildSize.cy);
    end;
  end;

  if TotalFlex > 0 then
    TotalW := FixedW + AvailForFlex + FPaddingLeft + FPaddingRight
  else
    TotalW := FixedW + FPaddingLeft + FPaddingRight;
  FDesiredSize := TSizeF.Create(TotalW, MaxH + FPaddingTop + FPaddingBottom);
  Result := FDesiredSize;
end;

procedure THStack.Layout(const ARect: TRectF);
var
  AvailW, TotalFlex, FlexUnitW, CurX, ChildW, ChildH, ChildY: Single;
  Child: IUiNode;
  I, J: Integer;
  ChildRect: TRectF;
  BetweenGap, RemainingNeededW, MaxAllowedW: Single;
begin
  inherited Layout(ARect);

  AvailW := ARect.Width - (FPaddingLeft + FPaddingRight);
  TotalFlex := 0;

  // 1. 扣除无 Flex 子项宽度及间距
  for Child in FChildren do
  begin
    if Child.GetFlex > 0 then
      TotalFlex := TotalFlex + Child.GetFlex
    else
      AvailW := AvailW - Child.GetDesiredSize.cx;
  end;

  if FJustify = juBetween then
  begin
    if FChildren.Count > 1 then
      BetweenGap := Max(0, AvailW) / (FChildren.Count - 1)
    else
      BetweenGap := 0;
  end
  else
  begin
    BetweenGap := FSpacing;
    if FChildren.Count > 1 then
      AvailW := AvailW - (FSpacing * (FChildren.Count - 1));
  end;

  if TotalFlex > 0 then
    FlexUnitW := Max(0, AvailW) / TotalFlex
  else
    FlexUnitW := 0;

  // 2. 依次排布
  CurX := ARect.Left + FPaddingLeft;

  for I := 0 to FChildren.Count - 1 do
  begin
    Child := FChildren[I];
    if Child.GetFlex > 0 then
    begin
      ChildW := Child.GetFlex * FlexUnitW;
    end
    else
    begin
      ChildW := Child.GetDesiredSize.cx;

      // 溢出防护：计算后续所有未排布的【固定尺寸(GetFlex = 0)】兄弟节点所需的最低固定宽度与间距之和
      // 注意：带 Flex > 0 的弹性子项自适应瓜分剩余空间，绝不能反向占用固定预留宽度挤压前面的固定项
      RemainingNeededW := 0;
      for J := I + 1 to FChildren.Count - 1 do
      begin
        if FChildren[J].GetFlex = 0 then
          RemainingNeededW := RemainingNeededW + FChildren[J].GetDesiredSize.cx;
        if FJustify <> juBetween then
          RemainingNeededW := RemainingNeededW + BetweenGap;
      end;

      // 当前子项的最大允许宽度，必须为后续兄弟节点预留空间，且不可逾越容器右边界
      MaxAllowedW := Max(0, (ARect.Right - FPaddingRight) - CurX - RemainingNeededW);
      if ChildW > MaxAllowedW then
        ChildW := MaxAllowedW;
    end;

    if ((Child is TVStack) or (Child is THStack) or (Child is TBoxNode)) and (Child.GetFlex > 0) then
      ChildH := ARect.Height - (FPaddingTop + FPaddingBottom)
    else
    begin
      ChildH := Min(Child.GetDesiredSize.cy, ARect.Height - (FPaddingTop + FPaddingBottom));
      if ChildH <= 0 then
        ChildH := ARect.Height - (FPaddingTop + FPaddingBottom);
    end;

    case FAlignItems of
      alLeading: ChildY := ARect.Top + FPaddingTop;
      alTrailing: ChildY := ARect.Bottom - FPaddingBottom - ChildH;
      alStretch:
        begin
          ChildY := ARect.Top + FPaddingTop;
          ChildH := ARect.Height - (FPaddingTop + FPaddingBottom);
        end;
    else
      // alCenter
      ChildY := ARect.Top + FPaddingTop + ((ARect.Height - FPaddingTop - FPaddingBottom) - ChildH) / 2;
    end;

    ChildRect := RectF(CurX, ChildY, CurX + ChildW, ChildY + ChildH);
    Child.Layout(ChildRect);

    CurX := CurX + ChildW + BetweenGap;
  end;
end;

procedure THStack.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
var
  Child: IUiNode;
begin
  for Child in FChildren do
    Child.Draw(ACanvas, AContext);
end;

function THStack.HitTest(const APoint: TPointF): Integer;
var
  I, Z: Integer;
begin
  Result := 0;
  if not FLayoutBounds.Contains(APoint) then Exit;
  for I := FChildren.Count - 1 downto 0 do
  begin
    Z := FChildren[I].HitTest(APoint);
    if Z <> 0 then Exit(Z);
  end;
  if FZoneID <> 0 then Result := FZoneID;
end;

function THStack.FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean;
var
  Child: IUiNode;
begin
  if (FZoneID <> 0) and (FZoneID = AZoneID) then
  begin
    ABounds := FLayoutBounds;
    ARadius := 0;
    Exit(True);
  end;
  for Child in FChildren do
    if Child.FindZone(AZoneID, ABounds, ARadius) then Exit(True);
  Result := False;
end;

{ TVStack }

constructor TVStack.Create;
begin
  inherited Create;
  FSpacing := 0;
  FPaddingLeft := 0;
  FPaddingTop := 0;
  FPaddingRight := 0;
  FPaddingBottom := 0;
  FAlignItems := alLeading;
  FChildren := TList<IUiNode>.Create;
end;

destructor TVStack.Destroy;
begin
  FChildren.Free;
  inherited Destroy;
end;

function TVStack.Spacing(const AVal: Single): TVStack;
begin
  FSpacing := AVal;
  Result := Self;
end;

function TVStack.Padding(const L, T, R, B: Single): TVStack;
begin
  FPaddingLeft := L;
  FPaddingTop := T;
  FPaddingRight := R;
  FPaddingBottom := B;
  Result := Self;
end;

function TVStack.Padding(const H, V: Single): TVStack;
begin
  Result := Padding(H, V, H, V);
end;

function TVStack.Padding(const AAll: Single): TVStack;
begin
  Result := Padding(AAll, AAll, AAll, AAll);
end;

function TVStack.AlignCenter: TVStack;
begin
  FAlignItems := alCenter;
  Result := Self;
end;

function TVStack.AlignStart: TVStack;
begin
  FAlignItems := alLeading;
  Result := Self;
end;

function TVStack.AlignEnd: TVStack;
begin
  FAlignItems := alTrailing;
  Result := Self;
end;

function TVStack.AlignStretch: TVStack;
begin
  FAlignItems := alStretch;
  Result := Self;
end;

function TVStack.Children(const AList: array of IUiNode): TVStack;
var
  Node: IUiNode;
begin
  for Node in AList do
    if Node <> nil then
      FChildren.Add(Node);
  Result := Self;
end;

function TVStack.Flex(const AVal: Single): TVStack;
begin
  FFlex := AVal;
  Result := Self;
end;

function TVStack.OnClick(const AZoneID: Integer): TVStack;
begin
  FZoneID := AZoneID;
  Result := Self;
end;

function TVStack.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
var
  Child: IUiNode;
  ChildSize: TSizeF;
  MaxW, TotalH: Single;
begin
  MaxW := 0;
  TotalH := FPaddingTop + FPaddingBottom;

  for Child in FChildren do
  begin
    ChildSize := Child.Measure(AContext, AMaxWidth - (FPaddingLeft + FPaddingRight), AMaxHeight);
    MaxW := Max(MaxW, ChildSize.cx);
    // 只有纯弹簧占位符 (TSpacerNode) 的 Flex 空间不在 Measure 阶段计入固有高度；
    // 任何包含实质内容的子节点 (如 HStack/VStack/Text)，其内容度量尺寸必须计入期望高度，防止高度坍塌
    if (Child.GetFlex = 0) or (not (Child is TSpacerNode)) then
      TotalH := TotalH + ChildSize.cy;
  end;

  if FChildren.Count > 1 then
    TotalH := TotalH + (FSpacing * (FChildren.Count - 1));

  FDesiredSize := TSizeF.Create(MaxW + FPaddingLeft + FPaddingRight, TotalH);
  Result := FDesiredSize;
end;

procedure TVStack.Layout(const ARect: TRectF);
var
  AvailH, TotalFlex, FlexUnitH, CurY, ChildW, ChildH, ChildX: Single;
  Child: IUiNode;
  ChildRect: TRectF;
begin
  inherited Layout(ARect);

  AvailH := ARect.Height - (FPaddingTop + FPaddingBottom);
  TotalFlex := 0;

  for Child in FChildren do
  begin
    if Child.GetFlex > 0 then
      TotalFlex := TotalFlex + Child.GetFlex
    else
      AvailH := AvailH - Child.GetDesiredSize.cy;
  end;

  if FChildren.Count > 1 then
    AvailH := AvailH - (FSpacing * (FChildren.Count - 1));

  if TotalFlex > 0 then
    FlexUnitH := Max(0, AvailH) / TotalFlex
  else
    FlexUnitH := 0;

  CurY := ARect.Top + FPaddingTop;

  for Child in FChildren do
  begin
    if Child.GetFlex > 0 then
    begin
      if Child is TSpacerNode then
        ChildH := Child.GetFlex * FlexUnitH
      else
        ChildH := Max(Child.GetDesiredSize.cy, Child.GetFlex * FlexUnitH);
    end
    else
      ChildH := Child.GetDesiredSize.cy;

    if (Child is THStack) or (Child is TVStack) or (Child is TBoxNode) or (Child.GetFlex > 0) or (FAlignItems = alStretch) then
      ChildW := ARect.Width - (FPaddingLeft + FPaddingRight)
    else if (Child is TImageNode) and (TImageNode(Child).GetDesiredSize.cx <= 0) then
      ChildW := ARect.Width - (FPaddingLeft + FPaddingRight)
    else
    begin
      ChildW := Child.GetDesiredSize.cx;
      if (ChildW <= 0) or (ChildW > ARect.Width - (FPaddingLeft + FPaddingRight)) then
        ChildW := ARect.Width - (FPaddingLeft + FPaddingRight);
    end;

    case FAlignItems of
      alTrailing: ChildX := ARect.Right - FPaddingRight - ChildW;
      alCenter: ChildX := ARect.Left + FPaddingLeft + ((ARect.Width - FPaddingLeft - FPaddingRight) - ChildW) / 2;
    else
      // alLeading
      ChildX := ARect.Left + FPaddingLeft;
    end;

    ChildRect := RectF(ChildX, CurY, ChildX + ChildW, CurY + ChildH);
    Child.Layout(ChildRect);

    CurY := CurY + ChildH + FSpacing;
  end;
end;

procedure TVStack.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
var
  Child: IUiNode;
begin
  for Child in FChildren do
    Child.Draw(ACanvas, AContext);
end;

function TVStack.HitTest(const APoint: TPointF): Integer;
var
  I, Z: Integer;
begin
  Result := 0;
  if not FLayoutBounds.Contains(APoint) then Exit;
  for I := FChildren.Count - 1 downto 0 do
  begin
    Z := FChildren[I].HitTest(APoint);
    if Z <> 0 then Exit(Z);
  end;
  if FZoneID <> 0 then Result := FZoneID;
end;

function TVStack.FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean;
var
  Child: IUiNode;
begin
  if (FZoneID <> 0) and (FZoneID = AZoneID) then
  begin
    ABounds := FLayoutBounds;
    ARadius := 0;
    Exit(True);
  end;
  for Child in FChildren do
    if Child.FindZone(AZoneID, ABounds, ARadius) then Exit(True);
  Result := False;
end;

{ TBoxNode }

constructor TBoxNode.Create;
begin
  inherited Create;
  FFillColor := 0;
  FStrokeColor := 0;
  FStrokeWidth := 0;
  FCornerRadius := 0;
  FHasShadow := False;
  FHasFill := False;
  FPaddingLeft := 0;
  FPaddingTop := 0;
  FPaddingRight := 0;
  FPaddingBottom := 0;
  FFixedWidth := 0;
  FFixedHeight := 0;
  FChild := nil;
end;

destructor TBoxNode.Destroy;
begin
  FChild := nil;
  inherited Destroy;
end;

function TBoxNode.Fill(const AColor: TAlphaColor): TBoxNode;
begin
  FFillColor := AColor;
  FHasFill := True;
  Result := Self;
end;

function TBoxNode.Stroke(const AColor: TAlphaColor; const AWidth: Single): TBoxNode;
begin
  FStrokeColor := AColor;
  FStrokeWidth := AWidth;
  Result := Self;
end;

function TBoxNode.Radius(const ARadius: Single): TBoxNode;
begin
  FCornerRadius := ARadius;
  Result := Self;
end;

function TBoxNode.Shadow(const AEnable: Boolean): TBoxNode;
begin
  FHasShadow := AEnable;
  Result := Self;
end;

function TBoxNode.Padding(const L, T, R, B: Single): TBoxNode;
begin
  FPaddingLeft := L;
  FPaddingTop := T;
  FPaddingRight := R;
  FPaddingBottom := B;
  Result := Self;
end;

function TBoxNode.Padding(const H, V: Single): TBoxNode;
begin
  Result := Padding(H, V, H, V);
end;

function TBoxNode.Padding(const AAll: Single): TBoxNode;
begin
  Result := Padding(AAll, AAll, AAll, AAll);
end;

function TBoxNode.Width(const AVal: Single): TBoxNode;
begin
  FFixedWidth := AVal;
  Result := Self;
end;

function TBoxNode.Height(const AVal: Single): TBoxNode;
begin
  FFixedHeight := AVal;
  Result := Self;
end;

function TBoxNode.Size(const W, H: Single): TBoxNode;
begin
  FFixedWidth := W;
  FFixedHeight := H;
  Result := Self;
end;

function TBoxNode.Child(const ANode: IUiNode): TBoxNode;
begin
  FChild := ANode;
  Result := Self;
end;

function TBoxNode.Children(const AList: array of IUiNode): TBoxNode;
var
  Stack: TVStack;
begin
  Stack := TVStack.Create;
  Stack.AlignStretch;
  Stack.Children(AList);
  FChild := Stack;
  Result := Self;
end;

function TBoxNode.Flex(const AVal: Single): TBoxNode;
begin
  FFlex := AVal;
  Result := Self;
end;

function TBoxNode.OnClick(const AZoneID: Integer): TBoxNode;
begin
  FZoneID := AZoneID;
  Result := Self;
end;

function TBoxNode.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
var
  ChildSize: TSizeF;
  InnerW, InnerH: Single;
begin
  InnerW := Max(0, AMaxWidth - (FPaddingLeft + FPaddingRight));
  InnerH := Max(0, AMaxHeight - (FPaddingTop + FPaddingBottom));

  if FChild <> nil then
    ChildSize := FChild.Measure(AContext, InnerW, InnerH)
  else
    ChildSize := TSizeF.Create(0, 0);

  if FFixedWidth > 0 then
    FDesiredSize.cx := FFixedWidth
  else
    FDesiredSize.cx := ChildSize.cx + FPaddingLeft + FPaddingRight;

  if FFixedHeight > 0 then
    FDesiredSize.cy := FFixedHeight
  else
    FDesiredSize.cy := ChildSize.cy + FPaddingTop + FPaddingBottom;

  Result := FDesiredSize;
end;

procedure TBoxNode.Layout(const ARect: TRectF);
var
  InnerRect: TRectF;
begin
  inherited Layout(ARect);

  if FChild <> nil then
  begin
    InnerRect := RectF(
      ARect.Left + FPaddingLeft,
      ARect.Top + FPaddingTop,
      ARect.Right - FPaddingRight,
      ARect.Bottom - FPaddingBottom
    );
    FChild.Layout(InnerRect);
  end;
end;

procedure TBoxNode.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
begin
  if FHasFill or (FStrokeWidth > 0) or FHasShadow then
  begin
    AContext.DrawCardBox(ACanvas, FLayoutBounds, FFillColor, FCornerRadius,
      FStrokeColor, FStrokeWidth, FHasShadow);
  end;

  if FChild <> nil then
    FChild.Draw(ACanvas, AContext);
end;

function TBoxNode.HitTest(const APoint: TPointF): Integer;
begin
  Result := 0;
  if not FLayoutBounds.Contains(APoint) then Exit;
  if FChild <> nil then
  begin
    Result := FChild.HitTest(APoint);
    if Result <> 0 then Exit;
  end;
  if FZoneID <> 0 then
    Result := FZoneID;
end;

function TBoxNode.FindZone(const AZoneID: Integer; out ABounds: TRectF; out ARadius: Single): Boolean;
begin
  if (FZoneID <> 0) and (FZoneID = AZoneID) then
  begin
    ABounds := FLayoutBounds;
    ARadius := FCornerRadius;
    Exit(True);
  end;
  if FChild <> nil then
    Result := FChild.FindZone(AZoneID, ABounds, ARadius)
  else
    Result := False;
end;

{ TSpacerNode }

constructor TSpacerNode.Create(const W, H: Single);
begin
  inherited Create;
  FWidth := W;
  FHeight := H;
  if (W = 0) and (H = 0) then
    FFlex := 1;
end;

function TSpacerNode.Width(const AVal: Single): TSpacerNode;
begin
  FWidth := AVal;
  FFlex := 0;
  Result := Self;
end;

function TSpacerNode.Height(const AVal: Single): TSpacerNode;
begin
  FHeight := AVal;
  FFlex := 0;
  Result := Self;
end;

function TSpacerNode.Flex(const AVal: Single): TSpacerNode;
begin
  FFlex := AVal;
  Result := Self;
end;

function TSpacerNode.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
begin
  FDesiredSize := TSizeF.Create(FWidth, FHeight);
  Result := FDesiredSize;
end;

procedure TSpacerNode.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
begin
  // 占位无可见像素
end;

{ TTextNode }

constructor TTextNode.Create(const AText: string);
begin
  inherited Create;
  FText := AText;
  FFontSize := 12;
  FColor := $FF333333;
  FBold := False;
  FStrikethrough := False;
  FMaxLines := 1;
  FWrap := False;
end;

function SplitTextLines(const AText: string; const AFont: ISkFont; const AMaxWidth: Single): TArray<string>;
var
  Lines: TList<string>;
  CurLine: string;
  CurW, ChW: Single;
  I: Integer;
  Ch: Char;
begin
  if (AText.IsEmpty) or (AMaxWidth <= 0) then
  begin
    SetLength(Result, 1);
    Result[0] := AText;
    Exit;
  end;

  Lines := TList<string>.Create;
  try
    CurLine := '';
    CurW := 0;
    for I := 1 to Length(AText) do
    begin
      Ch := AText[I];
      if Ch = #10 then
      begin
        Lines.Add(CurLine);
        CurLine := '';
        CurW := 0;
        Continue;
      end
      else if Ch = #13 then
        Continue;

      ChW := AFont.MeasureText(Ch);
      if (CurW + ChW > AMaxWidth) and (CurLine <> '') then
      begin
        Lines.Add(CurLine);
        CurLine := Ch;
        CurW := ChW;
      end
      else
      begin
        CurLine := CurLine + Ch;
        CurW := CurW + ChW;
      end;
    end;
    if CurLine <> '' then
      Lines.Add(CurLine);
    Result := Lines.ToArray;
  finally
    Lines.Free;
  end;
end;

function TTextNode.Size(const AVal: Single): TTextNode;
begin
  FFontSize := AVal;
  Result := Self;
end;

function TTextNode.Color(const AColor: TAlphaColor): TTextNode;
begin
  FColor := AColor;
  Result := Self;
end;

function TTextNode.Bold(const AVal: Boolean): TTextNode;
begin
  FBold := AVal;
  Result := Self;
end;

function TTextNode.Strikethrough(const AVal: Boolean): TTextNode;
begin
  FStrikethrough := AVal;
  Result := Self;
end;

function TTextNode.MaxLines(const AVal: Integer): TTextNode;
begin
  FMaxLines := AVal;
  Result := Self;
end;

function TTextNode.Wrap(const AVal: Boolean): TTextNode;
begin
  FWrap := AVal;
  Result := Self;
end;

function TTextNode.Flex(const AVal: Single): TTextNode;
begin
  FFlex := AVal;
  Result := Self;
end;

function TTextNode.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
var
  LFont: ISkFont;
  Lines: TArray<string>;
  SingleLineH: Single;
begin
  LFont := AContext.Font(FFontSize, FBold);
  SingleLineH := AContext.GetFontHeight(LFont) + 2;

  if (not FWrap) or (AMaxWidth <= 0) then
  begin
    FDesiredSize := TSizeF.Create(LFont.MeasureText(FText), SingleLineH);
  end
  else
  begin
    Lines := SplitTextLines(FText, LFont, AMaxWidth);
    FDesiredSize := TSizeF.Create(AMaxWidth, Max(1, Length(Lines)) * SingleLineH);
  end;
  Result := FDesiredSize;
end;

procedure TTextNode.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
var
  LFont: ISkFont;
  LPaint: ISkPaint;
  BaselineY, LineH, CurY: Single;
  Lines: TArray<string>;
  I: Integer;
  M: TSkFontMetrics;
  TextW, StrikeY: Single;
begin
  if FText.IsEmpty or (FLayoutBounds.Width <= 0) or (FLayoutBounds.Height <= 0) then Exit;

  LFont := AContext.Font(FFontSize, FBold);
  LPaint := AContext.FillPaint(FColor);
  LFont.GetMetrics(M);
  LineH := AContext.GetFontHeight(LFont) + 2;

  if not FWrap then
  begin
    BaselineY := AContext.GetCenterBaseline(LFont, FLayoutBounds);
    if FMaxLines = 1 then
      AContext.DrawEllipsisText(ACanvas, FText, FLayoutBounds.Left, BaselineY,
        FLayoutBounds.Width, FFontSize, FColor, FBold)
    else
      AContext.DrawFastText(ACanvas, FText, FLayoutBounds, FFontSize, FColor, FBold, True, False);

    if FStrikethrough and (FLayoutBounds.Width > 0) then
    begin
      TextW := Min(LFont.MeasureText(FText), FLayoutBounds.Width);
      StrikeY := BaselineY + (M.Ascent * 0.35);
      ACanvas.DrawLine(PointF(FLayoutBounds.Left, StrikeY),
        PointF(FLayoutBounds.Left + TextW, StrikeY), AContext.StrokePaint(FColor, 1.0));
    end;
  end
  else
  begin
    Lines := SplitTextLines(FText, LFont, FLayoutBounds.Width);
    CurY := FLayoutBounds.Top - M.Ascent;
    for I := 0 to High(Lines) do
    begin
      if (I > 0) and (CurY + M.Descent > FLayoutBounds.Bottom + 6) then Break;
      ACanvas.DrawSimpleText(Lines[I], FLayoutBounds.Left, CurY, LFont, LPaint);
      CurY := CurY + LineH;
    end;
  end;
end;

{ TImageNode }

constructor TImageNode.Create(const AUrl: string; const AOwner: TObject);
begin
  inherited Create;
  FUrl := AUrl;
  FOwner := AOwner;
  FWidth := 0; // 默认 0，表示自适应撑满父容器分配宽度
  FHeight := 100;
  FFillWidth := True;
  FCornerRadius := 0;
  FImgRadiusTL := 0;
  FImgRadiusTR := 0;
  FImgRadiusBR := 0;
  FImgRadiusBL := 0;
  FPlaceholderColor := $FFF0F0F2;
  FBadgeText := '';
  FBadgeBgColor := $EBE6432E;
  FBadgeTextColor := TAlphaColors.White;
  FBadgeRadiusTL := 0;
  FBadgeRadiusTR := 0;
  FBadgeRadiusBR := 6;
  FBadgeRadiusBL := 0;
  FBadgeHeight := 16;
  FBadgeFontSize := 9;
  FBadgePaddingH := 5;
  FBadgeFloating := False;
  FBadgeFloatOffset := 4;
end;

function TImageNode.Width(const AVal: Single): TImageNode;
begin
  FWidth := AVal;
  FFillWidth := (AVal <= 0);
  Result := Self;
end;

function TImageNode.Height(const AVal: Single): TImageNode;
begin
  FHeight := AVal;
  Result := Self;
end;

function TImageNode.Size(const W, H: Single): TImageNode;
begin
  FWidth := W;
  FHeight := H;
  FFillWidth := (W <= 0);
  Result := Self;
end;

function TImageNode.FillWidth(const AVal: Boolean): TImageNode;
begin
  FFillWidth := AVal;
  if AVal then FWidth := 0;
  Result := Self;
end;

function TImageNode.Radius(const ARadius: Single): TImageNode;
begin
  FCornerRadius := ARadius;
  FImgRadiusTL := ARadius;
  FImgRadiusTR := ARadius;
  FImgRadiusBR := ARadius;
  FImgRadiusBL := ARadius;
  Result := Self;
end;

function TImageNode.Radius(const ATL, ATR, ABR, ABL: Single): TImageNode;
begin
  FImgRadiusTL := ATL;
  FImgRadiusTR := ATR;
  FImgRadiusBR := ABR;
  FImgRadiusBL := ABL;
  Result := Self;
end;

function TImageNode.RadiusTop(const ARadius: Single): TImageNode;
begin
  FImgRadiusTL := ARadius;
  FImgRadiusTR := ARadius;
  FImgRadiusBL := 0;
  FImgRadiusBR := 0;
  Result := Self;
end;

function TImageNode.Placeholder(const AColor: TAlphaColor): TImageNode;
begin
  FPlaceholderColor := AColor;
  Result := Self;
end;

function TImageNode.Badge(const AText: string; const ABgColor: TAlphaColor;
  const ARadiusBR, AHeight: Single): TImageNode;
begin
  FBadgeText := AText;
  FBadgeBgColor := ABgColor;
  FBadgeRadiusBR := ARadiusBR;
  FBadgeHeight := AHeight;
  Result := Self;
end;

function TImageNode.BadgeRadius(const AAll: Single): TImageNode;
begin
  FBadgeRadiusTL := AAll;
  FBadgeRadiusTR := AAll;
  FBadgeRadiusBR := AAll;
  FBadgeRadiusBL := AAll;
  Result := Self;
end;

function TImageNode.BadgeRadius(const ATL, ATR, ABR, ABL: Single): TImageNode;
begin
  FBadgeRadiusTL := ATL;
  FBadgeRadiusTR := ATR;
  FBadgeRadiusBR := ABR;
  FBadgeRadiusBL := ABL;
  Result := Self;
end;

function TImageNode.BadgeRadiusTopLeft(const AVal: Single): TImageNode;
begin
  FBadgeRadiusTL := AVal;
  Result := Self;
end;

function TImageNode.BadgeRadiusTopRight(const AVal: Single): TImageNode;
begin
  FBadgeRadiusTR := AVal;
  Result := Self;
end;

function TImageNode.BadgeRadiusBottomRight(const AVal: Single): TImageNode;
begin
  FBadgeRadiusBR := AVal;
  Result := Self;
end;

function TImageNode.BadgeRadiusBottomLeft(const AVal: Single): TImageNode;
begin
  FBadgeRadiusBL := AVal;
  Result := Self;
end;

function TImageNode.BadgeRadiusTL(const AVal: Single): TImageNode;
begin
  Result := BadgeRadiusTopLeft(AVal);
end;

function TImageNode.BadgeRadiusTR(const AVal: Single): TImageNode;
begin
  Result := BadgeRadiusTopRight(AVal);
end;

function TImageNode.BadgeRadiusBR(const AVal: Single): TImageNode;
begin
  Result := BadgeRadiusBottomRight(AVal);
end;

function TImageNode.BadgeRadiusBL(const AVal: Single): TImageNode;
begin
  Result := BadgeRadiusBottomLeft(AVal);
end;

function TImageNode.BadgeHeight(const AHeight: Single): TImageNode;
begin
  FBadgeHeight := AHeight;
  Result := Self;
end;

function TImageNode.BadgeFontSize(const ASize: Single): TImageNode;
begin
  FBadgeFontSize := ASize;
  Result := Self;
end;

function TImageNode.BadgePadding(const APaddingH: Single): TImageNode;
begin
  FBadgePaddingH := APaddingH;
  Result := Self;
end;

function TImageNode.BadgeColor(const AColor: TAlphaColor): TImageNode;
begin
  FBadgeBgColor := AColor;
  Result := Self;
end;

function TImageNode.BadgeTextColor(const AColor: TAlphaColor): TImageNode;
begin
  FBadgeTextColor := AColor;
  Result := Self;
end;

function TImageNode.BadgeFloating(const AIsFloating: Boolean; const AOffset: Single): TImageNode;
begin
  FBadgeFloating := AIsFloating;
  FBadgeFloatOffset := AOffset;
  if AIsFloating and (FBadgeRadiusTL = 0) and (FBadgeRadiusTR = 0) and (FBadgeRadiusBL = 0) and (FBadgeRadiusBR = 6) then
  begin
    FBadgeRadiusTL := 3;
    FBadgeRadiusTR := 3;
    FBadgeRadiusBR := 3;
    FBadgeRadiusBL := 3;
  end;
  Result := Self;
end;

function TImageNode.BottomBar(const AText: string; const ABgColor: TAlphaColor): TImageNode;
begin
  FBottomBarText := AText;
  FBottomBarBgColor := ABgColor;
  Result := Self;
end;

function TImageNode.Flex(const AVal: Single): TImageNode;
begin
  FFlex := AVal;
  Result := Self;
end;

function TImageNode.OnClick(const AZoneID: Integer): TImageNode;
begin
  FZoneID := AZoneID;
  Result := Self;
end;

function TImageNode.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
begin
  if (FWidth > 0) and (not FFillWidth) then
    FDesiredSize := TSizeF.Create(FWidth, FHeight)
  else
    FDesiredSize := TSizeF.Create(AMaxWidth, FHeight);
  Result := FDesiredSize;
end;

procedure TImageNode.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
var
  LImg: ISkImage;
  RRect: TSkRoundRect;
  LRadii: TSkRoundRectRadii;
  LFont: ISkFont;
  Baseline, TextW, TextX: Single;
  TagW, TagH: Single;
  TagRect, BarRect, SrcRect: TRectF;
  SrcW, SrcH, DstW, DstH, Scale, CropW, CropH: Single;
begin
  if (FLayoutBounds.Width <= 0) or (FLayoutBounds.Height <= 0) then Exit;

  // 1. 尝试从二级缓存加载
  LImg := TSkImageCache.GetImage(FUrl, FOwner, procedure
  begin
    if (AContext <> nil) and Assigned(AContext.OnNeedRedraw) then
      AContext.OnNeedRedraw()
    else if (FOwner <> nil) and (FOwner is TSkVirtualListView) then
      TSkVirtualListView(FOwner).Redraw;
  end);

  ACanvas.Save;
  try
    if (FImgRadiusTL > 0) or (FImgRadiusTR > 0) or (FImgRadiusBR > 0) or (FImgRadiusBL > 0) then
    begin
      FillChar(LRadii, SizeOf(LRadii), 0);
      LRadii[TSkRoundRectCorner.UpperLeft]  := PointF(FImgRadiusTL, FImgRadiusTL);
      LRadii[TSkRoundRectCorner.UpperRight] := PointF(FImgRadiusTR, FImgRadiusTR);
      LRadii[TSkRoundRectCorner.LowerRight] := PointF(FImgRadiusBR, FImgRadiusBR);
      LRadii[TSkRoundRectCorner.LowerLeft]  := PointF(FImgRadiusBL, FImgRadiusBL);
      ACanvas.ClipRoundRect(TSkRoundRect.Create(FLayoutBounds, LRadii), TSkClipOp.Intersect, True);
    end
    else if FCornerRadius > 0 then
    begin
      RRect := TSkRoundRect.Create(FLayoutBounds, FCornerRadius, FCornerRadius);
      ACanvas.ClipRoundRect(RRect, TSkClipOp.Intersect, True);
    end;

    if LImg <> nil then
    begin
      // 居中等比撑满裁剪（Cover / Center Crop），消除拉伸走样变形
      SrcW := LImg.Width;
      SrcH := LImg.Height;
      DstW := FLayoutBounds.Width;
      DstH := FLayoutBounds.Height;
      if (SrcW > 0) and (SrcH > 0) and (DstW > 0) and (DstH > 0) then
      begin
        Scale := Max(DstW / SrcW, DstH / SrcH);
        CropW := DstW / Scale;
        CropH := DstH / Scale;
        SrcRect := RectF(
          Max(0, (SrcW - CropW) / 2),
          Max(0, (SrcH - CropH) / 2),
          Min(SrcW, (SrcW + CropW) / 2),
          Min(SrcH, (SrcH + CropH) / 2)
        );
        ACanvas.DrawImageRect(LImg, SrcRect, FLayoutBounds);
      end
      else
        ACanvas.DrawImageRect(LImg, FLayoutBounds);
    end
    else
      ACanvas.DrawRect(FLayoutBounds, AContext.FillPaint(FPlaceholderColor));

    // 左上角专享/补贴标签（支持贴边单角圆角与浮动模式）
    if not FBadgeText.IsEmpty then
    begin
      LFont := AContext.Font(FBadgeFontSize, True);
      TextW := LFont.MeasureText(FBadgeText);
      TagW := TextW + FBadgePaddingH * 2;
      TagH := FBadgeHeight;

      if FBadgeFloating then
      begin
        TagRect := RectF(FLayoutBounds.Left + FBadgeFloatOffset,
                         FLayoutBounds.Top + FBadgeFloatOffset,
                         FLayoutBounds.Left + FBadgeFloatOffset + TagW,
                         FLayoutBounds.Top + FBadgeFloatOffset + TagH);
      end
      else
      begin
        TagRect := RectF(FLayoutBounds.Left,
                         FLayoutBounds.Top,
                         FLayoutBounds.Left + TagW,
                         FLayoutBounds.Top + TagH);
      end;

      FillChar(LRadii, SizeOf(LRadii), 0);
      LRadii[TSkRoundRectCorner.UpperLeft]  := PointF(FBadgeRadiusTL, FBadgeRadiusTL);
      LRadii[TSkRoundRectCorner.UpperRight] := PointF(FBadgeRadiusTR, FBadgeRadiusTR);
      LRadii[TSkRoundRectCorner.LowerRight] := PointF(FBadgeRadiusBR, FBadgeRadiusBR);
      LRadii[TSkRoundRectCorner.LowerLeft]  := PointF(FBadgeRadiusBL, FBadgeRadiusBL);
      ACanvas.DrawRoundRect(TSkRoundRect.Create(TagRect, LRadii), AContext.FillPaint(FBadgeBgColor));

      Baseline := AContext.GetCenterBaseline(LFont, TagRect);
      ACanvas.DrawSimpleText(FBadgeText, TagRect.Left + FBadgePaddingH, Baseline, LFont,
        AContext.FillPaint(FBadgeTextColor));
    end;

    // 底部全宽半透明保障标签横条（如：假一赔十 / 破损包赔 / 冷链配送）
    if not FBottomBarText.IsEmpty then
    begin
      BarRect := RectF(FLayoutBounds.Left, FLayoutBounds.Bottom - 18,
        FLayoutBounds.Right, FLayoutBounds.Bottom);
      ACanvas.DrawRect(BarRect, AContext.FillPaint(FBottomBarBgColor));

      LFont := AContext.Font(9.0, False);
      Baseline := AContext.GetCenterBaseline(LFont, BarRect);
      TextW := LFont.MeasureText(FBottomBarText);
      TextX := BarRect.Left + Max(0, (BarRect.Width - TextW) / 2);
      ACanvas.DrawSimpleText(FBottomBarText, TextX, Baseline, LFont,
        AContext.FillPaint(TAlphaColors.White));
    end;
  finally
    ACanvas.Restore;
  end;
end;

{ TCarouselNode }

constructor TCarouselNode.Create(const AImages: array of string; const AOwner: TObject);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FImages, Length(AImages));
  for I := 0 to High(AImages) do
    FImages[I] := AImages[I];
  FOwner := AOwner;
  FActiveIndex := 0;
  FScrollOffset := 0;
  FWidth := 0;
  FHeight := 100;
  FFillWidth := True;
  FCornerRadius := 0;
  FPlaceholderColor := $FFF0F0F2;
  FBadgeText := '';
  FBadgeBgColor := $EBE6432E;
  FBadgeTextColor := TAlphaColors.White;
  FBadgeRadiusBR := 6;
  FBadgeHeight := 16;
  FBadgeFontSize := 9;
  FBadgePaddingH := 5;
  FBottomBarText := '';
  FBottomBarBgColor := $B0202022;
  FShowIndicator := True;
  FAutoCruise := True;
end;

constructor TCarouselNode.Create(const AImages: TArray<string>; const AOwner: TObject);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FImages, Length(AImages));
  for I := 0 to High(AImages) do
    FImages[I] := AImages[I];
  FOwner := AOwner;
  FActiveIndex := 0;
  FScrollOffset := 0;
  FWidth := 0;
  FHeight := 100;
  FFillWidth := True;
  FCornerRadius := 0;
  FPlaceholderColor := $FFF0F0F2;
  FBadgeText := '';
  FBadgeBgColor := $EBE6432E;
  FBadgeTextColor := TAlphaColors.White;
  FBadgeRadiusBR := 6;
  FBadgeHeight := 16;
  FBadgeFontSize := 9;
  FBadgePaddingH := 5;
  FBottomBarText := '';
  FBottomBarBgColor := $B0202022;
  FShowIndicator := True;
  FAutoCruise := True;
end;

function TCarouselNode.AutoCruise(const AVal: Boolean): TCarouselNode;
begin
  FAutoCruise := AVal;
  Result := Self;
end;

function TCarouselNode.Width(const AVal: Single): TCarouselNode;
begin
  FWidth := AVal;
  FFillWidth := (AVal <= 0);
  Result := Self;
end;

function TCarouselNode.Height(const AVal: Single): TCarouselNode;
begin
  FHeight := AVal;
  Result := Self;
end;

function TCarouselNode.Size(const W, H: Single): TCarouselNode;
begin
  FWidth := W;
  FHeight := H;
  FFillWidth := (W <= 0);
  Result := Self;
end;

function TCarouselNode.FillWidth(const AVal: Boolean): TCarouselNode;
begin
  FFillWidth := AVal;
  Result := Self;
end;

function TCarouselNode.Radius(const ARadius: Single): TCarouselNode;
begin
  FCornerRadius := ARadius;
  Result := Self;
end;

function TCarouselNode.ActiveIndex(const AIndex: Integer): TCarouselNode;
begin
  FActiveIndex := AIndex;
  Result := Self;
end;

function TCarouselNode.ScrollOffset(const AOffset: Single): TCarouselNode;
begin
  FScrollOffset := AOffset;
  Result := Self;
end;

function TCarouselNode.Badge(const AText: string; const ABgColor: TAlphaColor;
  const ARadiusBR, AHeight: Single): TCarouselNode;
begin
  FBadgeText := AText;
  FBadgeBgColor := ABgColor;
  FBadgeRadiusBR := ARadiusBR;
  FBadgeHeight := AHeight;
  Result := Self;
end;

function TCarouselNode.BottomBar(const AText: string; const ABgColor: TAlphaColor): TCarouselNode;
begin
  FBottomBarText := AText;
  FBottomBarBgColor := ABgColor;
  Result := Self;
end;

function TCarouselNode.ShowIndicator(const AVal: Boolean): TCarouselNode;
begin
  FShowIndicator := AVal;
  Result := Self;
end;

function TCarouselNode.Flex(const AVal: Single): TCarouselNode;
begin
  FFlex := AVal;
  Result := Self;
end;

function TCarouselNode.OnClick(const AZoneID: Integer): TCarouselNode;
begin
  FZoneID := AZoneID;
  Result := Self;
end;

function TCarouselNode.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
begin
  if (FWidth > 0) and (not FFillWidth) then
    FDesiredSize := TSizeF.Create(FWidth, FHeight)
  else
    FDesiredSize := TSizeF.Create(AMaxWidth, FHeight);
  Result := FDesiredSize;
end;

procedure TCarouselNode.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
var
  I: Integer;
  ImgW, ImgH, BaseOffsetX, CurLeft, CurRight: Single;
  CurImgRect, SrcRect, TagRect, BarRect: TRectF;
  LImg: ISkImage;
  RRect: TSkRoundRect;
  LRadii: TSkRoundRectRadii;
  LFont: ISkFont;
  Baseline, TextW, TextX, TagW, TagH: Single;
  SrcW, SrcH, DstW, DstH, Scale, CropW, CropH: Single;
  PodW, PodH, PodY, CurItemX, ItemY, ActiveW, InactiveW, ItemGap, PadX: Single;
  PodRect, ItemRect: TRectF;
begin
  if (FLayoutBounds.Width <= 0) or (FLayoutBounds.Height <= 0) then Exit;
  if Length(FImages) = 0 then Exit;

  ImgW := FLayoutBounds.Width;
  ImgH := FLayoutBounds.Height;

  ACanvas.Save;
  try
    // 1. 裁剪外层圆角
    if FCornerRadius > 0 then
    begin
      RRect := TSkRoundRect.Create(FLayoutBounds, FCornerRadius, FCornerRadius);
      ACanvas.ClipRoundRect(RRect, TSkClipOp.Intersect, True);
    end;

    // 2. 计算基准 X 偏移量
    BaseOffsetX := -(FActiveIndex * ImgW) + FScrollOffset;

    // 3. 绘制落在可视边界内的图片
    for I := 0 to High(FImages) do
    begin
      CurLeft := FLayoutBounds.Left + BaseOffsetX + (I * ImgW);
      CurRight := CurLeft + ImgW;

      if (CurRight > FLayoutBounds.Left) and (CurLeft < FLayoutBounds.Right) then
      begin
        CurImgRect := RectF(CurLeft, FLayoutBounds.Top, CurRight, FLayoutBounds.Bottom);
        LImg := TSkImageCache.GetImage(FImages[I], FOwner, procedure
        begin
          if (AContext <> nil) and Assigned(AContext.OnNeedRedraw) then
            AContext.OnNeedRedraw()
          else if (FOwner <> nil) and (FOwner is TSkVirtualListView) then
            TSkVirtualListView(FOwner).Redraw;
        end);

        if LImg <> nil then
        begin
          SrcW := LImg.Width;
          SrcH := LImg.Height;
          DstW := CurImgRect.Width;
          DstH := CurImgRect.Height;
          if (SrcW > 0) and (SrcH > 0) and (DstW > 0) and (DstH > 0) then
          begin
            Scale := Max(DstW / SrcW, DstH / SrcH);
            CropW := DstW / Scale;
            CropH := DstH / Scale;
            SrcRect := RectF(
              Max(0, (SrcW - CropW) / 2),
              Max(0, (SrcH - CropH) / 2),
              Min(SrcW, (SrcW + CropW) / 2),
              Min(SrcH, (SrcH + CropH) / 2)
            );
            ACanvas.DrawImageRect(LImg, SrcRect, CurImgRect);
          end
          else
            ACanvas.DrawImageRect(LImg, CurImgRect);
        end
        else
          ACanvas.DrawRect(CurImgRect, AContext.FillPaint(FPlaceholderColor));
      end;
    end;

    // 3.1 预热加载相邻下一张轮播图片，保障自动巡航与手势滑切时 0 延迟、0 白屏
    if Length(FImages) > 1 then
    begin
      TSkImageCache.GetImage(FImages[(FActiveIndex + 1) mod Length(FImages)], FOwner, procedure
      begin
        if (AContext <> nil) and Assigned(AContext.OnNeedRedraw) then
          AContext.OnNeedRedraw()
        else if (FOwner <> nil) and (FOwner is TSkVirtualListView) then
          TSkVirtualListView(FOwner).Redraw;
      end);
    end;

    // 4. 底部现代胶囊分页指示器 (半透明黑底胶囊 + 灵动亮白长条)
    if FShowIndicator and (Length(FImages) > 1) then
    begin
      ActiveW := 9.0;
      InactiveW := 3.0;
      ItemGap := 3.5;
      PadX := 5.0;
      PodH := 9.5;

      // 内部项目总宽度：1 个长条 + (N-1) 个圆点 + (N-1) 个间距
      PodW := ActiveW + (Length(FImages) - 1) * (InactiveW + ItemGap) + (PadX * 2);

      if not FBottomBarText.IsEmpty then
        PodY := FLayoutBounds.Bottom - 18 - 3 - PodH
      else
        PodY := FLayoutBounds.Bottom - 6 - PodH;

      PodRect := RectF(
        FLayoutBounds.CenterPoint.X - (PodW / 2),
        PodY,
        FLayoutBounds.CenterPoint.X + (PodW / 2),
        PodY + PodH
      );

      // 4.1 绘制半透明黑底胶囊底托（消除任何背景浅色图片干扰）
      ACanvas.DrawRoundRect(TSkRoundRect.Create(PodRect, PodH / 2, PodH / 2),
        AContext.FillPaint($59000000));

      // 4.2 依次排布指示条与小圆点
      CurItemX := PodRect.Left + PadX;
      ItemY := PodRect.Top + (PodH - InactiveW) / 2;

      for I := 0 to High(FImages) do
      begin
        if I = FActiveIndex then
        begin
          ItemRect := RectF(CurItemX, ItemY, CurItemX + ActiveW, ItemY + InactiveW);
          ACanvas.DrawRoundRect(TSkRoundRect.Create(ItemRect, InactiveW / 2, InactiveW / 2),
            AContext.FillPaint(TAlphaColors.White));
          CurItemX := CurItemX + ActiveW + ItemGap;
        end
        else
        begin
          ItemRect := RectF(CurItemX, ItemY, CurItemX + InactiveW, ItemY + InactiveW);
          ACanvas.DrawRoundRect(TSkRoundRect.Create(ItemRect, InactiveW / 2, InactiveW / 2),
            AContext.FillPaint($8CFFFFFF));
          CurItemX := CurItemX + InactiveW + ItemGap;
        end;
      end;
    end;

    // 5. 左上角专享/补贴标签
    if not FBadgeText.IsEmpty then
    begin
      LFont := AContext.Font(FBadgeFontSize, True);
      TextW := LFont.MeasureText(FBadgeText);
      TagW := TextW + FBadgePaddingH * 2;
      TagH := FBadgeHeight;
      TagRect := RectF(FLayoutBounds.Left, FLayoutBounds.Top, FLayoutBounds.Left + TagW, FLayoutBounds.Top + TagH);

      FillChar(LRadii, SizeOf(LRadii), 0);
      LRadii[TSkRoundRectCorner.LowerRight] := PointF(FBadgeRadiusBR, FBadgeRadiusBR);
      ACanvas.DrawRoundRect(TSkRoundRect.Create(TagRect, LRadii),
        AContext.FillPaint(FBadgeBgColor));

      Baseline := AContext.GetCenterBaseline(LFont, TagRect);
      TextX := TagRect.Left + FBadgePaddingH;
      ACanvas.DrawSimpleText(FBadgeText, TextX, Baseline, LFont, AContext.FillPaint(FBadgeTextColor));
    end;

    // 6. 底部半透明横条
    if not FBottomBarText.IsEmpty then
    begin
      BarRect := RectF(FLayoutBounds.Left, FLayoutBounds.Bottom - 18, FLayoutBounds.Right, FLayoutBounds.Bottom);
      ACanvas.DrawRect(BarRect, AContext.FillPaint(FBottomBarBgColor));

      LFont := AContext.Font(9.0, False);
      Baseline := AContext.GetCenterBaseline(LFont, BarRect);
      TextW := LFont.MeasureText(FBottomBarText);
      TextX := BarRect.Left + Max(0, (BarRect.Width - TextW) / 2);
      ACanvas.DrawSimpleText(FBottomBarText, TextX, Baseline, LFont, AContext.FillPaint(TAlphaColors.White));
    end;
  finally
    ACanvas.Restore;
  end;
end;

{ TSvgNode }

constructor TSvgNode.Create(const ASvgPath: string);
begin
  inherited Create;
  FSvgPath := ASvgPath;
  FWidth := 16;
  FHeight := 16;
  FColor := $FF333333;
end;

function TSvgNode.Size(const W, H: Single): TSvgNode;
begin
  FWidth := W;
  FHeight := H;
  Result := Self;
end;

function TSvgNode.Color(const AColor: TAlphaColor): TSvgNode;
begin
  FColor := AColor;
  Result := Self;
end;

function TSvgNode.OnClick(const AZoneID: Integer): TSvgNode;
begin
  FZoneID := AZoneID;
  Result := Self;
end;

function TSvgNode.Flex(const AVal: Single): TSvgNode;
begin
  FFlex := AVal;
  Result := Self;
end;

function TSvgNode.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
begin
  FDesiredSize := TSizeF.Create(FWidth, FHeight);
  Result := FDesiredSize;
end;

procedure TSvgNode.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
begin
  AContext.DrawSvgPath(ACanvas, FSvgPath, FLayoutBounds, FColor);
end;

{ TCircleNode }

constructor TCircleNode.Create(const ARadius: Single);
begin
  inherited Create;
  FRadius := ARadius;
  FFillColor := 0;
  FStrokeColor := 0;
  FStrokeWidth := 0;
end;

function TCircleNode.Fill(const AColor: TAlphaColor): TCircleNode;
begin
  FFillColor := AColor;
  Result := Self;
end;

function TCircleNode.Stroke(const AColor: TAlphaColor; const AWidth: Single): TCircleNode;
begin
  FStrokeColor := AColor;
  FStrokeWidth := AWidth;
  Result := Self;
end;

function TCircleNode.OnClick(const AZoneID: Integer): TCircleNode;
begin
  FZoneID := AZoneID;
  Result := Self;
end;

function TCircleNode.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
begin
  FDesiredSize := TSizeF.Create(FRadius * 2, FRadius * 2);
  Result := FDesiredSize;
end;

procedure TCircleNode.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
var
  Center: TPointF;
begin
  Center := FLayoutBounds.CenterPoint;
  if FFillColor <> 0 then
    ACanvas.DrawCircle(Center, FRadius, AContext.FillPaint(FFillColor));
  if (FStrokeColor <> 0) and (FStrokeWidth > 0) then
    ACanvas.DrawCircle(Center, FRadius, AContext.StrokePaint(FStrokeColor, FStrokeWidth));
end;

{ TBadgeNode }

constructor TBadgeNode.Create(const AText: string);
begin
  inherited Create;
  FText := AText;
  FFontSize := 9.5;
  FTextColor := $FFE6432E;
  FFillColor := 0;
  FStrokeColor := $FFF3B8AE;
  FStrokeWidth := 1;
  FCornerRadius := 2;
  FPaddingH := 4;
  FPaddingV := 1.5;
end;

function TBadgeNode.TextColor(const AColor: TAlphaColor): TBadgeNode;
begin
  FTextColor := AColor;
  Result := Self;
end;

function TBadgeNode.Fill(const AColor: TAlphaColor): TBadgeNode;
begin
  FFillColor := AColor;
  Result := Self;
end;

function TBadgeNode.Stroke(const AColor: TAlphaColor; const AWidth: Single): TBadgeNode;
begin
  FStrokeColor := AColor;
  FStrokeWidth := AWidth;
  Result := Self;
end;

function TBadgeNode.Radius(const ARadius: Single): TBadgeNode;
begin
  FCornerRadius := ARadius;
  Result := Self;
end;

function TBadgeNode.FontSize(const ASize: Single): TBadgeNode;
begin
  FFontSize := ASize;
  Result := Self;
end;

function TBadgeNode.Padding(const H, V: Single): TBadgeNode;
begin
  FPaddingH := H;
  FPaddingV := V;
  Result := Self;
end;

function TBadgeNode.Measure(AContext: TSkRenderContext; AMaxWidth, AMaxHeight: Single): TSizeF;
var
  LFont: ISkFont;
  TextW, TextH: Single;
begin
  LFont := AContext.Font(FFontSize, False);
  TextW := LFont.MeasureText(FText);
  TextH := AContext.GetFontHeight(LFont);
  FDesiredSize := TSizeF.Create(TextW + (FPaddingH * 2), TextH + (FPaddingV * 2));
  Result := FDesiredSize;
end;

procedure TBadgeNode.Draw(const ACanvas: ISkCanvas; AContext: TSkRenderContext);
var
  RRect: TSkRoundRect;
  LFont: ISkFont;
  BaselineY: Single;
begin
  if FLayoutBounds.Width <= 0 then Exit;

  RRect := TSkRoundRect.Create(FLayoutBounds, FCornerRadius, FCornerRadius);
  if FFillColor <> 0 then
    ACanvas.DrawRoundRect(RRect, AContext.FillPaint(FFillColor));
  if (FStrokeColor <> 0) and (FStrokeWidth > 0) then
    ACanvas.DrawRoundRect(RRect, AContext.StrokePaint(FStrokeColor, FStrokeWidth));

  LFont := AContext.Font(FFontSize, False);
  BaselineY := AContext.GetCenterBaseline(LFont, FLayoutBounds);
  ACanvas.DrawSimpleText(FText, FLayoutBounds.Left + FPaddingH, BaselineY, LFont, AContext.FillPaint(FTextColor));
end;

{ TDeclarativeCardRenderer }

constructor TDeclarativeCardRenderer.Create(const ASpanCount: Integer; const AItemHeight: Single);
begin
  inherited Create;
  FSpanCount := Max(1, ASpanCount);
  FItemHeight := AItemHeight;
  FCache := TDictionary<TObject, TCachedLayout>.Create;
end;

destructor TDeclarativeCardRenderer.Destroy;
begin
  FCache.Free;
  inherited Destroy;
end;

procedure TDeclarativeCardRenderer.ClearCache;
begin
  FCache.Clear;
end;

function TDeclarativeCardRenderer.GetSpanCount: Integer;
begin
  Result := FSpanCount;
end;

function TDeclarativeCardRenderer.GetItemHeight(AContext: TSkRenderContext; AColWidth: Single; AItem: TObject = nil): Single;
begin
  Result := FItemHeight;
end;

function TDeclarativeCardRenderer.HitTestCard(AItem: TObject; const ARect: TRectF; const APoint: TPointF): Integer;
var
  LayoutCache: TCachedLayout;
  LocalPt: TPointF;
begin
  Result := 0;
  if (AItem <> nil) and FCache.TryGetValue(AItem, LayoutCache) and (LayoutCache.Node <> nil) then
  begin
    LocalPt := PointF(APoint.X - ARect.Left, APoint.Y - ARect.Top);
    Result := LayoutCache.Node.HitTest(LocalPt);
  end;
end;

procedure TDeclarativeCardRenderer.DrawCard(const ACanvas: ISkCanvas; AContext: TSkRenderContext;
  AItem: TObject; const ARect: TRectF; AIsPressed: Boolean; APressedZoneID: Integer);
var
  LayoutCache: TCachedLayout;
  W, H: Single;
  ZoneBounds: TRectF;
  ZoneRadius: Single;
begin
  if AItem = nil then Exit;
  W := ARect.Width;
  H := ARect.Height;

  // 检查是否已有缓存且尺寸完全一致
  if not FCache.TryGetValue(AItem, LayoutCache) or
     (Abs(LayoutCache.Width - W) > 0.5) or
     (Abs(LayoutCache.Height - H) > 0.5) then
  begin
    LayoutCache.Node := BuildLayout(AItem);
    if LayoutCache.Node = nil then Exit;

    // 以卡片局部原点 (0, 0, W, H) 执行唯一的度量与排版计算
    LayoutCache.Node.Measure(AContext, W, H);
    LayoutCache.Node.Layout(RectF(0, 0, W, H));
    LayoutCache.Width := W;
    LayoutCache.Height := H;
    FCache.AddOrSetValue(AItem, LayoutCache);
  end;

  if LayoutCache.Node = nil then Exit;

  // 120 FPS 高速滚动时直接在视口坐标处平移绘制已排版完成的节点树，彻底消除堆内存分配
  ACanvas.Save;
  try
    ACanvas.Translate(ARect.Left, ARect.Top);
    LayoutCache.Node.Draw(ACanvas, AContext);

    // 通用零硬编码按压微反馈：支持任何颜色、任何位置与形状的按钮与卡片
    if AIsPressed then
    begin
      if (APressedZoneID <> 0) and LayoutCache.Node.FindZone(APressedZoneID, ZoneBounds, ZoneRadius) then
      begin
        // 精准命中的子热区按钮（叠加 15% 半透明纯黑遮罩，使任意原色自然变暗加深 15%）
        ACanvas.DrawRoundRect(TSkRoundRect.Create(ZoneBounds, ZoneRadius, ZoneRadius),
          AContext.FillPaint($26000000));
      end
      else
      begin
        // 整张卡片主体按下：覆盖 4% 浅灰阴影
        ACanvas.DrawRoundRect(TSkRoundRect.Create(RectF(0, 0, W, H), 8, 8),
          AContext.FillPaint($0A000000));
      end;
    end;
  finally
    ACanvas.Restore;
  end;
end;

function TDeclarativeCardRenderer.CanSwipeImage(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean;
begin
  AWidth := 0;
  Result := False;
end;

function TDeclarativeCardRenderer.CanAutoCruise(AItem: TObject; AZoneID: Integer; out AWidth: Single): Boolean;
begin
  Result := CanSwipeImage(AItem, AZoneID, AWidth);
end;

procedure TDeclarativeCardRenderer.OnImageSwipe(AItem: TObject; const ADeltaX: Single);
begin
  if AItem <> nil then
    FCache.Remove(AItem);
end;

procedure TDeclarativeCardRenderer.OnImageSwipeEnd(AItem: TObject; const ADeltaX, AImgWidth: Single);
begin
  if AItem <> nil then
    FCache.Remove(AItem);
end;

function TDeclarativeCardRenderer.ResolveSwipeTarget(AItem: TObject; const ADeltaX, AImgWidth: Single;
  out ATargetOffset: Single; out AIndexDelta: Integer): Boolean;
begin
  ATargetOffset := 0;
  AIndexDelta := 0;
  Result := False;
end;

procedure TDeclarativeCardRenderer.OnImageSwipeFinished(AItem: TObject; const AIndexDelta: Integer);
begin
  if AItem <> nil then
    FCache.Remove(AItem);
end;

end.
