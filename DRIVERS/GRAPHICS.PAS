{$I COMPILER.INC}
unit Graphics;

interface

uses
  AplObj,
  AplTypes,
  AplMath,
  AplUtils,
  Streams,
  Drawing,
  Lists,
  AplConst,
  AplStr,
  Compress,
  Palettes,
  MemDrv,
  Strings;

const
  FontMajorVersion = 1;
  FontMinorVersion = 2;

type
  PGraphicsMode = ^TGraphicsMode;
  PGraphicsDriver = ^TGraphicsDriver;
  PGraphicsModeList = ^TGraphicsModeList;
  PFont = ^TFont;
  PFontList = ^TFontList;
  PGraphicsState = ^TGraphicsState;
  PSystemFont = ^TSystemFont;
  PMonospaceFont = ^TMonospaceFont;
  PProportionalFont = ^TProportionalFont;
  PVectorFont = ^TVectorFont;
  PColoredFont = ^TColoredFont;
  PFillPattern = ^TFillPattern;
  PLinePattern = ^TLinePattern;

  TFontWidthArray = array[byte] of word;
  TFontFormat = (ffMonoSpace, ffProportional, ffSystem, ffColored);
  TFontFormats = set of TFontFormat;
  TFillPattern = array[0..15] of word;
  TLinePattern = word;
  TImageFlag = (
    ifTransparent,
    ifStreamed
  );
  TImageFlags = set of TImageFlag;

  TGraphicsMode = object(TIdentifiable)
  private
  public
    Description: PChar;
    Width, Height: integer;
    MaxX, MaxY: integer;
    Bounds: TRect;
    Bpp: byte;
    HelpText: PChar;
    ModeIndex: word;
    BytesPerScanLine: word;
    FrameBuffer: pointer;
    ScreenSize: longint;
    PageCount: word;
    MaxPage: word;
    ModeId: integer;
    procedure Assign(var ASource: TObject); virtual;
    procedure Init; virtual;
    destructor Free; virtual;
  end;

  TGraphicsModeList = object(TIdentifiableList)
  public
    function GetItemById(const AID: string): PGraphicsMode;
    function GetItem(AIndex: integer): PGraphicsMode;
    function GetModeById(AModeID: integer): PGraphicsMode;
    function Add(AItem: PGraphicsMode): integer;
    function IndexOf(AItem: PGraphicsMode): integer;
    procedure SetItem(AIndex: integer; AItem: PGraphicsMode);
    procedure Insert(AIndex: integer; AItem: PGraphicsMode);
  end;

  TFontHeader = record
    MajorVersion: integer;
    MinorVersion: integer;
    Name: string[50];
    DataSize: longint;
    MaxWidth: byte;
    Height: byte;
    Compression: TAplCompression;
    Spacing: byte;
    Format: TFontFormat;
    Unused: byte;
    CompressionLevel: TCompressionLevel;
    BytesPerCharLine: byte;
    Reserved: array[0..250] of byte;
  end;

  TFont = object(TPersistent)
  private
    FFontData: PByte;
    FFontDataSize: word;
    FFormat: TFontFormat;
    procedure AdjustSize(var AHeader: TFontHeader; ASize: word);
    public
    Version: real;
    TransparentColor: longint;
    Transparent: boolean;
    Height: byte;
    MaxWidth: byte;
    AverageWidth: integer;
    Spacing: byte;
    BytesPerCharLine: byte;
    destructor Free; virtual;
    constructor CreateSize(AMaxWidth, AHeight, ASpacing: byte);
    procedure Assign(var ASource: TObject); virtual;
    procedure Init; virtual;
    procedure SetPixel(AChar: char; APX, APY: integer); virtual;
    procedure ClearPixel(AChar: char; APX, APY: integer); virtual;
    procedure SaveToStream(AStream: PStream); virtual;
    procedure LoadFromStream(AStream: PStream); virtual;
    procedure SetCharWidths; virtual;
    procedure SetFormat(AFormat: TFontFormat); virtual;
    function Format: TFontFormat; virtual;
    function IsPixelSet(AChar: char; APX, APY: integer): boolean; virtual;
    function CharWidth(AChar: char): integer; virtual;
    function TextWidthAny(AText: PChar; ALength: word): longint; virtual;
    function TextWidth(const AText: string): longint; virtual;
    function TextWidthLarge(AText: PChar): longint; virtual;
    function FontData: PByte; virtual;
    function FontDataSize: word; virtual;
  end;

  TMonospaceFont = object(TFont)
  private
  public
    constructor CreateSize(AWidth, AHeight, ASpacing: byte);
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    destructor Free; virtual;
    procedure SetCharWidths; virtual;
    function TextWidthAny(AText: PChar; ALength: word): longint; virtual;
    function CharWidth(AChar: char): integer; virtual;
  end;

  TProportionalFont = object(TFont)
  private
  public
    CharWidths: TByteArray;
    constructor CreateSize(AMaxWidth, AHeight, ASpacing: byte);
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    procedure SetCharWidths; virtual;
    function TextWidthAny(AText: PChar; ALength: word): longint; virtual;
    function CharWidth(AChar: char): integer; virtual;
    destructor Free; virtual;
  end;

  TVectorFont = object(TFont)
  private
  public
  end;

  TColoredFont = object(TProportionalFont)
  private
  public
    StartChar: byte;
    EndChar: byte;
    constructor CreateSize(AMaxWidth, AHeight, ASpacing: byte);
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    destructor Free; virtual;
  end;

  TSystemFont = object(TMonospaceFont)
  private
  public
    FontIndex: byte;
    function CharWidth(AChar: char): integer; virtual;
    function TextWidthAny(AText: PChar; ALength: word): longint; virtual;
    procedure SetTextFont(AFontIndex: byte); virtual;
    procedure Init; virtual;
    destructor Free; virtual;
  end;

  TGraphicsState = object(TObject)
  private
  public
    ForeColor: longint;
    BackColor: longint;
    XPos, YPos: integer;
    Bpp: byte;
    Font: PFont;
    ViewPort: TRect;
    FrameBuffer: PByte;
    BufferMode: boolean;
    Bounds: TRect;
    FillPattern: PFillPattern;
    LinePattern: PLinePattern;
    Inverse: boolean;
    DrawPage, DisplayPage: word;
    OverrideFontWidth: byte;
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
  end;

  TGraphicsDriver = object(TStatusObject)
  private
    FOldMode: byte;
  public
    State: PGraphicsState;
    StateStack: TObjectStack;
    Modes: TGraphicsModeList;
    Mode: PGraphicsMode;
    BufferRect: TRect;
    OffScreenPage: word;
    function GetPixel(APX, APY: integer): byte; virtual;
    function ForeColor: longint; virtual;
    function BackColor: longint; virtual;
    function XPos: byte; virtual;
    function YPos: byte; virtual;
    function GetScreenPointer(APX, APY: integer): PByte; virtual;
    function CreateGraphicsState: PGraphicsState; virtual;
    function CharWidth(AChar: char): integer; virtual;
    procedure SetDisplayPage(APage: word); virtual;
    procedure SetDrawPage(APage: word); virtual;
    procedure BeginDrawBuffer(var ABuffer: PByte; var ABounds: TRect); virtual;
    procedure GetImage(APX, APY, AWidth, AHeight: longint; ABuffer: PByte); virtual;
    procedure GetImageRect(ARect: TRect; ABuffer: PByte); virtual;
    procedure GetImageStream(APX, APY, AWidth, AHeight: longint; AStream: PStream); virtual;
    procedure GetImageStreamRect(ARect: TRect; AStream: PStream); virtual;
    procedure SetForeColor(AColor: longint); virtual;
    procedure SetBackColor(AColor: longint); virtual;
    procedure SetFillPattern(APattern: PFillPattern); virtual;
    procedure SetLinePattern(APattern: PLinePattern); virtual;
    procedure SetMode(AMode: PGraphicsMode); virtual;
    procedure SetViewport(var ARect: TRect); virtual;
    procedure SetPixel(APX, APY: integer); virtual;
    procedure MoveTo(APX, APY: integer); virtual;
    procedure LineTo(APX, APY: integer); virtual;
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
    procedure RenderText(APX, APY, ALength: integer; AText: PChar); virtual;
    procedure DrawImageCoords(APX, APY, AWidth, AHeight: integer;
      var AImage; AFlags: TImageFlags); virtual;
    procedure DrawImage(const ARect: TRect; var AImage;
      AFlags: TImageFlags); virtual;
    procedure DrawImageZoom(const ARect: TRect; var AImage;
      AFlags: TImageFlags; AZoom: integer); virtual;
    procedure DrawBufferRect(const ASourceBounds, ASourceRect: TRect;
      const ADestPoint: TPoint; var ABuffer); virtual;
    procedure DrawText(APX, APY: integer; AText: string); virtual;
    procedure DrawTextLarge(APX, APY: integer; AText: PChar); virtual;
    procedure GetDrawRect(var ARect: TRect); virtual;
    procedure GetImageDrawRects(APX, APY, AWidth, AHeight: longint;
      var AImageRect, ADrawRect: TRect); virtual;
    procedure PushState; virtual;
    procedure PopState; virtual;
    procedure EndDrawBuffer; virtual;
    procedure Init; virtual;
    procedure WaitForVSync; virtual;
    procedure ResetMode; virtual;
    procedure CopyToOffScreen(const ASource, ADest: TRect); virtual;
    procedure CopyFromOffScreen(const ASource, ADest: TRect); virtual;
    procedure CopyFullScreenToOff(ASourcePage, ADestPage: word); virtual;
    procedure CopyFullOffToScreen(ASourcePage, ADestPage: word); virtual;
    destructor Free; virtual;
  end;

  TFontList = Object(TIdentifiableList)
  public
    function GetItemById(const AId: string): PFont;
    function GetItem(AIndex: integer): PFont;
    function Add(AItem: PFont): integer;
    function IndexOf(AItem: PFont): integer;
    procedure SetItem(AIndex: integer; AItem: PFont);
    procedure Insert(AIndex: integer; AItem: PFont);
  end;

  TFontManager = object(TStatusObject)
  private
  public
    function CreateFromFile(const AFilename: string): PFont;
    function CreateFromStream(AStream: PStream): PFont;
  end;

const
  CheckerFillPattern: TFillPattern =
  (
    $AAAA,
    $5555,
    $AAAA,
    $5555,
    $AAAA,
    $5555,
    $AAAA,
    $5555,
    $AAAA,
    $5555,
    $AAAA,
    $5555,
    $AAAA,
    $5555,
    $AAAA,
    $5555
  );

  CheckerLinePattern: TLinePattern = $AAAA;

  FontFormatNames: array[TFontFormat] of string =
  (
    'Monospace',
    'Proportional',
    'System',
    'Colored'
  );

var
  Graph: PGraphicsDriver;
  FontManager: TFontManager;
  LineBuffer: array[0..1599] of byte;

implementation

uses
  Dos,
  Lzw;

var
  PreviousExitProc: PProc;

function TGraphicsDriver.CreateGraphicsState: PGraphicsState;
begin
  CreateGraphicsState := New(PGraphicsState, Create);
end;

function TGraphicsDriver.CharWidth(AChar: char): integer;
begin
  if State^.OverrideFontWidth > 0 then
    CharWidth := State^.OverrideFontWidth
  else
    CharWidth := State^.Font^.TextWidth(AChar);
end;

procedure TGraphicsDriver.Init;
var
  oldMode: byte;
begin
  inherited Init;
  asm
    mov ah, 0Fh
    int 10h
    mov oldMode, al
  end;
  FOldMode := oldMode;
  OffScreenPage := 0;
  Modes.Create;
  Mode := nil;
  State := CreateGraphicsState;
  StateStack.Create;
  MoveTo(0, 0);
  BufferRect.Create;
end;

procedure TGraphicsDriver.RenderText(APX, APY, ALength: integer; AText: PChar);
begin
  Abstract;
end;

function TGraphicsDriver.GetScreenPointer(APX, APY: integer): PByte; assembler;
asm
  push ds
  les di, self
  lds si, es:[di].State
  mov ax, ds:[si].TGraphicsState.Bounds.TRect.Width
  xor bh, bh
  mov bl, ds:[si].TGraphicsState.Bpp
  mov cl, 3
  shr bx, cl
  mul bx
  mul APY
  add ax, APX
  les di, ds:[si].TGraphicsState.FrameBuffer
  add di, ax
  mov ax, di
  mov dx, es
  pop ds
end;

procedure TGraphicsDriver.SetViewport(var ARect: TRect);
begin
  State^.ViewPort.Assign(ARect);
end;

function TGraphicsDriver.ForeColor: longint;
begin
  ForeColor := State^.ForeColor;
end;

function TGraphicsDriver.BackColor: longint;
begin
  BackColor := State^.BackColor;
end;

function TGraphicsDriver.XPos: byte;
begin
  XPos := State^.XPos;
end;

function TGraphicsDriver.YPos: byte;
begin
  YPos := State^.YPos;
end;

procedure TGraphicsDriver.SetForeColor(AColor: longint);
begin
  State^.ForeColor := AColor;
end;

procedure TGraphicsDriver.SetBackColor(AColor: longint);
begin
  State^.BackColor := AColor;
end;

procedure TGraphicsDriver.SetFillPattern(APattern: PFillPattern);
begin
  State^.FillPattern := APattern;
end;

procedure TGraphicsDriver.SetLinePattern(APattern: PLinePattern);
begin
  State^.LinePattern := APattern;
end;

procedure TGraphicsDriver.ResetMode;
var
  oldMode: byte;
begin
  if not Assigned(Mode) then
    exit;
  oldMode := FOldMode;
  asm
    mov ah, 0
    mov al, [oldMode]
    int 10h
  end;
end;

procedure TGraphicsDriver.GetDrawRect(var ARect: TRect);
begin
  State^.Bounds.GetIntersection(State^.ViewPort, ARect);
  ARect.Intersect(Mode^.Bounds);
end;

function TGraphicsDriver.GetPixel(APX, APY: integer): byte;
var
  offset: longint;
  ptr: PByte;
  drawRect: TRect;
begin
  GetPixel := 0;
  State^.Bounds.GetIntersection(State^.ViewPort, drawRect);
  if not drawRect.Contains(APX, APY) then
    exit;
  ptr := GetScreenPointer(APX, APY);
  GetPixel := ptr^;
end;

procedure TGraphicsDriver.SetPixel(APX, APY: integer);
var
  ptr: PByte;
  drawRect: TRect;
begin
  State^.Bounds.GetIntersection(State^.ViewPort, drawRect);
  if not drawRect.Contains(APX, APY) then
    exit;
  ptr := GetScreenPointer(APX, APY);
  ptr^ := ForeColor;
end;

procedure TGraphicsDriver.SetMode(AMode: PGraphicsMode);
begin
  Mode := AMode;
  State^.ViewPort.SetDims(0, 0, Mode^.Width, Mode^.Height);
  State^.Bounds.SetRect(State^.ViewPort);
  Mode^.Bounds.SetRect(State^.ViewPort);
  State^.Bpp := AMode^.Bpp;
end;

procedure TGraphicsDriver.MoveTo(APX, APY: integer);
begin
  State^.XPos := APX;
  State^.YPos := APY;
end;

procedure TGraphicsDriver.LineTo(APX, APY: integer);
begin
  Line(State^.XPos, State^.YPos, APX, APY);
  State^.XPos := APX;
  State^.YPos := APY;
end;

procedure TGraphicsDriver.Line(AX1, AY1, AX2, AY2: integer);
begin
  Abstract;
end;

procedure TGraphicsDriver.Rectangle(ARect: TRect);
begin
  HLine(ARect.X, ARect.Y, ARect.Width);
  HLine(ARect.X, ARect.Bottom, ARect.Width);
  VLine(ARect.X, ARect.Y, ARect.Height);
  VLine(ARect.Right, ARect.Y, ARect.Height);
end;

procedure TGraphicsDriver.HLine(APX, APY, AWidth: integer);
begin
  Abstract;
end;

procedure TGraphicsDriver.VLine(APX, APY, AHeight: integer);
begin
  Abstract;
end;

procedure TGraphicsDriver.CopyToOffScreen(const ASource, ADest: TRect);
begin
  Abstract;
end;

procedure TGraphicsDriver.CopyFromOffScreen(const ASource, ADest: TRect);
begin
  Abstract;
end;

procedure TGraphicsDriver.CopyFullScreenToOff(ASourcePage, ADestPage: word);
begin
  Abstract;
end;

procedure TGraphicsDriver.CopyFullOffToScreen(ASourcePage, ADestPage: word);
begin
  Abstract;
end;


procedure TGraphicsDriver.FillRect(ARect: TRect);
var
  index: integer;
  tempColor: longint;
  rect: PRect;
begin
  tempColor := State^.ForeColor;
  State^.ForeColor := State^.BackColor;
  if ARect.IsEmpty then
    exit;
  ARect.Intersect(State^.ViewPort);
  for index := ARect.Y to ARect.Bottom do
    HLine(ARect.X, index, ARect.Width);
  State^.ForeColor := tempColor;
end;

procedure TGraphicsDriver.FillPattern(ARect: TRect);
var
  screen: PByte;
  px, py, sy, width, index: integer;
begin
  width := ARect.Width;
  for index := 0 to ARect.Height - 1 do begin
    sy := ARect.Y + index;
    screen := GetScreenPointer(ARect.X, sy);
    px := ARect.X mod 16;
    py := sy mod 16;
    HLinePattern(State^.FillPattern^[py], px, py, width);
  end;
end;

procedure TGraphicsDriver.HLinePattern(APattern: word; APX, APY, AWidth: integer);
begin
  Abstract;
end;

procedure TGraphicsDriver.VLinePattern(APattern: word; APX, APY, AHeight: integer);
var
  patternIndex: integer;
  fore, back: byte;
  screen: PByte;
  py: integer;
begin
  fore := State^.ForeColor;
  back := State^.BackColor;
  screen := GetScreenPointer(APX, APY);
  for patternIndex := 0 to AHeight - 1 do begin
    py := APY mod 16;
    if APattern and (1 shl py) > 0 then
      screen^ := fore
    else
      screen^ := back;
    Inc(screen, Mode^.Width);
    Inc(APY);
  end;
end;

procedure TGraphicsDriver.InverseHLine(APX, APY, AWidth: integer);
var
  drawRect: TRect;
  index: integer;
  screen: PByte;
begin
  GetDrawRect(drawRect);
  if HasException or (APY < drawRect.Y) or (APY > drawRect.Bottom) then
    exit;
  if APX < drawRect.X then begin
    Dec(AWidth, drawRect.X - APX);
    APX := drawRect.X;
  end;
  if APX + AWidth - 1 > drawRect.Right then
    AWidth := drawRect.Right - APX + 1;
  if AWidth <= 0 then
    exit;
  screen := GetScreenPointer(APX, APY);
  if State^.BufferMode then begin
    for index := 0 to AWidth - 1 do begin
      screen^ := screen^ xor 15;
      Inc(screen);
    end;
    exit;
  end;
  for index := 0 to AWidth - 1 do begin
    screen^ := screen^ xor 15;
    Inc(screen);
  end;
end;

procedure TGraphicsDriver.InverseVLine(APX, APY, AHeight: integer);
var
  index: integer;
  screen: PByte;
  drawRect: TRect;
begin
  GetDrawRect(drawRect);
  if HasException or (APX < drawRect.X) or (APX > drawRect.Right) then
    exit;
  if APY < drawRect.Y then begin
    Dec(AHeight, drawRect.Y - APY);
    APY := drawRect.Y;
  end;
  if APY + AHeight - 1 > drawRect.Bottom then
    AHeight := drawRect.Bottom - APY + 1;
  if AHeight <= 0 then
    exit;
  screen := GetScreenPointer(APX, APY);
  for index := APY to APY + AHeight - 1 do begin
    screen := GetScreenPointer(APX, index);
    screen^ := screen^ xor 15;
  end;
end;

procedure TGraphicsDriver.InverseRectangle(ARect: TRect);
begin
  Abstract;
end;

procedure TGraphicsDriver.BezierQuad(AP1: TPoint; AP2: TPoint; AControl: TPoint; AResolution: integer);
var
  v1, v2, v3: TVector2;
  previous, next: TVector2;
  value: integer;
  index: integer;
begin
  v1.CreatePoint(AP1);
  v2.CreatePoint(AControl);
  v3.CreatePoint(AP2);
  previous.CreateVector(v1);
  for index := 1 to AResolution do begin
    BezierInterpolationQuad(v1, v2, v3, index / AResolution, next);
    Line(Round(previous.X), Round(previous.Y), Round(next.X), round(next.Y));
    previous.Assign(next);
  end;
end;

procedure TGraphicsDriver.BezierCubic(AP1: TPoint; AP2: TPoint; AControl1: TPoint; AControl2: TPoint; AResolution: integer);
var
  v1, v2, v3, v4: TVector2;
  previous, next: TVector2;
  value: integer;
  index: integer;
begin
  v1.CreatePoint(AP1);
  v2.CreatePoint(AControl1);
  v3.CreatePoint(AControl2);
  v4.CreatePoint(AP2);
  previous.CreateVector(v1);
  for index := 1 to AResolution do begin
    BezierInterpolationCubic(v1, v2, v3, v4, index / AResolution, next);
    Line(Round(previous.X), Round(previous.Y), Round(next.X), round(next.Y));
    previous.Assign(next);
  end;
end;

procedure TGraphicsDriver.Ellipse(AX1, AY1, AX2, AY2: integer);
var
  halfX, halfY: integer;
begin
  if AX1 > AX2 then
    Swap(AX1, AX2);
  if AY1 > AY2 then
    Swap(AY1, AY2);
  halfX := (AX2 - AX1) div 2;
  halfY := (AY2 - AY1) div 2;
  EllipseCenter(AX1 + halfX, AY1 + halfY, halfX, halfY);
end;

procedure TGraphicsDriver.EllipseRect(ARect: TRect);
begin
  Ellipse(ARect.X, ARect.Y, ARect.Right, ARect.Bottom);
end;

procedure TGraphicsDriver.EllipsePoints(AP1, AP2: TPoint);
begin
  Ellipse(AP1.X, AP1.Y, AP2.X, AP2.Y);
end;

procedure TGraphicsDriver.EllipseCenter(APX, APY, ARadiusX, ARadiusY: integer);
var
  x, y: longint;
  dx, dY: longint;
  error: longint;
  twoASquared, twoBSquared : longint;
  stopX, stopY : longint;
begin
  if (ARadiusX = 0) or (ARadiusY = 0) then
    exit;
  twoASquared := 2 * longint(ARadiusX) * ARadiusX;
  twoBSquared := 2 * longint(ARadiusY) * ARadiusY;
  x := ARadiusX;
  y := 0;
  dx := longint(ARadiusY) * ARadiusY * (1 - 2 * longint(ARadiusX));
  dy := longint(ARadiusX) * ARadiusX;
  error := 0;
  stopX := twoBSquared * ARadiusX;
  stopY := 0;
  while stopX >= stopY do begin
    SetPixel(APX + x, APY + y);
    SetPixel(APX - x, APY + y);
    SetPixel(APX - x, APY - y);
    SetPixel(APX + x, APY - y);
    Inc(y);
    Inc(stopY, twoASquared);
    Inc(error, dy);
    Inc(dy, twoASquared);
    if 2 * error + dx > 0 then begin
      Dec(x);
      Dec(stopX, twoBSquared);
      Inc(error, dx);
      Inc(dx, twoBSquared);
    end;
  end;
  X := 0;
  Y := ARadiusY;
  dx := longint(ARadiusY) * ARadiusY;
  dy := longint(ARadiusX) * ARadiusX * (1 - 2 * longint(ARadiusY));
  error := 0;
  stopX := 0;
  stopY := twoASquared * ARadiusY;
  while stopX <= stopY do begin
    SetPixel(APX + x, APY + y);
    SetPixel(APX - x, APY + y);
    SetPixel(APX - x, APY - y);
    SetPixel(APX + x, APY - y);
    Inc(X);
    Inc(stopX, twoBSquared);
    Inc(error, dx);
    Inc(dx, twoBSquared);
    if 2 * error + dy > 0 then begin
      Dec(Y);
      Dec(stopY, twoASquared);
      Inc(error, dy);
      Inc(dy, twoASquared);
    end;
  end;
end;

procedure TGraphicsDriver.Circle(ACenterX, ACenterY, ARadius: integer);
var
  t1, t2: integer;
  x, y: integer;
  color: byte;
  drawRect: TRect;
  procedure SetPix(APX, APY: integer);
  var
    drawPtr: PByte;
  begin
    if not drawRect.Contains(APX, APY) then
      exit;
    drawPtr := GetScreenPointer(APX, APY);
    drawPtr^ := ForeColor;
  end;
begin
  GetDrawRect(drawRect);
  t1 := ARadius shr 4;
  x := ARadius;
  y := 0;
  color := State^.ForeColor;
  repeat
    SetPix(ACenterX + x, ACenterY + y);
    SetPix(ACenterX - x, ACenterY + y);
    SetPix(ACenterX + x, ACenterY - y);
    SetPix(ACenterX - x, ACenterY - y);
    SetPix(ACenterX + y, ACenterY + x);
    SetPix(ACenterX - y, ACenterY + x);
    SetPix(ACenterX + y, ACenterY - x);
    SetPix(ACenterX - y, ACenterY - x);
    Inc(y);
    Inc(t1, y);
    t2 := t1 - x;
    if t2 >= 0 then begin
      t1 := t2;
      Dec(x);
    end;
  until x < y;
end;


procedure TGraphicsDriver.DrawText(APX, APY: integer; AText: string);
var
  ptr: PChar;
begin
  if not Assigned(State^.Font) then
    exit;
  if Length(AText) = 0 then
    exit;
  ptr := @AText[1];
  RenderText(APX, APY, Length(AText), ptr);
end;

procedure TGraphicsDriver.DrawTextLarge(APX, APY: integer; AText: PChar);
var
  len: word;
begin
  if not Assigned(State^.Font) then
    exit;
  if not Assigned(AText) then
    exit;
  len := StrLen(AText);
  if len = 0 then
    exit;
  RenderText(APX, APY, len, AText);
end;

procedure TGraphicsDriver.GetImage(APX, APY, AWidth, AHeight: longint; ABuffer: PByte);
begin
  Abstract;
end;

procedure TGraphicsDriver.GetImageRect(ARect: TRect; ABuffer: PByte);
begin
  GetImage(ARect.X, ARect.Y, ARect.Width, ARect.Height, ABuffer);
end;

procedure TGraphicsDriver.GetImageStream(APX, APY, AWidth, AHeight: longint; AStream: PStream);
begin
  Abstract;
end;

procedure TGraphicsDriver.GetImageStreamRect(ARect: TRect; AStream: PStream);
begin
  GetImageStream(ARect.X, ARect.Y, ARect.Width, ARect.Height, AStream);
end;

procedure TGraphicsDriver.DrawImageCoords(APX, APY, AWidth, AHeight: integer;
  var AImage; AFlags: TImageFlags);
begin
  Abstract;
end;

procedure TGraphicsDriver.DrawImageZoom(const ARect: TRect; var AImage;
  AFlags: TImageFlags; AZoom: integer);
begin
  Abstract;
end;

procedure TGraphicsDriver.DrawBufferRect(const ASourceBounds, ASourceRect: TRect;
  const ADestPoint: TPoint; var ABuffer); virtual;
begin
  Abstract;
end;

procedure TGraphicsDriver.DrawImage(const ARect: TRect; var AImage;
  AFlags: TImageFlags);
begin
  DrawImageCoords(ARect.X, ARect.Y, ARect.Width, ARect.Height, AImage, AFlags);
end;

procedure TGraphicsDriver.GetImageDrawRects(APX, APY, AWidth, AHeight: longint;
  var AImageRect, ADrawRect: TRect);
begin
  AImageRect.CreateDims(APX, APY, AWidth, AHeight);
  Mode^.Bounds.GetIntersection(State^.ViewPort, ADrawRect);
  ADrawRect.Intersect(AImageRect);
  AImageRect.TranslateToOrigin;
end;

procedure TGraphicsDriver.PushState;
var
  newState: PGraphicsState;
begin
  newState := CreateGraphicsState;
  newState^.Assign(State^);
  StateStack.Push(newState);
end;

procedure TGraphicsDriver.SetDisplayPage(APage: word);
begin
  if Mode^.PageCount > 1 then
    State^.DisplayPage := APage;
end;

procedure TGraphicsDriver.SetDrawPage(APage: word);
begin
  if Mode^.PageCount > 1 then
    State^.DrawPage := APage;
end;

procedure TGraphicsDriver.BeginDrawBuffer(var ABuffer: PByte; var ABounds: TRect);
var
  size: word;
begin
  if not Assigned(ABuffer) then begin
    size := ABounds.Width * ABounds.Height;
    GetMem(ABuffer, size);
    if not Assigned(ABuffer) then begin
      Raise(ecNotEnoughMemory);
      exit;
    end;
  end;
  ABounds.TranslateToOrigin;
  State^.FrameBuffer := ABuffer;
  State^.ViewPort.Assign(ABounds);
  State^.Bounds.Assign(ABounds);
  State^.BufferMode := true;
end;

procedure TGraphicsDriver.EndDrawBuffer;
begin
  State^.BufferMode := false;
  State^.FrameBuffer := Mode^.FrameBuffer;
end;

procedure TGraphicsDriver.PopState;
var
  oldState: PGraphicsState;
begin
  oldState := PGraphicsState(StateStack.Pop);
  if not Assigned(oldState) then
    exit;
  State^.Assign(oldState^);
  SetDrawPage(State^.DrawPage);
  SetDisplayPage(State^.DisplayPage);
  FreeAndNil(oldState);
end;

procedure TGraphicsDriver.Fill(AX1, AY1, AWidth, AHeight: integer);
var
  rect: TRect;
begin
  rect.CreateDims(AX1, AY1, AWidth, AHeight);
end;

destructor TGraphicsDriver.Free;
begin
  ResetMode;
  Modes.Free;
  FreeAndNil(State);
  StateStack.DisposeObjects := true;
  StateStack.Free;
  inherited Free;
end;

procedure TGraphicsDriver.WaitForVSync;
begin
  Abstract;
end;

procedure TGraphicsMode.Init;
begin
  inherited Init;
  ModeId := 0;
  Width := 0;
  Height := 0;
  MaxX := 0;
  MaxY := 0;
  Bpp := 0;
  PageCount := 1;
  Bounds.Create;
  ModeIndex := 0;
  BytesPerScanLine := 0;
  HelpText := nil;
  Description := nil;
  FrameBuffer := nil;
  HelpText := nil;
  MaxPage := 1;
end;

destructor TGraphicsMode.Free;
begin
  TString.Free(HelpText);
  TString.Free(Description);
  inherited Free;
end;

procedure TGraphicsMode.Assign(var ASource: TObject);
var
  mode: PGraphicsMode;
begin
  inherited Assign(ASource);
  mode := PGraphicsMode(@ASource);
  Width := mode^.Width;
  Height := mode^.Height;
  PageCount := mode^.PageCount;
  MaxX := mode^.MaxX;
  MaxY := mode^.MaxY;
  Bounds.SetRect(mode^.Bounds);
  Bpp := mode^.Bpp;
  ModeIndex := mode^.ModeIndex;
  TString.Free(Description);
  TString.Free(HelpText);
  Description := TString.Copy(mode^.Description);
  HelpText:= TString.Copy(mode^.HelpText);
  BytesPerScanLine := mode^.BytesPerScanLine;
  FrameBuffer := mode^.FrameBuffer;
end;

function TGraphicsModeList.GetItem(AIndex: integer): PGraphicsMode;
begin
  GetItem := PGraphicsMode(inherited GetItem(AIndex));
end;

function TGraphicsModeList.GetItemById(const AID: string): PGraphicsMode;
begin
  GetItemById := PGraphicsMode(inherited GetItemById(AId));
end;

function TGraphicsModeList.GetModeById(AModeId: integer): PGraphicsMode;
var
  index: integer;
  mode: PGraphicsMode;
begin
  GetModeById := nil;
  for index := 0 to Count - 1 do begin
    mode := GetItem(index);
    if mode^.ModeId = AModeId then begin
      GetModeById := mode;
      exit;
    end;
  end;
end;

function TGraphicsModeList.Add(AItem: PGraphicsMode): integer;
begin
  Add := inherited Add(AItem);
end;

function TGraphicsModeList.IndexOf(AItem: PGraphicsMode): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TGraphicsModeList.SetItem(AIndex: integer; AItem: PGraphicsMode);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TGraphicsModeList.Insert(AIndex: integer; AItem: PGraphicsMode);
begin
  inherited Insert(AIndex, AItem);
end;

destructor TFont.Free;
begin
  if Assigned(FFontData) then
    FreeMem(FFontData, FFontDataSize);
  inherited Free;
end;

procedure TFont.Assign(var ASource: TObject);
var
  source: PFont;
begin
  inherited Assign(ASource);
  source := PFont(@ASource);
  Version := source^.Version;
  TransparentColor := source^.TransparentColor;
  Transparent := source^.Transparent;
  Height := source^.Height;
  MaxWidth := source^.MaxWidth;
  AverageWidth := source^.AverageWidth;
  Spacing := source^.Spacing;
  BytesPerCharLine := source^.BytesPerCharLine;
  FFormat := source^.FFormat;
  if Assigned(FFontData) then
    FreeMem(FFontData, FFontDataSize);
  FFontDataSize := source^.FFontDataSize;
  GetMem(FFontData, source^.FFontDataSize);
  Move(source^.FFontData^, FFontData^, source^.FFontDataSize);
end;

procedure TFont.Init;
begin
  inherited Init;
  Version := 1.0;
  TransparentColor := 0;
  Transparent := true;
  Height := 0;
  AverageWidth := 0;
  MaxWidth := 0;
  FFontData := nil;
  FFontDataSize := 0;
  FFormat := ffProportional;
  Spacing := 2;
  BytesPerCharLine := 2;
end;

constructor TFont.CreateSize(AMaxWidth, AHeight, ASpacing: byte);
begin
  inherited Create;
  MaxWidth := AMaxWidth;
  Height := AHeight;
  Spacing := ASpacing;
end;

function TFont.CharWidth(AChar: char): integer;
begin
  Abstract;
end;

function TFont.TextWidthAny(AText: PChar; ALength: word): longint;
begin
  Abstract;
end;

function TFont.TextWidth(const AText: string): longint;
var
  textPtr: PChar;
begin
  TextWidth := 0;
  if Length(AText) = 0 then
    exit;
  textPtr := @AText[1];
  TextWidth := TextWidthAny(textPtr, Length(AText));
end;

function TFont.TextWidthLarge(AText: PChar): longint;
begin
  TextWidthLarge := TextWidthAny(AText, StrLen(AText));
end;

function TFont.FontData: PByte;
begin
  FontData := FFontData;
end;

function TFont.FontDataSize: word;
begin
  FontDataSize := FFontDataSize;
end;

procedure TFont.SetCharWidths;
begin
  Abstract;
end;

procedure TFont.SetFormat(AFormat: TFontFormat);
begin
  FFormat := AFormat;
end;

function TFont.Format: TFontFormat;
begin
  Format := FFormat;
end;

function TFont.IsPixelSet(AChar: char; APX, APY: integer): boolean;
var
  ptr: PByte;
  px, currentLine: word;
  shift: word;
begin
  ptr := FontData;
  shift := BytesPerCharLine * 8 - 1 - APX;
  Inc(ptr, BytesPerCharLine * (Ord(AChar) * Height + APY));
  if BytesPerCharLine > 1 then
    currentLine := PWord(ptr)^
  else
    currentLine := ptr^;
  px := 1 shl shift;
  IsPixelSet := currentLine and px > 0;
end;

procedure TFont.SetPixel(AChar: char; APX, APY: integer);
var
  ptr: PByte;
  shift: word;
  px, currentLine: word;
begin
  ptr := FFontData;
  shift := BytesPerCharLine * 8 - 1 - APX;
  Inc(ptr, BytesPerCharLine * (Ord(AChar) * Height + APY));
  if BytesPerCharLine > 1 then
    currentLine := PWord(ptr)^
  else
    currentLine := ptr^;
  px := 1 shl shift;
  if currentLine and px > 0 then
    exit;
  if BytesPerCharLine > 1 then
    PWord(ptr)^ := currentLine or px
  else
    ptr^ := currentLine or px;
end;

procedure TFont.ClearPixel(AChar: char; APX, APY: integer);
var
  ptr: PByte;
  shift: word;
  px, currentLine: word;
begin
  ptr := FontData;
  shift := BytesPerCharLine * 8 - 1 - APX;
  Inc(ptr, BytesPerCharLine * (Ord(AChar) * Height + APY));
  if BytesPerCharLine > 1 then
    currentLine := PWord(ptr)^
  else
    currentLine := ptr^;
  px := 1 shl shift;
  if currentLine and px = 0 then
    exit;
  if BytesPerCharLine > 1 then
    PWord(ptr)^ := currentLine and not px
  else
    ptr^ := currentLine and not px;
end;

constructor TMonospaceFont.CreateSize(AWidth, AHeight, ASpacing: byte);
var
  size: word;
begin
  inherited CreateSize(AWidth, AHeight, 0);
  size := 256;
  BytesPerCharLine := 1;
  if AWidth > 8 then begin
    size := 512;
    BytesPerCharLine := 2;
  end;
  FFontDataSize := AHeight * size;
  GetMem(FFontData, FFontDataSize);
  FillChar(FFontData^, FFontDataSize, 0);
end;

procedure TMonospaceFont.Init;
begin
  inherited Init;
  FFormat := ffMonospace;
end;

function TMonospaceFont.CharWidth(AChar: char): integer;
begin
  CharWidth := MaxWidth;
end;

function TMonospaceFont.TextWidthAny(AText: PChar; ALength: word): longint;
var
  index: integer;
  total: integer;
begin
  total := 0;
  for index := 1 to ALength do begin
    if (AText^ = #13) or (AText^ = #10) then
      continue;
    Inc(total, MaxWidth + Spacing);
  end;
  TextWidthAny := total;
end;

procedure TMonospaceFont.SetCharWidths;
begin
end;

destructor TMonospaceFont.Free;
begin
  inherited Free;
end;

procedure TMonospaceFont.Assign(var ASource: TObject);
var
  source: PMonospaceFont;
begin
  inherited Assign(ASource);
  source := PMonospaceFont(@ASource);
end;

constructor TProportionalFont.CreateSize(AMaxWidth, AHeight, ASpacing: byte);
var
  size: word;
begin
  inherited CreateSize(AMaxWidth, AHeight, ASpacing);
  FillChar(CharWidths, SizeOf(CharWidths), MaxWidth);
  size := 256;
  BytesPerCharLine := 1;
  if AMaxWidth > 8 then begin
    size := 512;
    BytesPerCharLine := 2;
  end;
  FFontDataSize := AHeight * size;
  GetMem(FFontData, FFontDataSize);
  FillChar(FFontData^, FFontDataSize, 0);
end;

procedure TProportionalFont.Init;
begin
  inherited Init;
  MaxWidth := 8;
  AverageWidth := 0;
  FFormat := ffProportional;
  FillChar(CharWidths, SizeOf(CharWidths), 0);
end;

destructor TProportionalFont.Free;
begin
  inherited Free;
end;

function TProportionalFont.TextWidthAny(AText: PChar; ALength: word): longint;
var
  index: word;
  total: longint;
  ptr: PChar;
begin
  TextWidthAny := 0;
  if not Assigned(AText) then
    exit;
  total := 0;
  ptr := AText;
  for index := 1 to ALength do begin
    Inc(total, CharWidths[Ord(ptr^)]);
    Inc(total, Spacing);
    Inc(ptr);
  end;
  TextWidthAny := total;
end;

procedure TProportionalFont.Assign(var ASource: TObject);
var
  source: PProportionalFont;
begin
  inherited Assign(ASource);
  source := PProportionalFont(@ASource);
  CharWidths := source^.CharWidths;
end;

function TProportionalFont.CharWidth(AChar: char): integer;
begin
  CharWidth := CharWidths[Ord(AChar)];
end;

procedure TProportionalFont.SetCharWidths;
var
  avgCount, avgTotal, charIndex, xIndex, yIndex: integer;
  linePtr: PByte;
  line: word;
  width, shift: word;
begin
  avgCount := 0;
  avgTotal := 0;
  shift := 1 shl (BytesPerCharLine * 8 - 1);
  for charIndex := 0 to High(byte) do begin
    width := 0;
    linePtr := FFontData;
    Inc(linePtr, charIndex * Height * BytesPerCharLine);
    for yIndex := 0 to Height - 1 do begin
      if BytesPerCharLine > 1 then
        line := PWord(linePtr)^
      else
        line := linePtr^;
      for xIndex := 0 to MaxWidth - 1 do begin
        if (line and (shift shr xIndex)) > 0 then
          width := MaxW(xIndex, width);
      end;
      Inc(linePtr, BytesPerCharLine);
    end;
    if (width > 0) and not (Chr(charIndex) in WhiteSpaceChars + [#32]) then begin
      Inc(AvgTotal);
      Inc(AvgCount, width);
    end;
    Inc(width);
    CharWidths[charIndex] := width;
  end;
  AverageWidth := Max(1, Round(avgCount / Max(1, avgTotal)) - 1);
  if CharWidths[32] <= 1 then
    CharWidths[32] := AverageWidth;
  CharWidths[10] := 0;
  CharWidths[13] := 0;
end;

procedure TFont.SaveToStream(AStream: PStream);
var
  header: TFontHeader;
  lzw: TLzw;
  stream: TMemoryStream;
begin
  FillChar(header, SizeOf(header), 0);
  header.MajorVersion := FontMajorVersion;
  header.MinorVersion := FontMinorVersion;
  header.Name := GetId;
  header.DataSize := FFontDataSize;
  header.MaxWidth := MaxWidth;
  header.Height := Height;
  header.Compression := acLzw;
  header.CompressionLevel := clHigh;
  header.Spacing := Spacing;
  header.Format := format;
  header.BytesPerCharLine := BytesPerCharLine;
  SetCharWidths;
  stream.Create(FFontDataSize);
  stream.Write(PByte(FFontData), FFontDataSize);
  stream.Seek(0, soFromBeginning);
  if stream.HasException then
    Raise(stream.Exception^.Code)
  else begin
    AStream^.Write(@header, SizeOf(header));
    if AStream^.HasException then
      Raise(AStream^.Exception^.Code)
    else begin
      lzw.CreateBitSize(LzwCompressionBitSize[header.CompressionLevel]);
      lzw.CompressStream(@stream, AStream, FFontDataSize);
      if lzw.HasException then
        Raise(lzw.Exception^.Code);
      lzw.Free;
    end;
  end;
  stream.Free;
end;

procedure TFont.AdjustSize(var AHeader: TFontHeader; ASize: word);
var
  buffer: PByte;
  dataPtr, bufferPtr: PByte;
  charIndex, yIndex: integer;
  dataBytes: integer;
begin
  GetMem(buffer, ASize);
  FillChar(buffer^, ASize, 0);
  if not Assigned(FFontData) then begin
    Raise(ecNotEnoughMemory);
    exit;
  end;
  dataBytes := AHeader.DataSize div 256 div AHeader.Height;
  BytesPerCharLine := ASize div 256 div AHeader.Height;
  dataPtr := PByte(FFontData);
  Inc(dataPtr);
  bufferPtr := buffer;
  for charIndex := 0 to 255 do begin
    for yIndex := 0 to AHeader.Height - 1 do begin
      Move(dataPtr^, bufferPtr^, BytesPerCharLine);
      Inc(dataPtr, DataBytes);
      Inc(bufferPtr, BytesPerCharLine);
    end;
  end;
  FreeMem(FFontData, FFontDataSize);
  FFontDataSize := ASize;
  FFontData := buffer;
end;

procedure TFont.LoadFromStream(AStream: PStream);
var
  header: TFontHeader;
  stream: TMemoryStream;
  lzw: TLzw;
  index: integer;
  lineIndex: integer;
  ptr: PByte;
  size: word;
begin
  AStream^.Read(@header, SizeOf(header));
  if AStream^.HasException then begin
    Raise(AStream^.Exception^.Code);
    exit;
  end;
  if (header.MajorVersion > FontMajorVersion) or (header.MinorVersion > FontMinorVersion) then begin
    Raise(ecFontVersionNotSupported);
    exit;
  end;
  if Assigned(FFontData) then
    FreeMem(FFontData, FontDataSize);

  SetId(header.Name);
  BytesPerCharLine := header.BytesPerCharLine;
  if BytesPerCharLine = 0
    then BytesPerCharLine := 2;

  size := (header.MaxWidth div 9 + 1) * header.Height * 256;
  GetMem(FFontData, header.DataSize);
  if not Assigned(FFontData) then begin
    Raise(ecNotEnoughMemory);
    exit;
  end;
  FFontDataSize := header.DataSize;
  stream.Create(header.DataSize);
  if stream.HasException then begin
    FreeMem(FFontData, header.DataSize);
    Raise(stream.Exception^.Code);
  end
  else begin
    case header.Compression of
      acNone: begin
      end;
      acLzw: begin
        if (header.MajorVersion = 1) and (header.MinorVersion < 1) then
          lzw.CreateBitSize(13)
        else
          lzw.CreateBitSize(LzwCompressionBitSize[header.CompressionLevel]);
        lzw.DecompressStream(AStream, @stream, header.DataSize);
        CheckReRaise(@lzw);
        lzw.Free;
        stream.Seek(0, soFromBeginning);
        stream.Read(PByte(FFontData), header.DataSize);
        if stream.HasException then
          Raise(stream.Exception^.Code)
        else begin
          if size < header.DataSize then
            AdjustSize(header, size);
          Height := header.Height;
          Spacing := header.Spacing;
          MaxWidth := header.MaxWidth;
          SetCharWidths;
        end;
      end
      else
        Raise(ecFontCompressionNotSupported)
    end;
  end;
  stream.Free;
end;

constructor TColoredFont.CreateSize(AMaxWidth, AHeight, ASpacing: byte);
begin
  inherited CreateSize(AMaxWidth, AHeight, ASpacing);
  FillChar(CharWidths, SizeOf(CharWidths), MaxWidth);
  FFontDataSize := Height * (StartChar - EndChar) * 2;
  GetMem(FFontData, FontDataSize);
  FillChar(FFontData^, FontDataSize, 0);
end;

procedure TColoredFont.Init;
begin
  inherited Init;
  FFormat := ffColored;
  StartChar := 32;
  EndChar := 126;
end;

destructor TColoredFont.Free;
begin
  inherited Free;
end;

procedure TColoredFont.Assign(var ASource: TObject);
var
  source: PColoredFont;
begin
  inherited Assign(ASource);
end;

function TSystemFont.TextWidthAny(AText: PChar; ALength: word): longint;
begin
  TextWidthAny := inherited TextWidthAny(AText, ALength);
end;

procedure TSystemFont.SetTextFont(AFontIndex: byte);
var
  data: pointer;
begin
  data := FFontData;
  asm
    mov bl, AFontIndex
    les di, self
    mov bh, es:[di].TFont.Height
    push bp
    mov ax, 1100h
    mov cx, 00FFh
    xor dx, dx
    les di, data
    mov bp, di
    int 10h
    pop bp

    mov ax, 1103h
    xor bh, bh
    mov bl, AFontIndex
    mov cl, 2
    shl bl, cl
    add bl, AFontIndex
    int 10h
  end;
end;

procedure TSystemFont.Init;
var
  regs: registers;
  fontPtr: pointer;
begin
  inherited Init;
  Id := TString.New('SystemFont');
  FontIndex := 0;
  Height := 16;
  MaxWidth := 8;
  AverageWidth := 8;
  FFormat := ffSystem;
  FillChar(regs, SizeOf(regs), 0);
  regs.ax := $1130;
  regs.bh := $06;
  intr($10, regs);
  fontPtr := Ptr(regs.es, regs.bp);
  FFontDataSize := 256 * Height;
  GetMem(FFontData, FFontDataSize);
  Move(fontPtr^, FFontData^, FFontDataSize);
  BytesPerCharLine := 1;
end;

destructor TSystemFont.Free;
begin
  asm
    les di, self
    mov ax, 1104h
    mov bl, es:[di].TFont.FontIndex
    int 10h
    mov ax, 1103h
    mov bl, 0
    int 10h
  end;
  inherited Free;
end;

function TSystemFont.CharWidth(AChar: char): integer;
begin
  CharWidth := 8;
end;

procedure TGraphicsState.Init;
begin
  inherited Init;
  DisplayPage := 0;
  DrawPage := 0;
  ForeColor := 0;
  BackColor := 0;
  Bpp := 0;
  XPos := 0;
  YPos := 0;
  Font := nil;
  ViewPort.Create;
  BufferMode := false;
  FrameBuffer := nil;
  Inverse := false;
  Bounds.Create;
  FillPattern := nil;
  LinePattern := nil;
  OverrideFontWidth := 0;
end;

procedure TGraphicsState.Assign(var ASource: TObject);
var
  state: PGraphicsState;
begin
  inherited Assign(ASource);
  state := PGraphicsState(@ASource);
  ForeColor := state^.ForeColor;
  BackColor := state^.BackColor;
  XPos := state^.XPos;
  YPos := state^.YPos;
  Font := state^.Font;
  Bpp := state^.Bpp;
  FrameBuffer := state^.FrameBuffer;
  ViewPort.SetRect(state^.ViewPort);
  Bounds.SetRect(state^.Bounds);
  BufferMode := state^.BufferMode;
  FillPattern := state^.FillPattern;
  LinePattern := state^.LinePattern;
  DisplayPage := state^.DisplayPage;
  DrawPage := state^.DrawPage;
  OverrideFontWidth := state^.OverrideFontWidth;
  Inverse := state^.Inverse;
end;

function TFontList.GetItem(AIndex: integer): PFont;
begin
  GetItem := PFont(inherited GetItem(AIndex));
end;

function TFontList.GetItemById(const AId: string): PFont;
begin
  GetItemById := PFont(inherited GetItemById(AId));
end;

function TFontList.Add(AItem: PFont): integer;
begin
  Add := inherited Add(AItem);
end;

function TFontList.IndexOf(AItem: PFont): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TFontList.SetItem(AIndex: integer; AItem: PFont);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TFontList.Insert(AIndex: integer; AItem: PFont);
begin
  inherited Insert(AIndex, AItem);
end;

function TFontManager.CreateFromStream(AStream: PStream): PFont;
var
  header: TFontHeader;
  font: PFont;
begin
  AStream^.Read(@header, SizeOf(header));
  if CheckReRaise(AStream) then
    exit;
  if (header.MajorVersion <= 1) and (header.MinorVersion <= 1) then begin
    Dec(header.Format, 2);
  end;
  AStream^.Seek(0, soFromBeginning);
  case header.Format of
    ffMonospace: font := New(PMonospaceFont, Create);
    ffProportional: font := New(PProportionalFont, Create);
    ffColored: font := New(PColoredFont, Create);
    ffSystem: font := New(PSystemFont, Create);
  end;
  if NilPtr(font, ecNotEnoughMemory) then
    exit;
  font^.LoadFromStream(AStream);
  CheckReRaise(AStream);
  CreateFromStream := font;
end;

function TFontManager.CreateFromFile(const AFilename: string): PFont;
var
  stream: TFileStream;
  font: PFont;
  header: TFontHeader;
begin
  stream.Create(AFilename, fmRead);
  if stream.HasException then begin
    stream.Free;
    exit;
  end;
  CreateFromFile := CreateFromStream(@stream);
  stream.Free;
end;

procedure Finalize; far;
begin
  ExitProc := PreviousExitProc;
  FreeAndNil(Graph);
  FontManager.Free;
end;

begin
  Graph := nil;
  FontManager.Create;
  PreviousExitProc := ExitProc;
  ExitProc := @Finalize;
end.
