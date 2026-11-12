unit Biz.OrderModel;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  // 单个商品明细
  TOrderItemDetail = class
  public
    ProductName: string;
    ImageUrl: string;
    SpecName: string;
    Price: Currency;
    Quantity: Integer;
    constructor Create(const AName, AImg, ASpec: string; const APrice: Currency; const AQty: Integer);
  end;

  // 订单完整模型（列表中的一个独立卡片 Item）
  TOrder = class
  public
    OrderId: string;
    OrderDate: string;
    StatusText: string;
    Details: TObjectList<TOrderItemDetail>;
    TotalQty: Integer;
    TotalAmount: Currency;
    constructor Create; overload;
    constructor Create(const AId, ADate, AStatus: string); overload;
    destructor Destroy; override;
    procedure AddDetail(const AName, AImg, ASpec: string; const APrice: Currency; const AQty: Integer);
  end;

implementation

{ TOrderItemDetail }

constructor TOrderItemDetail.Create(const AName, AImg, ASpec: string; const APrice: Currency; const AQty: Integer);
begin
  inherited Create;
  ProductName := AName;
  ImageUrl := AImg;
  SpecName := ASpec;
  Price := APrice;
  Quantity := AQty;
end;

{ TOrder }

constructor TOrder.Create;
begin
  inherited Create;
  Details := TObjectList<TOrderItemDetail>.Create(True);
  TotalQty := 0;
  TotalAmount := 0;
end;

constructor TOrder.Create(const AId, ADate, AStatus: string);
begin
  Create;
  OrderId := AId;
  OrderDate := ADate;
  StatusText := AStatus;
end;

destructor TOrder.Destroy;
begin
  Details.Free;
  inherited Destroy;
end;

procedure TOrder.AddDetail(const AName, AImg, ASpec: string; const APrice: Currency; const AQty: Integer);
begin
  Details.Add(TOrderItemDetail.Create(AName, AImg, ASpec, APrice, AQty));
  TotalQty := TotalQty + AQty;
  TotalAmount := TotalAmount + (APrice * AQty);
end;

end.