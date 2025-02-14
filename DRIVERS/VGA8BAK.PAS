{$I COMPILER.INC}
unit Vga8Drv;

interface

uses
  Graphics,
  Gr8Drv,
  AplMath,
  AplConst,
  AplUtils,
  AplTypes,
  Streams,
  Drawing;

type
  PVga8Driver = ^TVga8Driver;

  TVga8Driver = object(TGraphics8Driver)
  private
    function InitializeDrawRect(APX, APY, AWidth, AHeight: integer; var ADrawRect: TRect): boolean;
  public
    procedure GetImage(APX, APY, AWidth, AHeight: longint; ABuffer: PByte); virtual;
    procedure GetImageStream(APX, APY, AWidth, AHeight: longint; AStream: PStream); virtual;
    procedure SetMode(AMode: PGraphicsMode); virtual;
    procedure RenderText(APX, APY, ALength: integer; AText: PChar); virtual;
    procedure Line(AX1, AY1, AX2, AY2: integer); virtual;
    procedure HLine(APX, APY, AWidth: integer); virtual;
    procedure VLine(ApX, APY, AHeight: integer); virtual;
    procedure FillRect(ARect: TRect); virtual;
    procedure DrawImage(APX, APY, AWidth, AHeight: integer; AImage: PByte); virtual;
    procedure DrawImageT(APX, APY, AWidth, AHeight: integer; AImage: PByte); virtual;
    procedure DrawImageStream(APX, APY, AWidth, AHeight: integer; AStream: PStream); virtual;
    procedure DrawImageStreamT(APX, APY, AWidth, AHeight: integer; AStream: PStream); virtual;
    procedure WaitForVSync; virtual;
    procedure Init; virtual;
    destructor Free; virtual;
  end;

implementation

uses
  MouseDrv,
  Palettes,
  AplStr;

procedure TVga8Driver.Init;
var
  newMode: PGraphicsMode;
  desc: string;
begin
  inherited Init;
  newMode := New(PGraphicsMode, Create);
  with newMode^ do begin
    ModeId := $13;
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
    Bpp := 8;
    BytesPerScanLine := 320;
    ScreenSize := 64000;
    HelpText := TString.New('Requires a VGA card.');
    FrameBuffer := Ptr($A000, $0000);
  end;
  Modes.Add(newMode);
end;

procedure TVga8Driver.SetMode(AMode: PGraphicsMode);
begin
  inherited SetMode(AMode);
  asm
    mov ah, 0
    mov al, 13h
    int 10h
  end;
  State^.FrameBuffer := Mode^.FrameBuffer;
  State^.ViewPort.SetDims(0, 0, Mode^.Width, Mode^.Height);
  SetVgaPalette;
  Mouse.XShift := 1;
end;

procedure TVga8Driver.WaitForVSync;
begin
  asm
    mov dx, 3DAh
    @loop:
    in al, dx
    test al, 8h
    jz @loop
  end;
end;

function TVga8Driver.InitializeDrawRect(APX, APY, AWidth, AHeight: integer; var ADrawRect: TRect): boolean;
var
  visibleRect: TRect;
begin
  InitializeDrawRect := false;
  State^.Bounds.GetIntersection(State^.ViewPort, ADrawRect);
  ADrawRect.Intersect(Mode^.Bounds);
  if not ADrawRect.IsEmpty then
    InitializeDrawRect := true;
end;

procedure TVga8Driver.RenderText(APX, APY, ALength: integer; AText: PChar);
var
  drawRect: TRect;
  ch: char;
  sx, sy, minX, maxX, maxY, xIndex, charIndex, width, height: integer;
  currentLine, shift, initialShift: word;
  linePtr, screen: PByte;
  fore: byte;
  offset: longint;
  font: PFont;
begin
  if HasException then
    exit;
  GetDrawRect(drawRect);
  height := State^.Font^.Height;
  font := State^.Font;
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
    if sx > drawRect.Right then
      exit;
    if sx + width < drawRect.X then begin
      Inc(sx, width);
      continue;
    end;
    minX := Max(0, drawRect.X - sx);
    maxX := Min(width - 1, drawRect.Right - sx);
    sy := Max(drawRect.Y, APY);
    initialShift := 1 shl (font^.BytesPerCharLine * 8 - 1);
    while sy <= maxY do begin
      screen := GetScreenPointer(sx + minX, sy);
      linePtr := font^.FontData;
      Inc(linePtr, font^.BytesPerCharLine * Ord(ch) * height + (sy - APY));
      if font^.BytesPerCharLine > 1 then
        currentLine := PWord(linePtr)^
      else
        currentLine := linePtr^;
      Inc(linePtr, font^.BytesPerCharLine);
      shift := initialShift shr minX;
      for xIndex := minX to maxX do begin
        if currentLine and shift > 0 then
          screen^ := fore;
        Inc(screen);
        shift := shift shr 1;
      end;
      Inc(sy);
    end;
    Inc(sx, width);
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
  GetDrawRect(drawRect);
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

procedure TVga8Driver.Line(AX1, AY1, AX2, AY2: integer);
var
  aError, aError2, sx, sy, dlx, dly: integer;
  screenPtr: PByte;
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
  drawRect.GetCoords(x, y, right, bottom);
  screenPtr := State^.FrameBuffer;
  width := Mode^.Width;
  color := State^.ForeColor;
  asm
    mov cx, aError
    @loop:
      mov ax, AX1
      mov bx, x
      cmp ax, bx
      jl @xCompare
      mov bx, right
      cmp ax, bx
      jg @xCompare
      mov ax, AY1
      mov bx, y
      cmp ax, bx
      jl @xCompare
      mov bx, bottom
      cmp ax, bx
      jg @xCompare
      les di, screenPtr
      mov ax, AY1
      mov bx, width
      mul bx
      add ax, AX1
      add di, ax
      mov bl, color
      mov es:[di], bl
    @xCompare:
      mov ax, AX1
      mov bx, AX2
      cmp ax, bx
      jne @continue
      mov ax, AY1
      mov bx, AY2
      cmp ax, bx
      jne @continue
      jmp @endLoop
    @continue:
      mov dx, cx
      shl dx, 1
      mov ax, dly
      cmp dx, ax
      jl @yCompare
      mov ax, AX1
      mov bx, AX2
      cmp ax, bx
      je @endLoop
      add cx, dly
      add ax, sx
      mov AX1, ax
    @yCompare:
      mov ax, dlx
      cmp dx, ax
      jg @loop
      mov AX, AY1
      mov bx, AY2
      cmp ax, dx
      je @endLoop
      add cx, dlx
      add ax, sy
      mov AY1, ax
      jmp @loop
    @endLoop:
  end;
end;

procedure TVga8Driver.HLine(APX, APY, AWidth: integer);
var
  screen: PByte;
  lineWidth: integer;
  color: byte;
  drawRect: TRect;
  px, py: integer;
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
  if Assigned(State^.LinePattern) then begin
    px := APX mod 16;
    py := APY;
    HLinePattern(State^.LinePattern^, px, py, AWidth);
    exit;
  end;
  color := byte(State^.ForeColor);
  asm
    mov cx, AWidth
    mov al, color
    les di, screen
    rep stosb
  end;
end;

procedure TVga8Driver.VLine(APX, APY, AHeight: integer);
var
  index: integer;
  screen: PByte;
  drawRect: TRect;
  min, max: integer;
  color: byte;
  screenWidth: word;
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

  if Assigned(State^.LinePattern) then begin
    screen := GetScreenPointer(APX, APY);
    VLinePattern(AHeight, State^.LinePattern^, APX, APY);
    exit;
  end;
  screen := GetScreenPointer(APX, APY);
  color := ForeColor;
  screenWidth := Mode^.BytesPerScanLine;
  asm
    mov ax, screenWidth
    mov cx, AHeight
    mov bl, color
    les di, screen
  @loop:
    mov es:[di], bl
    add di, ax
    loop @loop
  end;
end;

procedure TVga8Driver.DrawImage(APX, APY, AWidth, AHeight: integer; AImage: PByte);
var
  screen: PByte;
  imageRect, drawRect: TRect;
  index: integer;
  screenWidth: word;
begin
  if HasException then
    exit;
  GetImageDrawRects(APX, APY, AWidth, AHeight, imageRect, drawRect);
  if drawRect.IsEmpty then
    exit;
  screenWidth := Mode^.BytesPerScanline;
  screen := GetScreenPointer(drawRect.X, drawRect.Y);
  Inc(AImage, word(imageRect.Y) * AWidth + imageRect.X);
  index := drawRect.Height;
  asm
    push ds
    lds si, AImage
    les di, screen
    mov cx, drawRect.Height
    mov bx, imageRect.Width
    mov dx, drawRect.Width
    mov ax, screenWidth
    sub ax, dx
    sub bx, dx
    @yloop:
      push cx
      mov cx, dx
      rep movsb
      pop cx
      add di, ax
      add si, bx
    loop @yloop
    pop ds
  end;
end;

procedure TVga8Driver.DrawImageT(APX, APY, AWidth, AHeight: integer; AImage: PByte);
var
  imageRect, drawRect: TRect;
  screen: PByte;
  screenWidth: word;
  tcolor: byte;
begin
  if HasException then
    exit;
  GetImageDrawRects(APX, APY, AWidth, AHeight, imageRect, drawRect);
  if drawRect.IsEmpty then
    exit;
  screen := GetScreenPointer(drawRect.X, drawRect.Y);
  Inc(AImage, imageRect.Y * imageRect.Width + imageRect.X);
  screenWidth := Mode^.BytesPerScanline;
  tcolor := TransparentColor;
  asm
    push ds
    lds si, AImage
    les di, screen
    mov cx, drawRect.Height
    mov bx, imageRect.Width
    mov dx, drawRect.Width
    mov ax, screenWidth
    @yloop:
      push cx
      push ax
      mov cx, dx
      mov ah, tcolor
      @xLoop:
        cmp ds:[si], ah
        je @skip
        movsb
        jmp @next
        @skip:
        inc si
        inc di
        @next:
      loop @xLoop
      pop ax
      pop cx
      add di, ax
      sub di, dx
      add si, bx
      sub si, dx
    loop @yloop
    pop ds
  end;
end;

procedure TVga8Driver.DrawImageStream(APX, APY, AWidth, AHeight: integer; AStream: PStream);
var
  imageRect, drawRect: TRect;
  yIndex: word;
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
    AStream^.Seek((yIndex + imageRect.Y) * imageRect.Width + imageRect.X, soFromBeginning);
    AStream^.Read(screen, lineWidth);
    Inc(sy);
  end;
  if AStream^.HasException then
    Raise(AStream^.Exception^.Code);
end;

procedure TVga8Driver.DrawImageStreamT(APX, APY, AWidth, AHeight: integer; AStream: PStream);
var
  imageRect, drawRect: TRect;
  xIndex, yIndex: word;
  screen: PByte;
  imageLine: PByte;
  streamStart: longint;
  sy: integer;
  lineWidth: integer;
  tcolor: byte;
begin
  if AStream^.HasException or HasException then
    exit;
  GetImageDrawRects(APX, APY, AWidth, AHeight, imageRect, drawRect);
  if drawRect.IsEmpty then
    exit;
  lineWidth := drawRect.Width;
  GetMem(imageLine, lineWidth);
  if not Assigned(imageLine) then begin
    Raise(ecNotEnoughMemory);
    exit;
  end;
  streamStart := AStream^.Position;
  sy := drawRect.Y;
  AStream^.Seek((yIndex + imageRect.Y) * AWidth + imageRect.X, soFromPosition);
  tcolor := TransparentColor;
  for yIndex := 0 to drawRect.Height - 1 do begin
    screen := GetScreenPointer(drawRect.X, drawRect.Y + yIndex);
    AStream^.Seek(yIndex * imageRect.Width + imageRect.X, soFromBeginning);
    AStream^.Read(imageLine, lineWidth);
    asm
      push ds
      lds si, imageLine
      les di, screen
      mov cx, lineWidth
      mov bl, tcolor
      @loop:
        mov al, [ds:si]
        cmp al, bl
        je @equal
        movsb
        jmp @end
        @equal:
        inc di
        inc si
        @end:
      loop @loop
      pop ds
    end;
    Inc(sy);
  end;
  if AStream^.HasException then
    Raise(AStream^.Exception^.Code);
  FreeMem(imageLine, lineWidth);
end;

procedure TVga8Driver.GetImage(APX, APY, AWidth, AHeight: longint; ABuffer: PByte);
var
  imageRect, drawRect: TRect;
  yIndex: word;
  screen, image: PByte;
  sy: longint;
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
    Inc(image, (yIndex + imageRect.Y) * imageRect.Width);
    asm
      push ds
      lds si, screen
      les di, image
      mov cx, lineWidth
      rep movsb
      pop ds
    end;
    Inc(image, lineWidth);
    Inc(sy);
  end;
end;

procedure TVga8Driver.GetImageStream(APX, APY, AWidth, AHeight: longint; AStream: PStream);
var
  imageRect, drawRect: TRect;
  yIndex: word;
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
    AStream^.Seek((yIndex + imageRect.Y) * imageRect.Width + imageRect.X, soFromBeginning);
    AStream^.Write(screen, lineWidth);
    Inc(sy);
  end;
  if AStream^.HasException then
    Raise(AStream^.Exception^.Code);
end;

destructor TVga8Driver.Free;
begin
  inherited Free;
end;

end.