{$I COMPILER.INC}
unit GrCanvas;

interface

uses
  AplObj,
  AplConst,
  AplTypes,
  Drawing,
  Streams,
  Graphics;

type
  PCanvas = ^TCanvas;

  TCanvas = object(TObject)
  private
    FDriver: PGraphicsDriver;
    FWidth: integer;
    FHeight: integer;
    FBounds: TRect;
    FScreenPosition: TPoint;
    FForeColor: longint;
    FBackColor: longint;
    FFillPattern: PFillPattern;
    FLinePattern: PLinePattern;
    FUpdating: boolean;
  public
    constructor Create(ADriver: PGraphicsDriver; AWidth, AHeight: integer);
    destructor Free; virtual;
    function Width: integer;
    function Height: integer;
    function GetPixel(APX, APY: integer): longint; virtual;
    function ForeColor: longint; virtual;
    function BackColor: longint; virtual;
    function CharWidth(AChar: char): integer; virtual;
    procedure Init; virtual;
    procedure SetWidth(AWidth: integer);
    procedure SetHeight(AHeight: integer);
    procedure SetPosition(const APosition: TPoint);
    procedure GetPosition(var APosition: TPoint);
    procedure SetForeColor(AColor: longint); virtual;
    procedure SetBackColor(AColor: longint); virtual;
    procedure SetFillPattern(APattern: PFillPattern); virtual;
    procedure SetLinePattern(APattern: PLinePattern); virtual;
    procedure SetPixel(APX, APY: integer); virtual;
    procedure Line(AX1, AY1, AX2, AY2: integer); virtual;
    procedure HLine(APX, APY, AWidth: integer); virtual;
    procedure VLine(APX, APY, AHeight: integer); virtual;
    procedure InverseHLine(APX, APY, AWidth: integer); virtual;
    procedure InverseVLine(APX, APY, AHeight: integer); virtual;
    procedure InverseRectangle(ARect: TRect); virtual;
    procedure Rectangle(ARect: TRect); virtual;
    procedure Fill(AX1, AY1, AWidth, AHeight: integer); virtual;
    procedure FillRect(ARect: TRect); virtual;
    procedure FillPattern(ARect: TRect); virtual;
    procedure HLinePattern(APattern: word; APX, APY, AWidth: integer); virtual;
    procedure VLinePattern(APattern: word; APX, APY, AHeight: integer); virtual;
    procedure BezierQuad(AP1: TPoint; AP2: TPoint; AControl: TPoint; AResolution: integer);
    procedure BezierCubic(AP1: TPoint; AP2: TPoint; AControl1: TPoint;
      AControl2: TPoint; AResolution: integer);
    procedure Ellipse(AX1, AY1, AX2, AY2: integer); virtual;
    procedure EllipseRect(ARect: TRect); virtual;
    procedure EllipsePoints(AP1, AP2: TPoint); virtual;
    procedure EllipseCenter(APX, APY, ARadiusX, ARadiusY: integer); virtual;
    procedure Circle(ACenterX, ACenterY, ARadius: integer); virtual;
    procedure DrawImage(APX, APY, AWidth, AHeight: integer; AImage: PByte); virtual;
    procedure DrawImageT(APX, APY, AWidth, AHeight: integer; AImage: PByte); virtual;
    procedure DrawImageRect(ARect: TRect; AImage: PByte); virtual;
    procedure DrawImageRectT(ARect: TRect; AImage: PByte); virtual;
    procedure DrawImageStream(APX, APY, AWidth, AHeight: integer; AStream: PStream); virtual;
    procedure DrawImageStreamRect(ARect: TRect; AStream: PStream); virtual;
    procedure DrawImageStreamT(APX, APY, AWidth, AHeight: integer; AStream: PStream); virtual;
    procedure DrawImageStreamRectT(ARect: TRect; AStream: PStream); virtual;
    procedure DrawText(APX, APY: integer; AText: string); virtual;
    procedure DrawTextLarge(APX, APY: integer; AText: PChar); virtual;
    procedure BeginUpdate; virtual;
    procedure EndUpdate; virtual;
    procedure TranslateCoords(APX, APY: integer; var APoint: TPoint);
    procedure TranslateRect(var ARect: TRect);
  end;

implementation

constructor TCanvas.Create(ADriver: PGraphicsDriver; AWidth, AHeight: integer);
begin
  inherited Create;
  FDriver := ADriver;
  FWidth := AWidth;
  FHeight := AHeight;
  FBounds.CreateDims(0, 0, AWidth, AHeight);
end;

destructor TCanvas.Free;
begin
  inherited Free;
end;

procedure TCanvas.Init;
begin
  inherited Init;
  FScreenPosition.CreateCoords(0, 0);
  FForeColor := 0;
  FBackColor := 0;
  FillChar(FFillPattern, SizeOf(FFillPattern), 0);
  FillChar(FLinePattern, SizeOf(FLinePattern), 0);
  FUpdating := false;
end;

procedure TCanvas.SetWidth(AWidth: integer);
begin
  FWidth := AWidth;
  FBounds.Width := AWidth;
end;

procedure TCanvas.SetHeight(AHeight: integer);
begin
  FHeight := AHeight;
  FBounds.Height := AHeight;
end;

function TCanvas.Width: integer;
begin
  Width := FWidth;
end;

function TCanvas.Height: integer;
begin
  Height := FHeight;
end;

procedure TCanvas.SetPosition(const APosition: TPoint);
begin
  FScreenPosition.SetPoint(APosition);
end;

procedure TCanvas.GetPosition(var APosition: TPoint);
begin
  APosition.CreatePoint(FScreenPosition);
end;

procedure TCanvas.TranslateCoords(APX, APY: integer; var APoint: TPoint);
begin
  APoint.CreateCoords(APX + FScreenPosition.X, APY + FScreenPosition.Y);
end;

procedure TCanvas.TranslateRect(var ARect: TRect);
begin
  ARect.Translate(FScreenPosition.X, FScreenPosition.Y);
end;

function TCanvas.GetPixel(APX, APY: integer): longint;
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  GetPixel := FDriver^.GetPixel(point.X, point.Y);
end;

function TCanvas.ForeColor: longint;
begin
  ForeColor := FForeColor;
end;

function TCanvas.BackColor: longint;
begin
  BackColor := FBackColor;
end;

function TCanvas.CharWidth(AChar: char): integer;
begin
  CharWidth := FDriver^.CharWidth(AChar);
end;

procedure TCanvas.SetForeColor(AColor: longint);
begin
  FForeColor := AColor;
end;

procedure TCanvas.SetBackColor(AColor: longint);
begin
  FBackColor := AColor;
end;

procedure TCanvas.SetFillPattern(APattern: PFillPattern);
begin
  FFillPattern := APattern;
end;

procedure TCanvas.SetLinePattern(APattern: PLinePattern);
begin
  FLinePattern := APattern;
end;

procedure TCanvas.SetPixel(APX, APY: integer);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetPixel(point.X, point.Y);
end;

procedure TCanvas.Line(AX1, AY1, AX2, AY2: integer);
var
  point1, point2: TPoint;
begin
  TranslateCoords(AX1, AY1, point1);
  TranslateCoords(AX2, AY2, point2);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.Line(point1.X, point1.Y, point2.X, point2.Y);
end;

procedure TCanvas.HLine(APX, APY, AWidth: integer);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.HLine(point.X, point.Y, AWidth);
end;

procedure TCanvas.VLine(APX, APY, AHeight: integer);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.VLine(point.X, point.Y, AHeight);
end;

procedure TCanvas.InverseHLine(APX, APY, AWidth: integer);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.InverseHLine(point.X, point.Y, AWidth);
end;

procedure TCanvas.InverseVLine(APX, APY, AHeight: integer);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.InverseVLine(point.X, point.Y, AHeight);
end;

procedure TCanvas.InverseRectangle(ARect: TRect);
begin
  TranslateRect(ARect);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.InverseRectangle(ARect);
end;

procedure TCanvas.Rectangle(ARect: TRect);
begin
  TranslateRect(ARect);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.Rectangle(ARect);
end;

procedure TCanvas.Fill(AX1, AY1, AWidth, AHeight: integer);
var
  point: TPoint;
begin
  TranslateCoords(AX1, AY1, point);
  FDriver^.SetBackColor(FBackColor);
  FDriver^.SetFillPattern(FFillPattern);
  FDriver^.Fill(point.X, point.Y, AWidth, AHeight);
end;

procedure TCanvas.FillRect(ARect: TRect);
begin
  TranslateRect(ARect);
  FDriver^.SetBackColor(FBackColor);
  FDriver^.SetFillPattern(FFillPattern);
  FDriver^.FillRect(ARect);
end;

procedure TCanvas.FillPattern(ARect: TRect);
begin
  TranslateRect(ARect);
  FDriver^.SetBackColor(FBackColor);
  FDriver^.SetFillPattern(FFillPattern);
  FDriver^.FillPattern(ARect);
end;

procedure TCanvas.HLinePattern(APattern: word; APX, APY, AWidth: integer);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.HLinePattern(APattern, point.X, point.Y, AWidth);
end;

procedure TCanvas.VLinePattern(APattern: word; APX, APY, AHeight: integer);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.SetLinePattern(FLinePattern);
  FDriver^.VLinePattern(APattern, point.X, point.Y, AHeight);
end;

procedure TCanvas.BezierQuad(AP1: TPoint; AP2: TPoint; AControl: TPoint; AResolution: integer);
var
  point1, point2, control: TPoint;
begin
  TranslateCoords(AP1.X, AP1.Y, point1);
  TranslateCoords(AP2.X, AP2.Y, point2);
  TranslateCoords(AControl.X, AControl.Y, control);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.BezierQuad(point1, point2, control, AResolution);
end;

procedure TCanvas.BezierCubic(AP1: TPoint; AP2: TPoint; AControl1: TPoint;
  AControl2: TPoint; AResolution: integer);
var
  point1, point2, control1, control2: TPoint;
begin
  TranslateCoords(AP1.X, AP1.Y, point1);
  TranslateCoords(AP2.X, AP2.Y, point2);
  TranslateCoords(AControl1.X, AControl1.Y, control1);
  TranslateCoords(AControl2.X, AControl2.Y, control2);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.BezierCubic(point1, point2, control1, control2, AResolution);
end;

procedure TCanvas.Ellipse(AX1, AY1, AX2, AY2: integer);
var
  point1, point2: TPoint;
begin
  TranslateCoords(AX1, AY1, point1);
  TranslateCoords(AX2, AY2, point2);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.Ellipse(point1.X, point1.Y, point2.X, point2.Y);
end;

procedure TCanvas.EllipseRect(ARect: TRect);
begin
  TranslateRect(ARect);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.EllipseRect(ARect);
end;

procedure TCanvas.EllipsePoints(AP1, AP2: TPoint);
var
  point1, point2: TPoint;
begin
  TranslateCoords(AP1.X, AP1.Y, point1);
  TranslateCoords(AP2.X, AP2.Y, point2);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.Ellipse(point1.X, point1.Y, point2.X, point2.Y);
end;

procedure TCanvas.EllipseCenter(APX, APY, ARadiusX, ARadiusY: integer);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.EllipseCenter(point.X, point.Y, ARadiusX, ARadiusY);
end;

procedure TCanvas.Circle(ACenterX, ACenterY, ARadius: integer);
var
  point: TPoint;
begin
  TranslateCoords(ACenterX, ACenterY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.Circle(point.X, point.Y, ARadius);
end;

procedure TCanvas.DrawImage(APX, APY, AWidth, AHeight: integer; AImage: PByte);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.DrawImageCoords(point.X, point.Y, AWidth, AHeight, AImage, []);
end;

procedure TCanvas.DrawImageT(APX, APY, AWidth, AHeight: integer; AImage: PByte);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.DrawImageCoords(point.X, point.Y, AWidth, AHeight, AImage, [ifTransparent]);
end;

procedure TCanvas.DrawImageRect(ARect: TRect; AImage: PByte);
begin
  TranslateRect(ARect);
  FDriver^.DrawImage(ARect, AImage, []);
end;

procedure TCanvas.DrawImageRectT(ARect: TRect; AImage: PByte);
begin
  TranslateRect(ARect);
  FDriver^.DrawImage(ARect, AImage, [ifTransparent]);
end;

procedure TCanvas.DrawImageStream(APX, APY, AWidth, AHeight: integer; AStream: PStream);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.DrawImageCoords(point.X, point.Y, AWidth, AHeight, AStream, [ifStreamed]);
end;

procedure TCanvas.DrawImageStreamRect(ARect: TRect; AStream: PStream);
begin
  TranslateRect(ARect);
  FDriver^.DrawImage(ARect, AStream, [ifStreamed]);
end;

procedure TCanvas.DrawImageStreamT(APX, APY, AWidth, AHeight: integer; AStream: PStream);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.DrawImageCoords(point.X, point.Y, AWidth, AHeight, AStream, [ifTransparent, ifStreamed]);
end;

procedure TCanvas.DrawImageStreamRectT(ARect: TRect; AStream: PStream);
begin
  TranslateRect(ARect);
  FDriver^.DrawImage(ARect, AStream, [ifTransparent, ifStreamed]);
end;

procedure TCanvas.DrawText(APX, APY: integer; AText: string);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.DrawText(point.X, point.Y, AText);
end;

procedure TCanvas.DrawTextLarge(APX, APY: integer; AText: PChar);
var
  point: TPoint;
begin
  TranslateCoords(APX, APY, point);
  FDriver^.SetForeColor(FForeColor);
  FDriver^.DrawTextLarge(point.X, point.Y, AText);
end;

procedure TCanvas.BeginUpdate;
begin
  if FUpdating then
    Exit;
  FDriver^.PushState;
  FUpdating := true;
end;

procedure TCanvas.EndUpdate;
begin
  if not FUpdating then
    Exit;
  FDriver^.PopState;
  FUpdating := false;
end;

end.