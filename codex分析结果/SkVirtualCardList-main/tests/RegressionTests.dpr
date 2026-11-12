program RegressionTests;

{$APPTYPE CONSOLE}
{$ASSERTIONS ON}

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.Skia,
  FMX.Forms, FMX.Skia, FMX.StdCtrls,
  SkAsync in '../SkAsync.pas',
  SkImageCache in '../SkImageCache.pas',
  SkVirtualList.Core in '../SkVirtualList.Core.pas',
  SkUiDsl in '../SkUiDsl.pas',
  SkCardRenderers.Biz in '../SkCardRenderers.Biz.pas',
  Biz.OrderModel in '../Biz.OrderModel.pas',
  Biz.OrderRenderer in '../Biz.OrderRenderer.pas',
  Unit1 in '../Unit1.pas';

type
  TCountingRenderer = class(TSingleProductCardRenderer)
  public
    Builds: Integer;
    HeightMeasures: Integer;
    function GetItemHeight(AContext: TSkRenderContext; AColWidth: Single;
      AItem: TObject = nil): Single; override;
    function BuildLayout(AItem: TObject): IUiNode; override;
  end;

function TCountingRenderer.GetItemHeight(AContext: TSkRenderContext;
  AColWidth: Single; AItem: TObject): Single;
begin
  Inc(HeightMeasures);
  Result := inherited GetItemHeight(AContext, AColWidth, AItem);
end;

function TCountingRenderer.BuildLayout(AItem: TObject): IUiNode;
begin
  Inc(Builds);
  Result := inherited BuildLayout(AItem);
end;

procedure TestFailedFetch;
var
  List: TSkVirtualListView;
begin
  List := TSkVirtualListView.Create(nil);
  try
    List.PageIndex := 2;
    List.HasMore := True;
    List.IsLoadingMore := True;
    List.FinishFetch(False, False);
    Assert(List.HasMore, 'A failed request must remain retryable');
    Assert(List.PageIndex = 2, 'A failed request must retain its page');
    Assert(not List.IsLoadingMore, 'A failed request must release its loading flag');
    List.IsLoadingMore := True;
    List.FinishFetch(0, False);
    Assert(List.HasMore, 'The item-count overload must also retain HasMore on failure');
    List.IsLoadingMore := True;
    List.Clear;
    Assert(not List.IsLoadingMore, 'Clear must reset the loading state');
  finally
    List.Free;
  end;
end;

procedure TestIncrementalFetch;
var
  List: TSkVirtualListView;
  Renderer: ISkCardRenderer;
  Counter: TCountingRenderer;
  I: Integer;
begin
  Counter := TCountingRenderer.Create;
  Renderer := Counter;
  List := TSkVirtualListView.Create(nil);
  try
    List.Width := 400;
    List.Renderer := Renderer;
    for I := 1 to 3 do List.Items.Add(TProductItem.Create);
    List.UpdateLayout;
    Counter.HeightMeasures := 0;
    for I := 1 to 2 do List.Items.Add(TProductItem.Create);
    List.IsLoadingMore := True;
    List.FinishFetch(True, False);
    Assert(Counter.HeightMeasures = 2, 'Boolean FinishFetch must measure only appended items');
  finally
    List.Free;
  end;
end;

procedure TestTextLimit;
var
  Context: TSkRenderContext;
  Node: IUiNode;
  OneLine, Limited, Unlimited: TSizeF;
begin
  Context := TSkRenderContext.Create;
  try
    Node := SkText('x').Wrap(True);
    OneLine := Node.Measure(Context, 40, 1000);
    Node := SkText(StringOfChar('x', 200)).MaxLines(2);
    Limited := Node.Measure(Context, 40, 1000);
    Assert(SameValue(Limited.cy, OneLine.cy * 2, 0.1), 'MaxLines(2) must measure two lines');
    Node := SkText(StringOfChar('x', 200)).Wrap(True);
    Unlimited := Node.Measure(Context, 40, 1000);
    Assert(Unlimited.cy > Limited.cy, 'Wrap alone must retain unlimited address lines');
  finally
    Context.Free;
  end;
end;

procedure TestCarouselLayoutReuse;
var
  Context: TSkRenderContext;
  Renderer: ISkCardRenderer;
  Counter: TCountingRenderer;
  Product: TProductItem;
  Surface: ISkSurface;
  I: Integer;
begin
  Context := TSkRenderContext.Create;
  Product := TProductItem.Create;
  Counter := TCountingRenderer.Create;
  Renderer := Counter;
  try
    // Empty URLs avoid network I/O; the real card still contains a carousel node.
    Product.Images := ['', '', ''];
    Surface := TSkSurface.MakeRaster(400, 200);
    Renderer.DrawCard(Surface.Canvas, Context, Product, RectF(0, 0, 400, 142), False, 0);
    for I := 1 to 10 do
    begin
      Renderer.OnImageSwipe(Product, -I * 5);
      Renderer.DrawCard(Surface.Canvas, Context, Product, RectF(0, 0, 400, 142), False, 0);
    end;
    Renderer.OnImageSwipeFinished(Product, 1);
    Renderer.DrawCard(Surface.Canvas, Context, Product, RectF(0, 0, 400, 142), False, 0);
    Assert(Counter.Builds = 1, 'Carousel animation must reuse the card layout');
    Renderer.ClearItemCache(Product);
    Renderer.DrawCard(Surface.Canvas, Context, Product, RectF(0, 0, 400, 142), False, 0);
    Assert(Counter.Builds = 2, 'A data change must still rebuild the card');
  finally
    Renderer := nil;
    Product.Free;
    Context.Free;
  end;
end;

procedure ProcessFor(const Milliseconds: Cardinal);
var
  Deadline: UInt64;
begin
  Deadline := TThread.GetTickCount64 + Milliseconds;
  repeat
    Application.ProcessMessages;
    CheckSynchronize(0);
    TThread.Sleep(5);
  until TThread.GetTickCount64 >= Deadline;
end;

procedure TestModeAndRequestLifetime;
var
  Form: TForm1;
  List: TSkVirtualListView;
  OrderButton: TButton;
  I: Integer;
begin
  Form := TForm1.Create(nil);
  try
    // Keep the form hidden: this checks real events without downloading images.
    Form.Hide;
    List := nil;
    OrderButton := nil;
    for I := 0 to Form.ComponentCount - 1 do
    begin
      if Form.Components[I] is TSkVirtualListView then
        List := TSkVirtualListView(Form.Components[I]);
      if (Form.Components[I] is TButton) and
         (TButton(Form.Components[I]).Text = #$8BA2#$5355) then
        OrderButton := TButton(Form.Components[I]);
    end;
    Assert((List <> nil) and (OrderButton <> nil), 'Demo components must exist');
    OrderButton.OnClick(OrderButton);
    ProcessFor(750);
    Assert((List.Items.Count = 5) and (List.Items[0] is TOrder),
      'The delayed initial mixed load must not overwrite the selected mode');

    List.IsLoadingMore := True;
    List.OnPageFetch(List, 2, False);
    OrderButton.OnClick(OrderButton);
    ProcessFor(750);
    Assert((List.Items.Count = 5) and (List.PageIndex = 1),
      'An old page must not be appended after a mode reload');

    List.IsLoadingMore := True;
    List.OnPageFetch(List, 2, False);
  finally
    Form.Free;
  end;
  ProcessFor(500); // The pending callback must release results without touching the freed form.
end;

procedure TestFinallyAfterCallbackException;
var
  Promise: IAsyncPromise<Integer>;
  Done: Boolean;
  Deadline: UInt64;
begin
  Done := False;
  Promise := TAsync.Run<Integer>(function: Integer
    begin
      Result := 1;
    end)
    .OnSuccess(procedure(Value: Integer)
    begin
      raise EAbort.Create('test callback error');
    end)
    .&Finally(procedure
    begin
      Done := True;
    end);
  Deadline := TThread.GetTickCount64 + 5000;
  repeat
    try
      CheckSynchronize(10);
    except
      on E: EAbort do ;
    end;
  until Done or (TThread.GetTickCount64 >= Deadline);
  Assert(Done, 'Finally must run even when a completion callback raises');
end;

begin
  try
    GlobalUseSkia := True;
    Application.Initialize;
    TestFailedFetch;
    TestIncrementalFetch;
    TestTextLimit;
    TestCarouselLayoutReuse;
    TestModeAndRequestLifetime;
    TestFinallyAfterCallbackException;
    Writeln('All regression tests passed.');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
