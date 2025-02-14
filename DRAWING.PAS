{$I COMPILER.INC}
unit Drawing;

interface

uses
  AplObj,
  Lists,
  AplMath,
  AplUtils;

type
  PPoint = ^TPoint;
  PRect = ^TRect;
  PSize = ^TSize;
  PRectList = ^TRectList;
  PPointList = ^TPointList;
  PRegion = ^TRegion;
  PInversionPoint = ^TInversionPoint;
  PInversionPointList = ^TInversionPointList;
  PVector2 = ^TVector2;
  PSetPixelProc = ^TSetPixelProc;

  TRegionMode = (rmInclude, rmExclude);
  TSetPixelProc = procedure(AX, AY: integer; AData: pointer);

  TPointList = object(TObjectList)
  private
  public
    function GetItem(AIndex: integer): PPoint;
    function Add(AItem: PPoint): integer;
    function IndexOf(AItem: PPoint): integer;
    procedure SetItem(AIndex: integer; AItem: PPoint);
    procedure Insert(AIndex: integer; AItem: PPoint);
  end;

  TInversionPoint = object(TObject)
  private
  public
    On: boolean;
    Position: integer;
    constructor CreatePoint(AOn: boolean; APosition: integer);
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
  end;

  TRectList = object(TObjectList)
  private
  public
    function GetItem(AIndex: integer): PRect;
    function Add(AItem: PRect): integer;
    function IndexOf(AItem: PRect): integer;
    procedure SetItem(AIndex: integer; AItem: PRect);
    procedure Insert(AIndex: integer; AItem: PRect);
  end;

  TInversionPointList = object(TObjectList)
  private
  public
    constructor Create;
    procedure Init; virtual;
    function GetItem(AIndex: integer): PInversionPoint;
    function Add(AItem: PInversionPoint): integer;
    function IndexOf(AItem: PInversionPoint): integer;
    procedure SetItem(AIndex: integer; AItem: PInversionPoint);
    procedure Insert(AIndex: integer; AItem: PInversionPoint);
  end;

  TPoint = object(TObject)
  public
    X, Y: integer;
    constructor Create;
    constructor CreateCoords(AX, AY: longint);
    constructor CreatePoint(APoint: TPoint);
    procedure SetCoords(AX, AY: longint);
    procedure SetPoint(APoint: TPoint);
    procedure Translate(ADX, ADY: longint);
    procedure Init; virtual;
    function EqualsCoords(AX, AY: longint): boolean;
    function Equals(APoint: TPoint): boolean;
  end;

  TVector2 = object(TObject)
  private
  public
    X, Y: real;
    constructor CreateCoords(AX, AY: real);
    constructor CreateVector(AVector: TVector2);
    constructor CreateSingle(AValue: real);
    constructor CreatePoint(APoint: TPoint);
    procedure Assign(var ASource: TObject); virtual;
    procedure SetVector(AVector: TVector2);
    procedure SetSingle(AValue: real);
    procedure SetPoint(APoint: TPoint);
    procedure Translate(ADX, ADY: real);
    procedure Init; virtual;
    procedure Negate;
    procedure Abs;
    procedure Divide(AValue: real);
    procedure Multiply(AValue: real);
    procedure Add(AVector: TVector2);
    procedure Subtract(AVector: TVector2);
    function Equals(AVector: TVector2): boolean;
    function EqualsSingle(AValue: real): boolean;
    function Distance(AVector: TVector2): real;
    function DistanceSquared(AVector: TVector2): real;
  end;

  PLocation = ^TLocation;
  TLocation = TPoint;

  TRect = object(TObject)
  public
    X, Y: integer;
    Width, Height: integer;
    constructor CreateDims(AX, AY, AWidth, AHeight: integer);
    constructor CreateCoords(AX, AY, ARight, ABottom: integer);
    constructor CreateRect(ARect: TRect);
    procedure SetDims(AX, AY, AWidth, AHeight: integer);
    procedure SetCoords(AX, AY, ARight, ABottom: integer);
    procedure SetRect(ARect: TRect);
    procedure SetSize(AWidth, AHeight: integer);
    procedure SetXY(AX, AY: integer);
    procedure Assign(var ASource: TObject); virtual;
    procedure SetRight(ARight: integer);
    procedure SetBottom(ABottom: integer);
    procedure Translate(ADX, ADY: integer);
    procedure TranslateToOrigin;
    procedure Clear;
    procedure Grow(ADW, ADH: integer);
    procedure Intersect(var ARect: TRect);
    procedure GetIntersection(ARect: TRect; var AResult: TRect);
    procedure Init; virtual;
    procedure GetInversionPoints(var AList: TInversionPointList;
      AMode: TRegionMode; AY, AStartX, AEndX: integer);
    procedure GetCoords(var APX, APY, ARight, ABottom: integer);
    procedure GetDims(var APX, APY, AWidth, AHeight: integer);
    function GetNewObject: PObject; virtual;
    function Equals(ARect: TRect): boolean;
    function EqualsCoords(AX, AY, AWidth, AHeight: integer): boolean;
    function IsEmpty: boolean;
    function Right: integer;
    function Bottom: integer;
    function Contains(APX, APY: integer): boolean;
    function ContainsPoint(APoint: TPoint): boolean;
    function ContainsX(APX: integer): boolean;
    function ContainsY(APY: integer): boolean;
    function ClampX(APX: integer): integer;
    function ClampY(APY: integer): integer;
    function IntersectsRect(ARect: TRect): boolean;
  end;

  TSize = object(TObject)
  public
    Width, Height: longint;
    constructor Create;
    constructor CreateDims(AWidth, AHeight: longint);
    constructor CreateSize(ASize: TSize);
    constructor CreateRect(ARect: TRect);
    procedure Assign(var ASource: TObject); virtual;
    procedure SetDims(AWidth, AHeight: longint);
    procedure SetRect(ARect: TRect);
    procedure SetSize(ASize: TSize);
    procedure Grow(ADW, ADH: longint);
    procedure Init; virtual;
  end;

  TRegion = object(TRectList)
  private
  public
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    procedure GetInversionPoints(var AList: TInversionPointList;
      AMode: TRegionMode; AY, AStartX, AEndX: integer);
    function Contains(AX, AY: integer): boolean;
    function IntersectsRect(var ARect: TRect): boolean;
    function HasRect(var ARect: TRect): boolean;
  end;

procedure LinearInterpolation(const AStart, AEnd: TVector2;
  ATValue: real; var AResult: TVector2); far;

procedure BezierInterpolationQuad(const AP1, AP2, AP3: TVector2;
  ATValue: real; var AResult: TVector2); far;

procedure BezierInterpolationCubic(const AP1, AP2, AP3, AP4: TVector2;
  ATValue: real;  var AResult: TVector2); far;

procedure LineDraw(AX1, AY1, AX2, AY2: integer; ADrawRect: TRect;
  ASetPixelProc: PSetPixelProc; AData: pointer); far;

implementation

procedure LinearInterpolation(const AStart, AEnd: TVector2;
  ATValue: real; var AResult: TVector2);
begin
  AResult.Create;
  AResult.X := AStart.X + (AEnd.X - AStart.X) * ATValue;
  AResult.Y := AStart.Y + (AEnd.Y - AStart.Y) * ATValue;
end;

procedure BezierInterpolationQuad(const AP1, AP2, AP3: TVector2;
  ATValue: real; var AResult: TVector2);
var
  intermediateA, intermediateB: TVector2;
begin
  LinearInterpolation(AP1, AP2, ATValue, intermediateA);
  LinearInterpolation(AP2, AP3, ATValue, intermediateB);
  LinearInterpolation(intermediateA, intermediateB, ATValue, AResult);
end;

procedure BezierInterpolationCubic(const AP1, AP2, AP3, AP4: TVector2;
  ATValue: real; var AResult: TVector2);
var
  intermediateA, intermediateB, intermediateC: TVector2;
begin
  BezierInterpolationQuad(AP1, AP2, AP3, ATValue, intermediateA);
  BezierInterpolationQuad(AP2, AP3, AP4, ATValue, intermediateB);
  LinearInterpolation(intermediateA, intermediateB, ATValue, AResult);
end;

function InversionCompare(AItem1, AItem2: pointer): integer; far;
var
  item1, item2: PInversionPoint;
begin
  item1 := PInversionPoint(AItem1);
  item2 := PInversionPoint(AItem2);
  InversionCompare := 0;
  if item1^.Position = item2^.Position then
    exit;
  if item1^.Position < item2^.Position then
    InversionCompare := -1
  else if item1^.Position > item2^.Position then
    InversionCompare := 1;
end;

constructor TRect.CreateRect(ARect: TRect);
begin
  inherited Create;
  SetRect(ARect);
end;

constructor TRect.CreateDims(AX, AY, AWidth, AHeight: integer);
begin
  inherited Create;
  if (AWidth < 0) or (AHeight < 0) then
    SetDims(AX, AY, 0, 0)
  else
    SetDims(AX, AY, AWidth, AHeight);
end;

constructor TRect.CreateCoords(AX, AY, ARight, ABottom: integer);
begin
  inherited Create;
  if (ARight < AX) or (ABottom < AY) then
    SetDims(AX, AY, 0, 0)
  else
    SetCoords(AX, AY, ARight, ABottom);
end;

function TRect.GetNewObject: PObject;
begin
  GetNewObject := New(PRect, Create);
end;

procedure TRect.SetRight(ARight: integer);
begin
  Width := ARight - X + 1;
end;

procedure TRect.Init;
begin
  inherited Init;
  X := 0;
  Y := 0;
  Width := 0;
  Height := 0;
end;

procedure TRect.SetBottom(ABottom: integer);
begin
  Height := ABottom - Y + 1;
end;

procedure TRect.Translate(ADX, ADY: integer);
begin
  Inc(X, ADX);
  Inc(Y, ADY);
end;

procedure TRect.Clear;
begin
  SetDims(0, 0, 0, 0);
end;

procedure TRect.TranslateToOrigin;
begin
  X := 0;
  Y := 0;
end;

procedure TRect.Assign(var ASource: TObject);
var
  source: PRect;
begin
  inherited Assign(ASource);
  source := PRect(@ASource);
  SetRect(source^);
end;

procedure TRect.SetRect(ARect: TRect);
begin
  X := ARect.X;
  Y := ARect.Y;
  Width := ARect.Width;
  Height := ARect.Height
end;

procedure TRect.SetDims(AX, AY, AWidth, AHeight: integer);
begin
  X := AX;
  Y := AY;
  Width := AWidth;
  Height := AHeight;
end;

procedure TRect.SetCoords(AX, AY, ARight, ABottom: integer);
begin
  X := AX;
  Y := AY;
  Width := ARight - AX + 1;
  Height := ABottom - AY + 1;
end;

procedure TRect.SetSize(AWidth, AHeight: integer);
begin
  Width := AWidth;
  Height := AHeight;
end;

procedure TRect.SetXY(AX, AY: integer);
begin
  X := AX;
  Y := AY;
end;

procedure TRect.Grow(ADW, ADH: integer);
begin
  Inc(Width, ADW);
  Inc(Height, ADH);
end;

function TRect.Equals(ARect: TRect): boolean;
begin
  Equals := EqualsCoords(ARect.X, ARect.Y, ARect.Width, ARect.Height);
end;

function TRect.EqualsCoords(AX, AY, AWidth, AHeight: integer): boolean;
begin
  EqualsCoords :=
    (X = AX)
    and (Y = AY)
    and (Width = AWidth)
    and (Height = AHeight);
end;

function TRect.Right: integer;
begin
  Right := X + Width - 1;
end;

function TRect.Bottom: integer;
begin
  Bottom := Y + Height - 1;
end;

function TRect.ClampX(APX: integer): integer;
begin
  ClampX := Clamp(APX, X, Right);
end;

function TRect.ClampY(APY: integer): integer;
begin
  ClampY := Clamp(APY, Y, Bottom);
end;

procedure TRect.GetCoords(var APX, APY, ARight, ABottom: integer);
begin
  APX := X;
  APY := Y;
  ARight := Right;
  ABottom := Bottom;
end;

procedure TRect.GetDims(var APX, APY, AWidth, AHeight: integer);
begin
  APX := X;
  APY := Y;
  AWidth := Width;
  AHeight := Height;
end;

function TRect.ContainsX(APX: integer): boolean;
begin
  ContainsX := (APX >= X) and (APX <= Right);
end;

function TRect.ContainsY(APY: integer): boolean;
begin
  ContainsY := (APY >= Y) and (APY <= Bottom);
end;

function TRect.Contains(APX, APY: integer): boolean;
begin
  Contains := ContainsX(APX) and ContainsY(APY);
end;

function TRect.ContainsPoint(APoint: TPoint): boolean;
begin
  ContainsPoint := Contains(APoint.X, APoint.Y);
end;

function TRect.IntersectsRect(ARect: TRect): boolean;
begin
  IntersectsRect := not
    ((ARect.Right < X) or
     (ARect.X > Right) or
     (ARect.Bottom < Y) or
     (ARect.Y > Bottom));
end;

function TRect.IsEmpty: boolean;
begin
  IsEmpty := (Width <= 0) or (Height <= 0);
end;

procedure TRect.Intersect(var ARect: TRect);
begin
  if not IntersectsRect(ARect) then begin
    SetDims(0, 0, 0, 0);
    exit;
  end;
  SetCoords(MaxL(X, ARect.X), MaxL(Y, ARect.Y),
    MinL(Right, ARect.Right), MinL(Bottom, ARect.Bottom));
end;

procedure TRect.GetIntersection(ARect: TRect; var AResult: TRect);
begin
  AResult.Create;
  if not IntersectsRect(ARect) then
    exit;
  AResult.SetCoords(Max(X, ARect.X), Max(Y, ARect.Y),
    Min(Right, ARect.Right), Min(Bottom, ARect.Bottom));
end;

procedure TRect.GetInversionPoints(var AList: TInversionPointList;
  AMode: TRegionMode; AY, AStartX, AEndX: integer);
var
  point: PInversionPoint;
  on, off: boolean;
begin
  on := true;
  off := false;
  if AMode = rmExclude then begin
    on := false;
    off := true;
  end;
  if AStartX = AEndX then
    exit;
  if (AY < Y) or (AY > Bottom) then
    exit;
  if AStartX < X then begin
    point := New(PInversionPoint, CreatePoint(on, X));
    AList.Add(point);
  end;
  if AEndX > Right then begin
    point := New(PInversionPoint, CreatePoint(off, Right));
    AList.Add(point);
  end;
end;

constructor TPoint.Create;
begin
  Init;
end;

constructor TPoint.CreateCoords(AX, AY: longint);
begin
  Init;
  SetCoords(AX, AY);
end;

constructor TPoint.CreatePoint(APoint: TPoint);
begin
  Init;
  SetPoint(APoint);
end;

procedure TPoint.SetCoords(AX, AY: longint);
begin
  X := AX;
  Y := AY;
end;

procedure TPoint.SetPoint(APoint: TPoint);
begin
  X := APoint.X;
  Y := APoint.Y;
end;

procedure TPoint.Translate(ADX, ADY: longint);
begin
  Inc(X, ADX);
  Inc(Y, ADY);
end;

procedure TPoint.Init;
begin
  inherited Init;
  X := 0;
  Y := 0;
end;

function TPoint.EqualsCoords(AX, AY: longint): boolean;
begin
  EqualsCoords := (AX = X) and (AY = Y);
end;

function TPoint.Equals(APoint: TPoint): boolean;
begin
  Equals := (APoint.X = X) and (APoint.Y = Y);
end;

constructor TSize.Create;
begin
  Init;
end;

constructor TSize.CreateDims(AWidth, AHeight: longint);
begin
  Init;
  SetDims(AWidth, AHeight);
end;

constructor TSize.CreateSize(ASize: TSize);
begin
  Init;
  SetSize(ASize);
end;

constructor TSize.CreateRect(ARect: TRect);
begin
  Init;
  SetRect(ARect);
end;

procedure TSize.Init;
begin
  inherited Init;
  Width := 0;
  Height := 0;
end;

procedure TSize.Assign(var ASource: TObject);
var
  source: PSize;
begin
  inherited Assign(ASource);
  source := PSize(@ASource);
  Width := source^.Width;
  Height := source^.Height;
end;

procedure TSize.SetDims(AWidth, AHeight: longint);
begin
  Width := AWidth;
  Height := AHeight;
end;

procedure TSize.SetSize(ASize: TSize);
begin
  Width := ASize.Width;
  Height := ASize.Height;
end;

procedure TSize.SetRect(ARect: TRect);
begin
  Width := ARect.Width;
  Height := ARect.Height;
end;

procedure TSize.Grow(ADW, ADH: longint);
begin
  Inc(width, ADW);
  Inc(height, ADH);
end;

function TPointList.GetItem(AIndex: integer): PPoint;
begin
  GetItem := PPoint(inherited GetItem(AIndex));
end;

function TPointList.Add(AItem: PPoint): integer;
begin
  Add := inherited Add(AItem);
end;

function TPointList.IndexOf(AItem: PPoint): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TPointList.SetItem(AIndex: integer; AItem: PPoint);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TPointList.Insert(AIndex: integer; AItem: PPoint);
begin
  inherited Insert(AIndex, AItem);
end;

function TRectList.GetItem(AIndex: integer): PRect;
begin
  GetItem := PRect(inherited GetItem(AIndex));
end;

function TRectList.Add(AItem: PRect): integer;
begin
  Add := inherited Add(AItem);
end;

function TRectList.IndexOf(AItem: PRect): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TRectList.SetItem(AIndex: integer; AItem: PRect);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TRectList.Insert(AIndex: integer; AItem: PRect);
begin
  inherited Insert(AIndex, AItem);
end;

procedure TRegion.Init;
begin
  inherited Init;
end;

procedure TRegion.Assign(var ASource: TObject);
var
  source: PRegion;
  index: integer;
  rect, sourceRect: PRect;
begin
  inherited Assign(ASource);
  source := PRegion(@ASource);
  Clear;
  for index := 0 to source^.Count - 1 do begin
    sourceRect := source^.GetItem(index);
    rect := New(PRect, Create);
    rect^.Assign(sourceRect^);
    Add(rect);
  end;
end;

function TRegion.Contains(AX, AY: integer): boolean;
var
  index: integer;
  rect: PRect;
begin
  Contains := false;
  for index := 0 to Count - 1 do begin
    rect := GetItem(index);
    if rect^.Contains(AX, AY) then begin
      Contains := true;
      exit;
    end;
  end;
end;

function TRegion.IntersectsRect(var ARect: TRect): boolean;
var
  index: integer;
  rect: PRect;
begin
  IntersectsRect:= false;
  for index := 0 to Count - 1 do begin
    rect := GetItem(index);
    if rect^.IntersectsRect(ARect) then begin
      IntersectsRect := true;
      exit;
    end;
  end;
end;

function TRegion.HasRect(var ARect: TRect): boolean;
var
  index: integer;
  rect: PRect;
begin
  HasRect := false;
  for index := 0 to Count - 1 do begin
    rect := GetItem(index);
    if rect^.Equals(ARect) then begin
      HasRect := true;
      exit;
    end;
  end;
end;

procedure TRegion.GetInversionPoints(var AList: TInversionPointList;
  AMode: TRegionMode; AY, AStartX, AEndX: integer);
var
  index: integer;
  rect: PRect;
begin
  for index := 0 to Count - 1 do begin
    rect := GetItem(index);
    rect^.GetInversionPoints(AList, AMode, AY, AStartX, AEndX);
  end;
end;

constructor TInversionPoint.CreatePoint(AOn: boolean; APosition: integer);
begin
  inherited Create;
  On := AOn;
  Position := APosition;
end;

constructor TVector2.CreateCoords(AX, AY: real);
begin
  inherited Create;
  X := AX;
  Y := AY;
end;

constructor TVector2.CreateVector(AVector: TVector2);
begin
  inherited Create;
  SetVector(AVector);
end;

constructor TVector2.CreateSingle(AValue: real);
begin
  inherited Create;
  SetSingle(AValue);
end;

constructor TVector2.CreatePoint(APoint: TPoint);
begin
  inherited Create;
  SetPoint(APoint);
end;

procedure TVector2.Assign(var ASource: TObject);
var
  source: PVector2;
begin
  inherited Assign(ASource);
  source := PVector2(@ASource);
  X := source^.X;
  Y := source^.Y;
end;

procedure TVector2.SetVector(AVector: TVector2);
begin
  X := AVector.X;
  Y := AVector.Y;
end;

procedure TVector2.SetSingle(AValue: real);
begin
  X := AValue;
  Y := AValue;
end;

procedure TVector2.SetPoint(APoint: TPoint);
begin
  X := APoint.X;
  Y := APoint.Y;
end;

procedure TVector2.Translate(ADX, ADY: real);
begin
  X := X + ADX;
  Y := Y + ADY;
end;

procedure TVector2.Init;
begin
  inherited Init;
  X := 0;
  Y := 0;
end;

procedure TVector2.Negate;
begin
  X := -X;
  Y := -Y;
end;

procedure TVector2.Abs;
begin
  X := System.Abs(X);
  Y := System.Abs(Y);
end;

procedure TVector2.Divide(AValue: real);
begin
  X := X / AValue;
  Y := Y / AValue;
end;

procedure TVector2.Multiply(AValue: real);
begin
  X := X * AValue;
  Y := Y * AValue;
end;

procedure TVector2.Add(AVector: TVector2);
begin
  X := X + AVector.X;
  Y := Y + AVector.Y;
end;

procedure TVector2.Subtract(AVector: TVector2);
begin
  X := X - AVector.X;
  Y := Y - AVector.Y;
end;

function TVector2.Equals(AVector: TVector2): boolean;
begin
  Equals := (AVector.X = X) and (AVector.Y = Y);
end;

function TVector2.EqualsSingle(AValue: real): boolean;
begin
  EqualsSingle := (X = AValue) and (Y = AValue);
end;

function TVector2.Distance(AVector: TVector2): real;
begin
  Distance := Sqrt(Sqr(X - AVector.X) + Sqr(Y - AVector.Y));
end;

function TVector2.DistanceSquared(AVector: TVector2): real;
begin
  DistanceSquared := Sqr(X - AVector.X) + Sqr(Y - AVector.Y);
end;

procedure TInversionPoint.Init;
begin
  inherited Init;
  Position := 0;
  On := true;
end;

procedure TInversionPoint.Assign(var ASource: TObject);
var
  source: PInversionPoint;
begin
  inherited Assign(ASource);
  source := PInversionPoint(@ASource);
  Position := source^.Position;
  On := source^.On;
end;

function TInversionPointList.GetItem(AIndex: integer): PInversionPoint;
begin
  GetItem := PInversionPoint(inherited GetItem(AIndex));
end;

function TInversionPointList.Add(AItem: PInversionPoint): integer;
begin
  Add := inherited Add(AItem);
end;

function TInversionPointList.IndexOf(AItem: PInversionPoint): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TInversionPointList.SetItem(AIndex: integer; AItem: PInversionPoint);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TInversionPointList.Insert(AIndex: integer; AItem: PInversionPoint);
begin
  inherited Insert(AIndex, AItem);
end;

procedure TInversionPointList.Init;
begin
  inherited Init;
end;

constructor TInversionPointList.Create;
begin
  inherited Create;
end;

procedure LineDraw(AX1, AY1, AX2, AY2: integer; ADrawRect: TRect;
  ASetPixelProc: PSetPixelProc; AData: pointer);
var
  aError, aError2, sx, sy, dlx, dly: integer;
  x, y, right, bottom, width: integer;
  color: byte;
begin
  if not Assigned(ASetPixelProc) then
    exit;
  dlx := Abs(AX2 - AX1);
  if AX1 < AX2 then
    sx := 1
  else
    sx := -1;

  dly := -Abs(AY2 - AY1);
  if AY1 < AY2 then
    sy := 1
  else
    sy := -1;

  aError := dlx + dly;
  x := ADrawRect.X;
  y := ADrawRect.Y;
  right := ADrawRect.Right;
  bottom := ADrawRect.Bottom;
  while true do begin
    if ADrawRect.Contains(AX1, AY1) then
      TSetPixelProc(ASetPixelProc)(AX1, AY1, AData);
    if (AX1 = AX2) and (AY1 = AY2) then
      break;
    aError2 := 2 * aError;
    if aError2 >= dly then begin
      if AX1 = AX2 then
        break;
      Inc(aError, dly);
      Inc(AX1, sx);
    end;
    if aError2 <= dlx then begin
      if AY1 = AY2 then
        break;
      Inc(aError, dlx);
      Inc(AY1, sy);
    end;
  end;
end;

end.