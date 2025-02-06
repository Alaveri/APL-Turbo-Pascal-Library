{$I COMPILER.INC}
unit Vga8Drv;

interface

uses
  AplTypes,
  AplConst,
  AplObj,
  Drawing,
  AplUtils,
  AplStr,
  AplMath,
  Streams,
  Graphics,
  Gr8Drv,
  MemDrv,
  Palettes,
  VbeTypes,
  Strings;

type
  PVga8Driver = ^TVga8Driver;

  TVgaPageArray = array[0..3] of PByte;
  TVga8Driver = object(TGraphics8Driver)
  private
    FVga8Driver: integer;
    FPages: TVgaPageArray;
    procedure CopyRect(const ASource, ADest: TRect; ASourcePage, ADestPage: word);
    function GetOffset(APX, APY: integer): word;
    function InternalGetScreenPointer(APX, APY, APage: integer): PByte;
  public
    function GetScreenPointer(APX, APY: integer): PByte; virtual;
    procedure GetImage(APX, APY, AWidth, AHeight: longint; ABuffer: PByte); virtual;
    procedure GetImageStream(APX, APY, AWidth, AHeight: longint; AStream: PStream); virtual;
    procedure SetMode(AMode: PGraphicsMode); virtual;
    procedure RenderText(APX, APY, ALength: integer; AText: PChar); virtual;
    procedure Line(AX1, AY1, AX2, AY2: integer); virtual;
    procedure HLine(APX, APY, AWidth: integer); virtual;
    procedure VLine(ApX, APY, AHeight: integer); virtual;
    procedure FillRect(ARect: TRect); virtual;
    procedure FillPattern(ARect: TRect); virtual;
    procedure HLinePattern(APattern: TLinePattern; APX, APY, AWidth: integer); virtual;
    procedure VLinePattern(APattern: word; APX, APY, AHeight: integer); virtual;
    procedure InverseHLine(APX, APY, AWidth: integer); virtual;
    procedure DrawImageCoords(APX, APY, AWidth, AHeight: integer;
      AImage: pointer; AFlags: TImageFlags); virtual;
    procedure CopyToOffScreen(const ASource, ADest: TRect); virtual;
    procedure CopyFromOffScreen(const ASource, ADest: TRect); virtual;
    procedure CopyFullScreenToOff(ASourcePage, ADestPage: word); virtual;
    procedure CopyFullOffToScreen(ASourcePage, ADestPage: word); virtual;
    procedure SetDisplayPage(APage: word); virtual;
    procedure SetDrawPage(APage: word); virtual;
    procedure WaitForVSync; virtual;
    procedure Init; virtual;
    destructor Free; virtual;
  end;

implementation

uses
  MouseDrv;

type
  TLineInfo = record
    Image: pointer;
    YIndex: integer;
    Start: longint;
    DrawRect: TRect;
    ImageRect: TRect;
    Screen: PByte;
    Driver: PVga8Driver;
  end;
  TDrawLineProc = procedure(const ALineInfo: TLineInfo);

procedure TVga8Driver.Init;
var
  newMode: PGraphicsMode;
  desc: string;
begin
  inherited Init;
  FillChar(FPages, SizeOf(FPages), 0);
  newMode := New(PGraphicsMode, Create);
  with newMode^ do begin
    ModeId := $13;
    ModeIndex := ModeId;
    desc := 'VGA '
      + IntToStr(320)
      + 'x'
      + IntToStr(200)
      + ' 256 Color';
    Description := TString.New(desc);
    Width := 320;
    Height := 200;
    MaxX := 319;
    MaxY := 199;
    Bounds.CreateDims(0, 0, 320, 200);
    Bpp := 8;
    BytesPerScanLine := 320;
    ScreenSize := 64000;
    HelpText := TString.New('Requires a VGA card.');
    FrameBuffer := Ptr($A000, $0000);
    PageCount := 2;
    FPages[0] := FrameBuffer;
    GetMem(FPages[1], ScreenSize);
    if not Assigned(FPages[1]) then begin
      Raise(ecNotEnoughMemory);
      FreeAndNil(newMode);
      exit;
    end;
    MaxPage := PageCount - 1;
  end;
  Modes.Add(newMode);
end;

function TVga8Driver.GetOffset(APX, APY: integer): word;
var
  temp: longint;
begin
  temp := longint(APY) * Mode^.BytesPerScanLine + APX;
  if temp > MaxVarSize then begin
    temp := temp;
  end;
  GetOffset := temp;
end;

function TVga8Driver.GetScreenPointer(APX, APY: integer): PByte;
begin
  GetScreenPointer := InternalGetScreenPointer(APX, APY, State^.DrawPage);
end;

function TVga8Driver.InternalGetScreenPointer(APX, APY, APage: integer): PByte;
var
  screen: PByte;
  offset: word;
begin
  if State^.BufferMode then begin
    screen := State^.FrameBuffer;
    offset := word(APY) * State^.Bounds.Width + APX;
    Inc(screen, offset);
  end
  else begin
    offset := GetOffset(APX, APY);
    screen := FPages[APage];
    Inc(screen, offset);
  end;
  InternalGetScreenPointer := screen;
end;

procedure TVga8Driver.SetMode(AMode: PGraphicsMode);
var
  selectedMode: word;
begin
  selectedMode := AMode^.ModeId;
  inherited SetMode(AMode);
  asm
    mov ax, selectedMode
    int 10h
  end;
  State^.FrameBuffer := Mode^.FrameBuffer;
  State^.ViewPort.SetDims(0, 0, Mode^.Width, Mode^.Height);
  State^.Bpp := AMode^.Bpp;
  SetVgaPalette;
  OffscreenPage := 1;
  Mouse.XShift := 1;
end;

procedure TVga8Driver.RenderText(APX, APY, ALength: integer; AText: PChar);
var
  drawRect: TRect;
  ch: char;
  sx, sy, minX, maxX, maxY, xIndex, charIndex, width, height: integer;
  currentLine, shift, initialShift, count: word;
  linePtr, screen: PByte;
  fore: byte;
  font: PFont;
begin
  if HasException then
    exit;
  GetDrawRect(drawRect);
  font := State^.Font;
  height := font^.Height;
  if drawRect.IsEmpty
    or (APX > drawRect.Right)
    or not RangeContains(APY, drawRect.Y - height, drawRect.Bottom) then
    exit;
  sx := APX;
  charIndex := 0;
  maxY := Min(drawRect.Bottom, APY + height - 1);
  fore := State^.ForeColor;
  while charIndex < ALength  do begin
    ch := AText[charIndex];
    Inc(charIndex);
    width := CharWidth(ch);
    width := CharWidth(ch);
    if sx > drawRect.Right then
      exit;
    if sx + width < drawRect.X then begin
      Inc(sx, width);
      continue;
    end;
    minX := Max(0, drawRect.X - sx);
    maxX := Min(width - 1, drawRect.Right - sx);
    count := maxX - minX + 1;
    sy := Max(drawRect.Y, APY);
    initialShift := 1 shl (font^.BytesPerCharLine * 8 - 1);
    linePtr := font^.FontData;
    Inc(linePtr, font^.BytesPerCharLine * (Ord(ch) * height + (sy - APY)));
    while sy <= maxY do begin
      screen := GetScreenPointer(sx + minX, sy);
      if font^.BytesPerCharLine > 1 then
        currentLine := PWord(linePtr)^
      else
        currentLine := linePtr^;
      Inc(linePtr, font^.BytesPerCharLine);
      shift := initialShift shr minX;
      asm
        les di, screen
        mov bx, shift
        mov cx, count
        mov dl, fore
      @loop:
        mov ax, currentLine
        and ax, bx
        jz @skip
        mov es:[di], dl
      @skip:
        shr bx, 1
        inc di
        loop @loop
      end;
      Inc(sy);
    end;
    Inc(sx, width);
  end;
end;

procedure TVga8Driver.Line(AX1, AY1, AX2, AY2: integer);
var
  aError, aError2, sx, sy, dlx, dly: integer;
  x, y, right, bottom, width: integer;
  color: byte;
  drawRect: TRect;
begin
  GetDrawRect(drawRect);
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
  x := drawRect.X;
  y := drawRect.Y;
  right := drawRect.Right;
  bottom := drawRect.Bottom;
  width := Mode^.Width;
  color := State^.ForeColor;
  while true do begin
    if State^.ViewPort.Contains(AX1, AY1) then
      GetScreenPointer(AX1, AY1)^ := color;
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

procedure TVga8Driver.FillPattern(ARect: TRect);
var
  screen: PByte;
  py, width, index: integer;
  drawRect: TRect;
begin
  if HasException then
    exit;
  State^.Bounds.GetIntersection(State^.ViewPort, drawRect);
  drawRect.Intersect(Mode^.Bounds);
  if drawRect.IsEmpty then
    exit;
  if not drawRect.IntersectsRect(ARect) then
    exit;
  ARect.Intersect(drawRect);
  width := ARect.Width;
  for index := ARect.Y to ARect.Y + ARect.Height - 1 do begin
    screen := GetScreenPointer(ARect.X, index);
    py := index mod 16;
    HLinePattern(State^.FillPattern^[py], ARect.X, index, width);
  end;
end;

procedure TVga8Driver.FillRect(ARect: TRect);
var
  screen: PByte;
  drawRect: TRect;
  width, index: integer;
  color: byte;
begin
  if HasException then
    exit;
  State^.Bounds.GetIntersection(State^.ViewPort, drawRect);
  drawRect.Intersect(Mode^.Bounds);
  if drawRect.IsEmpty then
    exit;
  if not drawRect.IntersectsRect(ARect) then
    exit;
  ARect.Intersect(drawRect);
  color := byte(State^.BackColor);
  width := ARect.Width;
  if Assigned(State^.FillPattern) then begin
    FillPattern(ARect);
    exit;
  end;
  for index := 0 to ARect.Height - 1 do begin
    screen := GetScreenPointer(ARect.X, ARect.Y + index);
    FillChar(screen^, width, color);
  end;
end;

procedure TVga8Driver.VLinePattern(APattern: word; APX, APY, AHeight: integer);
var
  patternIndex: integer;
  fore, back: byte;
  screen: PByte;
  py: integer;
  drawRect: TRect;
begin
  GetDrawRect(drawRect);
  fore := State^.ForeColor;
  back := State^.BackColor;
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
  for patternIndex := 0 to AHeight - 1 do begin
    py := APY mod 16;
    if APattern and (1 shl py) > 0 then begin
      if State^.Inverse then
        screen^ := screen^ xor 15
      else if fore <> TransparentColor then
        screen^ := fore;
    end
    else if back <> TransparentColor then
     screen^ := back;
    Inc(screen, Mode^.Width);
    Inc(APY);
  end;
end;

procedure TVga8Driver.HLinePattern(APattern: TLinePattern; APX, APY, AWidth: integer);
var
  patternIndex: integer;
  drawRect: TRect;
  fore, back: byte;
  screen: PByte;
  px: integer;
begin
  fore := State^.ForeColor;
  back := State^.BackColor;
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
  for patternIndex := APX to APX + AWidth - 1 do begin
    px := patternIndex mod 16;
    if APattern and (1 shl px) > 0 then begin
      if State^.Inverse then
        screen^ := screen^ xor 15
      else if fore <> TransparentColor then
        screen^ := fore;
    end
    else if back <> TransparentColor then
      screen^ := back;
    Inc(screen);
  end;
end;

procedure TVga8Driver.HLine(APX, APY, AWidth: integer);
var
  screen: PByte;
  color: byte;
  drawRect: TRect;
begin
  color := byte(State^.ForeColor);
  if color = TransparentColor then
    exit;
  if Assigned(State^.LinePattern) then begin
    HLinePattern(State^.LinePattern^, APX, APY, AWidth);
    exit;
  end;
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
  FillChar(screen^, AWidth, color);
end;

procedure TVga8Driver.VLine(APX, APY, AHeight: integer);
var
  index: integer;
  screen: PByte;
  drawRect: TRect;
  color: byte;
  width: word;
begin
  if State^.ForeColor = TransparentColor then
    exit;
  if Assigned(State^.LinePattern) then begin
    VLinePattern(State^.LinePattern^, APX, APY, AHeight);
    exit;
  end;
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
  color := byte(State^.ForeColor);
  width := Mode^.Width;
  for index := 0 to AHeight - 1 do begin
    screen^ := color;
    Inc(screen, width);
  end;
end;

procedure TVga8Driver.InverseHLine(APX, APY, AWidth: integer);
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

procedure DrawLineBuffer(const ALineInfo: TLineInfo);
var
  screenPtr, imagePtr: PByte;
  lineWidth, partialWidth: integer;
begin
  with ALineInfo, Driver^ do begin
    imagePtr := PByte(Image);
    screenPtr := Screen;
    Inc(imagePtr, (YIndex + ImageRect.Y) * ImageRect.Width + ImageRect.X);
    lineWidth := DrawRect.Width;
    Move(imagePtr^, screenPtr^, lineWidth);
  end;
end;

procedure DrawLineStream(const ALineInfo: TLineInfo);
var
  screenPtr, imagePtr: PByte;
  lineWidth, partialWidth: integer;
  stream: PStream;
  sy, yIndex: integer;
begin
  with ALineInfo, Driver^ do begin
    imagePtr := PByte(Image);
    screenPtr := Screen;
    stream^.Seek(Start + (YIndex + ImageRect.Y) * longint(ImageRect.Width) +
      ImageRect.X, soFromBeginning);
    lineWidth := DrawRect.Width;
    stream^.Read(screenPtr, lineWidth);
    Driver^.CheckReRaise(stream);
  end;
end;

procedure DrawTransparentLineBuffer(const ALineInfo: TLineInfo);
var
  screenPtr, imagePtr: PByte;
  xIndex, lineWidth, sy: integer;
begin
  with ALineInfo, Driver^ do begin
    imagePtr := PByte(Image);
    screenPtr := Screen;
    Inc(imagePtr, (YIndex + ImageRect.Y) * ImageRect.Width + ImageRect.X);
    lineWidth := DrawRect.Width;
    for xIndex := 0 to DrawRect.Width - 1 do begin
      if imagePtr^ <> TransparentColor then
        screenPtr^ := imagePtr^;
      Inc(imagePtr);
      Inc(screenPtr);
    end;
  end;
end;
procedure DrawTransparentLineStream(const ALineInfo: TLineInfo);
var
  sy: integer;
  imageStream: PStream;
  xIndex: integer;
  screenPtr: PByte;
  color: byte;
begin
  with ALineInfo, Driver^ do begin
    imageStream := PStream(Image);
    screenPtr := Screen;
    imageStream^.Seek(Start + (YIndex + ImageRect.Y) * longint(ImageRect.Width) +
      ImageRect.X, soFromBeginning);
    imageStream^.Read(@LineBuffer, ImageRect.Width);
    for xIndex := 0 to ImageRect.Width - 1 do begin
      color := LineBuffer[xIndex];
      if color <> TransparentColor then
        screen^ := color;
      Inc(screenPtr);
    end;
    Driver^.CheckReRaise(imageStream);
  end;
end;

procedure TVga8Driver.DrawImageCoords(APX, APY, AWidth, AHeight: integer;
  AImage: pointer; AFlags: TImageFlags);
var
  imageRect, drawRect: TRect;
  yIndex: longint;
  drawLine: TDrawLineProc;
  sy: integer;
  info: TLineInfo;
begin
  if HasException then
    exit;
  GetImageDrawRects(APX, APY, AWidth, AHeight, imageRect, drawRect);
  if drawRect.IsEmpty or imageRect.IsEmpty then
    exit;
  sy := drawRect.Y;
  if AFlags * [ifStreamed, ifTransparent] = [ifStreamed, ifTransparent] then
    drawLine := DrawTransparentLineStream
  else if AFlags * [ifStreamed, ifTransparent] = [ifStreamed] then
    drawLine := DrawLineStream
  else if AFlags * [ifTransparent] = [ifTransparent] then
    drawLine := DrawTransparentLineBuffer
  else
    drawLine := DrawLineBuffer;
  sy := drawRect.Y;
  info.Image := @AImage;
  info.DrawRect.CreateRect(drawRect);
  info.ImageRect.CreateRect(imageRect);
  info.Start := 0;
  info.Driver := @self;
  if AFlags * [ifStreamed] = [ifStreamed] then
    info.Start := PStream(AImage)^.Position;
  for yIndex := 0 to drawRect.Height - 1 do begin
    info.Screen := GetScreenPointer(DrawRect.X, sy + yIndex);
    info.YIndex := yIndex;
    drawLine(info);
    if HasException then
      break;
    Inc(sy);
  end;
end;

procedure TVga8Driver.SetDisplayPage(APage: word);
begin
end;

procedure TVga8Driver.SetDrawPage(APage: word);
begin
  inherited SetDrawPage(APage);
end;

procedure TVga8Driver.CopyRect(const ASource, ADest: TRect; ASourcePage, ADestPage: word);
var
  sx, dx, sy, dy: word;
  sourcePtr, destPtr: PByte;
  source, dest: TRect;
  lineWidth, nextLine: word;
  index: integer;
begin
  if HasException then
    exit;
  if Mode^.PageCount < 2 then
    exit;
  source.CreateRect(ASource);
  dest.CreateRect(ADest);
  if source.Equals(dest) and source.Equals(Mode^.Bounds) then begin
    sourcePtr := FPages[ASourcePage];
    destPtr := FPages[ADestPage];
    asm
      push ds
      les di, destPtr
      lds si, sourcePtr
      mov cx, 64000
      cld
      rep movsb
      pop ds
    end;
    exit;
  end;
  source.Intersect(Mode^.Bounds);
  dest.Intersect(Mode^.Bounds);
  source.Width := Min(source.Width, dest.Width);
  source.Height := Min(source.Height, dest.Height);
  dest.Width := source.Width;
  dest.Height := source.Height;
  if source.IsEmpty then
    exit;

  sx := source.X;
  sy := source.Y;
  dx := dest.X;
  dy := dest.Y;

  lineWidth := source.Width;
  nextLine := Mode^.Width - lineWidth;
  sourcePtr := InternalGetScreenPointer(sx, sy, ASourcePage);
  destPtr := InternalGetScreenPointer(dx, dy, ADestPage);
  for index := sy to source.Bottom do begin
    asm
      push ds
      lds si, sourcePtr
      les di, destPtr
      mov cx, lineWidth
      cld
      rep movsb
      add di, nextLine
      add si, nextLine
      mov word ptr sourcePtr, si
      mov word ptr destPtr, di
      pop ds
    end;
  end;
end;

procedure TVga8Driver.CopyFullScreenToOff(ASourcePage, ADestPage: word);
begin
  CopyRect(Mode^.Bounds, Mode^.Bounds, ASourcePage, ADestPage);
end;

procedure TVga8Driver.CopyFullOffToScreen(ASourcePage, ADestPage: word);
begin
  CopyRect(Mode^.Bounds, Mode^.Bounds, ASourcePage, ADestPage);
end;

procedure TVga8Driver.CopyFromOffScreen(const ASource, ADest: TRect);
begin
  CopyRect(ASource, ADest, OffscreenPage, 0);
end;

procedure TVga8Driver.CopyToOffScreen(const ASource, ADest: TRect);
begin
  CopyRect(ASource, ADest, 0, OffscreenPage);
end;

procedure TVga8Driver.GetImage(APX, APY, AWidth, AHeight: longint; ABuffer: PByte);
var
  imageRect, drawRect: TRect;
  yIndex: integer;
  screen, image: PByte;
  sy: word;
  lineWidth: integer;
begin
  if HasException then
    exit;
  GetImageDrawRects(APX, APY, AWidth, AHeight, imageRect, drawRect);
  if drawRect.IsEmpty then
    exit;
  sy := drawRect.Y;
  lineWidth := drawRect.Width;
  for yIndex := 0 to drawRect.Height - 1 do begin
    screen := GetScreenPointer(drawRect.X, sy);
    image := ABuffer;
    Inc(image, (yIndex + imageRect.Y) * imageRect.Width + imageRect.X);
    Move(screen^, image^, lineWidth);
    Inc(image, lineWidth);
    Inc(sy);
  end;
end;

procedure TVga8Driver.GetImageStream(APX, APY, AWidth, AHeight: longint; AStream: PStream);
var
  imageRect, drawRect: TRect;
  yIndex: integer;
  screen: PByte;
  sy: longint;
  lineWidth: integer;
  streamStart: longint;
begin
  if AStream^.HasException or HasException then
    exit;
  GetImageDrawRects(APX, APY, AWidth, AHeight, imageRect, drawRect);
  if drawRect.IsEmpty then
    exit;
  sy := drawRect.Y;
  lineWidth := drawRect.Width;
  streamStart := AStream^.Position;
  for yIndex := 0 to drawRect.Height - 1 do begin
    screen := GetScreenPointer(drawRect.X, sy);
    AStream^.Seek(streamStart + (yIndex + imageRect.Y) * longint(imageRect.Width) + imageRect.X, soFromBeginning);
    AStream^.Write(screen, lineWidth);
    Inc(sy);
  end;
  if AStream^.HasException then
    Raise(AStream^.Exception^.Code);
end;

procedure TVga8Driver.WaitForVSync; assembler;
asm
  mov dx, 3DAh
  @loop:
  in al, dx
  test al, 8h
  jz @loop
end;

destructor TVga8Driver.Free;
begin
  inherited Free;
end;

begin
end.
