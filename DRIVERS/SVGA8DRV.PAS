{$I COMPILER.INC}
unit SVga8Drv;

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
  PSVga8Mode = ^TSvga8Mode;
  PSvga8State = ^TSvga8State;
  PSVga8Driver = ^TSVga8Driver;

  TSvga8Mode = object(TGraphicsMode)
  private
  public
    Attributes: TVbeModeAttributes;
    WinSize: longint;
    WinFunc: pointer;
    Granularity: word;
    FullGranularity: longint;
    BankShift: word;
    BanksPerPage: word;
    NumPages: word;
    destructor Free; virtual;
    function PageBank(APage: word): word;
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    function PopulateMode(var AVbeMode: TVbeMode; var AVbeInfo: TVbeInfo;AIndex: integer): boolean;
  end;

  TSvga8State = object(TGraphicsState)
  private
    FCurrentBank: integer;
    FOwner: PSvga8Driver;
  public
    constructor Create(AOwner: PSVga8Driver);
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    destructor Free; virtual;
  end;

  TSVga8Driver = object(TGraphics8Driver)
  private
    FSVga8Driver: integer;
    FWinFunc: pointer;
    FMaxOffset: word;
    FVbeInfo: TVbeInfo;
    procedure SetBank(ABank: word);
    procedure CopyRect(const ASource, ADest: TRect; ASourcePage, ADestPage: word);
    function SetBankByCoord(APX, APY, APage: integer): longint;
    function GetOffset(APX, APY: integer): longint;
    function GetBankOffset(APX, APY: integer): longint;
    function SvgaState: PSVga8State;
    function InternalGetScreenPointer(APX, APY: integer; ASetBank: boolean;
      var AOffset: longint): PByte;
  public
    function GetScreenPointer(APX, APY: integer): PByte; virtual;
    function SVgaMode: PSVga8Mode;
    function CreateGraphicsState: PGraphicsState; virtual;
    function ModeFromVbeMode(var AVbeMode: TVbeMode; AIndex: integer): PSVga8Mode;
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
    procedure DrawImageZoom(const ARect: TRect; AImage: pointer; AFlags: TImageFlags;
      AZoom: integer); virtual;
    procedure DrawBufferRect(var ASourceBounds, ASourceRect: TRect;
      const ADestPoint: TPoint; ABuffer: pointer); virtual;
    procedure CopyToOffScreen(const ASource, ADest: TRect); virtual;
    procedure CopyFromOffScreen(const ASource, ADest: TRect); virtual;
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
    Offset: longint;
    Driver: PSvga8Driver;
  end;
  TDrawLineProc = procedure(const ALineInfo: TLineInfo);

procedure TSVga8Mode.Init;
begin
  inherited Init;
  WinSize := 0;
  Attributes := [];
  WinFunc := nil;
  Granularity := 0;
  FullGranularity := 0;
  BankShift := 0;
  BanksPerPage := 0;
  MaxPage := 0;
  PageCount := 0;
end;

procedure TSVga8Mode.Assign(var ASource: TObject);
var
  mode: PSVga8Mode;
begin
  inherited Assign(ASource);
  mode := PSVga8Mode(@ASource);
  Attributes := mode^.Attributes;
  WinSize := mode^.WinSize;
  WinFunc := mode^.WinFunc;
  Granularity := mode^.Granularity;
  FullGranularity := mode^.FullGranularity;
  BankShift := mode^.BankShift;
  BanksPerPage := mode^.BanksPerPage;
  NumPages := mode^.NumPages;
  MaxPage := mode^.MaxPage;
  PageCount := mode^.PageCount;
end;

destructor TSvga8Mode.Free;
begin
  inherited Free;
end;

function TSvga8Mode.PageBank(APage: word): word;
begin
  PageBank := Min(APage, MaxPage) * BanksPerPage;
end;

function TSvga8Mode.PopulateMode(var AVbeMode: TVbeMode; var AVbeInfo: TVbeInfo; AIndex: integer): boolean;
var
  colors: string;
  recordPtr: pointer;
  index: integer;
  desc: string;
begin
  ModeId := AIndex;
  PopulateMode := true;
  case AVbeMode.v1.Bpp of
    4: colors := '16';
    8: colors := '256';
    15: colors := '32k';
    16: colors := '64k';
    32: colors := '16m';
  end;
  desc := 'SVGA '
    + IntToStr(AVbeMode.v1.XResolution)
    + 'x'
    + IntToStr(AVbeMode.v1.YResolution)
    + ' '
    + colors
    + ' Color';
  Description := TString.New(desc);
  ModeIndex := AIndex;
  Width := AVbeMode.v1.XResolution;
  Height := AVbeMode.v1.YResolution;
  MaxX := AVbeMode.v1.XResolution - 1;
  MaxY := AVbeMode.v1.YResolution - 1;
  Bpp := AVbeMode.v1.Bpp;
  BytesPerScanLine := AVbeMode.v1.BytesPerScanLine;
  ScreenSize := Longint(Height) * BytesPerScanLine;
  Attributes := AVbeMode.v1.ModeAttributes;
  WinSize := AVbeMode.v1.WinSize;
  WinFunc := AVbeMode.v1.WinFuncPtr;
  HelpText := TString.New('Requires Super VGA card supporting VBE extensions.');
  FrameBuffer := Ptr(AVbeMode.v1.WinSegmentA, 0);
  Granularity := AVbeMode.v1.WinGranularity;
  FullGranularity := longint(Granularity) * 1024;
  BankShift := 0;
  while (64 shr BankShift <> Granularity) do
    Inc(BankShift);
  NumPages := AVbeMode.v1.NumberOfImagePages;
  BanksPerPage := ScreenSize div FullGranularity;
  if ScreenSize mod FullGranularity <> 0 then
    Inc(BanksPerPage);
  PageCount := (AVbeInfo.TotalMemory * 64) div (BanksPerPage * Granularity);
  if PageCount = 0 then begin
    PageCount := 1;
    MaxPage := 0;
  end
  else
    MaxPage := PageCount - 1;
end;

function TSvga8Driver.ModeFromVbeMode(var AVbeMode: TVbeMode; AIndex: integer): PSVga8Mode;
var
  newMode: PSVga8Mode;
begin
  newMode := New(PSVga8Mode, Create);
  if NilPtr(newMode, ecNotEnoughMemory) then begin
    ModeFromVbeMode := nil;
    exit;
  end;
  if not newMode^.PopulateMode(AVbeMode, FVbeInfo, AIndex) then
    FreeAndNil(newMode);
  ModeFromVbeMode := newMode;
end;

procedure TSVga8Driver.Init;
var
  newMode: PSVga8Mode;
  oldMode: byte;
  vbeInfo: TVbeInfo;
  supported, callStatus: byte;
  modeIndexPtr: PWord;
  vbeInfoPtr: PVbeInfo;
  vbeModeInfoPtr: PVbeMode;
  vbeModeIndex: word;
  vbeMode: TVbeMode;
begin
  inherited Init;
  SvgaState^.FCurrentBank := 0;
  FMaxOffset := 0;
  vbeInfoPtr := @vbeInfo;
  FillChar(FVbeInfo, SizeOf(FVbeInfo), 0);
  asm
    mov ax, 4F00h
    les di, vbeInfoPtr
    int 10h
    mov [supported], al
    mov [callStatus], ah
  end;
  FVbeInfo := vbeInfo;
  if (supported <> $4F) or (callStatus <> 0) then begin
    Raise(ecGraphicsNotSupported);
    exit;
  end;

  modeIndexPtr := vbeInfo.VideoModePtr;
  while modeIndexPtr^ <> $FFFF do begin
    vbeModeIndex := modeIndexPtr^;
    if vbeModeIndex < $100 then begin
      Inc(modeIndexPtr);
      continue;
    end;
    vbeModeInfoPtr := @vbeMode;
    asm
      mov ax, 4F01h
      les di, vbeModeInfoPtr
      mov cx, [vbeModeIndex]
      int 10h
    end;
    if (vbeMode.v1.Bpp <> 8)
      or (not vbeMode.v1.MemoryModel = mmPackedPixel)
      or (not (vbeSupportedInHardware in vbeMode.v1.ModeAttributes))
      or (not (vbeIsColor in vbeMode.v1.ModeAttributes))
      or (not (vbeIsGraphics in vbeMode.v1.ModeAttributes)) then begin
      Inc(modeIndexPtr);
      continue;
    end;
    newMode := ModeFromVbeMode(vbeMode, vbeModeIndex);
    if NilPtr(newMode, ecNotEnoughMemory) then
      break;
    Inc(modeIndexPtr);
    Modes.Add(newMode);
  end;
end;

function TSVga8Driver.CreateGraphicsState: PGraphicsState;
begin
  CreateGraphicsState := new(PSVga8State, Create(@self));
end;

function TSvga8Driver.GetScreenPointer(APX, APY: integer): PByte;
var
  offset: longint;
begin
  GetScreenPointer := InternalGetScreenPointer(APX, APY, true, offset);
end;

function TSvga8Driver.InternalGetScreenPointer(APX, APY: integer;
  ASetBank: boolean; var AOffset: longint): PByte;
var
  bank: integer;
  screen: PByte;
begin
  if State^.BufferMode then begin
    screen := State^.FrameBuffer;
    AOffset := longint(APY) * State^.Bounds.Width + APX;
    Inc(screen, AOffset);
    InternalGetScreenPointer := screen;
    exit;
  end;
  AOffset := GetOffset(APX, APY);
  screen := State^.FrameBuffer;
  AOffset := AOffset and FMaxOffset;
  Inc(screen, AOffset);
  if ASetBank then
    SetBankByCoord(APX, APY, State^.DrawPage);
  InternalGetScreenPointer := screen;
end;

procedure TSVga8Driver.SetMode(AMode: PGraphicsMode);
var
  selectedMode: word;
begin
  inherited SetMode(AMode);
  selectedMode := AMode^.ModeIndex;
  asm
    mov   ax, 4F02h
    mov   bx, [selectedMode]
    int   10h
  end;
  Mouse.SetMouseResolution(AMode^.Width - 1, AMode^.Height - 1);
  if HasException then
    exit;
  State^.FrameBuffer := AMode^.FrameBuffer;
  State^.Bpp := AMode^.Bpp;
  SetVgaPalette;
  FWinFunc := SvgaMode^.WinFunc;
  SvgaState^.FCurrentBank := 0;
  FMaxOffset := word(SvgaMode^.FullGranularity - 1);
  OffscreenPage := 0;
  if SvgaMode^.PageCount > 1 then
    OffscreenPage := 1;
end;

function TSVga8Driver.SVgaMode: PSVga8Mode;
begin
  SVgaMode := PSVga8Mode(Mode);
end;

function TSvga8Driver.GetOffset(APX, APY: integer): longint;
begin
  GetOffset := longint(APY) * Mode^.BytesPerScanLine + APX;
end;

function TSvga8Driver.GetBankOffset(APX, APY: integer): longint;
begin
  GetBankOffset := GetOffset(APX, APY) and FMaxOffset;
end;

function TSvga8Driver.SetBankByCoord(APX, APY, APage: integer): longint;
var
  offset: longint;
  bank: word;
begin
  offset := GetOffset(APX, APY);
  bank := offset shr 16;
  Inc(bank, SvgaMode^.PageBank(APage));
  if bank <> SvgaState^.FCurrentBank then
    SetBank(bank);
  SetBankByCoord := offset;
end;

procedure TSVga8Driver.SetBank(ABank: word);
var
  winFunc: pointer;
begin
  if ABank = SvgaState^.FCurrentBank then
    exit;
  SvgaState^.FCurrentBank := ABank;
  ABank := ABank shl SvgaMode^.BankShift;
  winFunc := FWinFunc;
  asm
    mov bx, 0
    mov dx, [ABank]
    call winFunc
    mov bx, 1
    mov dx, [ABank]
    call winFunc
  end;
end;

procedure TSVga8Driver.RenderText(APX, APY, ALength: integer; AText: PChar);
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
    linePtr := font^.FontData;
    Inc(linePtr, font^.BytesPerCharLine * (Ord(ch) * height + (sy - APY)));
    while sy <= maxY do begin
      screen := InternalGetScreenPointer(sx + minX, sy, true, offset);
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
        Inc(offset);
        shift := shift shr 1;
        if offset > FMaxOffset then
          screen := InternalGetScreenPointer(sx + xIndex + 1, sy, true, offset);
      end;
      Inc(sy);
    end;
    Inc(sx, width);
  end;
end;

procedure TSVga8Driver.Line(AX1, AY1, AX2, AY2: integer);
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
  x := drawRect.X;
  y := drawRect.Y;
  right := drawRect.Right;
  bottom := drawRect.Bottom;
  screenPtr := State^.FrameBuffer;
  width := Mode^.Width;
  color := State^.ForeColor;

  while true do begin
    if State^.ViewPort.Contains(AX1, AY1) then begin
      screenPtr := GetScreenPointer(AX1, AY1);
      screenPtr^ := color;
    end;
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

procedure TSVga8Driver.FillPattern(ARect: TRect);
var
  screen: PByte;
  py, width, partialWidth, index: integer;
  offset: longint;
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
    screen := InternalGetScreenPointer(ARect.X, index, true, offset);
    py := index mod 16;
    if width + offset > FMaxOffset then begin
      partialWidth := FMaxOffset - offset + 1;
      HLinePattern(State^.FillPattern^[py], ARect.X, index, partialWidth);
      SetBank(SvgaState^.FCurrentBank + 1);
      screen := Mode^.FrameBuffer;
      HLinePattern(State^.FillPattern^[py], ARect.X + partialWidth, index, width - partialWidth);
    end
    else
      HLinePattern(State^.FillPattern^[py], ARect.X, index, width);
  end;
end;

procedure TSVga8Driver.FillRect(ARect: TRect);
var
  screen: PByte;
  drawRect: TRect;
  width, partialWidth, index: integer;
  color: byte;
  offset: longint;
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
    screen := InternalGetScreenPointer(ARect.X, ARect.Y + index, true, offset);
    if width + offset > FMaxOffset then begin
      partialWidth := FMaxOffset - offset + 1;
      FillChar(screen^, partialWidth, color);
      SetBank(SvgaState^.FCurrentBank + 1);
      screen := Mode^.FrameBuffer;
      FillChar(screen^, width - partialWidth, color);
    end
    else
      FillChar(screen^, width, color);
  end;
end;

procedure TSvga8Driver.VLinePattern(APattern: word; APX, APY, AHeight: integer);
var
  patternIndex: integer;
  fore, back: byte;
  screen: PByte;
  py: integer;
  offset: longint;
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
  screen := InternalGetScreenPointer(APX, APY, true, offset);
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
    Inc(offset, Mode^.Width);
    Inc(APY);
    if offset > FMaxOffset then begin
      screen := InternalGetScreenPointer(APX, APY, true, offset);
      Inc(offset, Mode^.Width);
    end;
  end;
end;

procedure TSVga8Driver.HLinePattern(APattern: TLinePattern; APX, APY, AWidth: integer);
var
  patternIndex: integer;
  drawRect: TRect;
  fore, back: byte;
  screen: PByte;
  px: integer;
  offset: longint;
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
  screen := InternalGetScreenPointer(APX, APY, true, offset);
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
    Inc(offset);
    if offset > FMaxOffset then begin
      offset := 0;
      SetBank(SvgaState^.FCurrentBank + 1);
      screen := Mode^.FrameBuffer;
    end;
  end;
end;

procedure TSVga8Driver.HLine(APX, APY, AWidth: integer);
var
  screen: PByte;
  partialWidth, lineWidth: integer;
  color: byte;
  drawRect: TRect;
  offset: longint;
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
  screen := InternalGetScreenPointer(APX, APY, true, offset);
  if AWidth + offset > FMaxOffset then begin
    partialWidth := FMaxOffset - offset + 1;
    asm
      les di, screen
      mov cx, partialWidth
      mov al, color
      rep stosb
     end;
    SetBank(SvgaState^.FCurrentBank + 1);
    screen := Mode^.FrameBuffer;
    Dec(AWidth, partialWidth);
    asm
      les di, screen
      mov cx, AWidth
      mov al, color
      rep stosb
    end;
  end
  else
    FillChar(screen^, AWidth, color);
end;

procedure TSVga8Driver.VLine(APX, APY, AHeight: integer);
var
  index: integer;
  screen: PByte;
  drawRect: TRect;
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
  for index := APY to APY + AHeight - 1 do begin
    screen := GetScreenPointer(APX, index);
    screen^ := ForeColor;
  end;
end;

procedure TSVga8Driver.InverseHLine(APX, APY, AWidth: integer);
var
  drawRect: TRect;
  index: integer;
  screen: PByte;
  offset: longint;
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
  screen := InternalGetScreenPointer(APX, APY, true, offset);
  if State^.BufferMode then begin
    for index := 0 to AWidth - 1 do begin
      screen^ := screen^ xor 15;
      Inc(screen);
    end;
    exit;
  end;
  for index := 0 to AWidth - 1 do begin
    if offset > FMaxOffset then begin
      SetBank(SvgaState^.FCurrentBank + 1);
      screen := Mode^.FrameBuffer;
      offset := 0;
    end;
    screen^ := screen^ xor 15;
    Inc(offset);
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
    if Offset + lineWidth > FMaxOffset then begin
      partialWidth := FMaxOffset - Offset + 1;
      Move(imagePtr^, screenPtr^, partialWidth);
      Inc(imagePtr, partialWidth);
      SetBank(SvgaState^.FCurrentBank + 1);
      screenPtr := Mode^.FrameBuffer;
      Move(imagePtr^, screenPtr^, lineWidth - partialWidth);
    end
    else
      Move(imagePtr^, screenPtr^, lineWidth);
  end;
end;

procedure DrawLineStream(const ALineInfo: TLineInfo);
var
  offset: longint;
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
    if Offset + lineWidth > FMaxOffset then begin
      partialWidth := FMaxOffset - Offset + 1;
      stream^.Read(screenPtr, partialWidth);
      SetBank(SvgaState^.FCurrentBank + 1);
      screenPtr := Mode^.FrameBuffer;
      stream^.Read(screenPtr, lineWidth - partialWidth);
    end
    else
      stream^.Read(screenPtr, lineWidth);
    Driver^.CheckReRaise(stream);
  end;
end;

procedure DrawTransparentLineBuffer(const ALineInfo: TLineInfo);
var
  screenOffset: longint;
  screenPtr, imagePtr: PByte;
  xIndex, lineWidth, sy: integer;
begin
  with ALineInfo, Driver^ do begin
    imagePtr := PByte(Image);
    screenPtr := Screen;
    screenOffset := Offset;
    Inc(imagePtr, (YIndex + ImageRect.Y) * ImageRect.Width + ImageRect.X);
    lineWidth := DrawRect.Width;
    for xIndex := 0 to DrawRect.Width - 1 do begin
      if imagePtr^ <> TransparentColor then
        screenPtr^ := imagePtr^;
      Inc(imagePtr);
      Inc(screenPtr);
      Inc(screenOffset);
      if screenOffset > FMaxOffset then
        screenPtr := InternalGetScreenPointer(DrawRect.X + xIndex + 1,
          YIndex + DrawRect.Y, true, screenOffset);
    end;
  end;
end;
procedure DrawTransparentLineStream(const ALineInfo: TLineInfo);
var
  screenOffset: longint;
  sy: integer;
  imageStream: PStream;
  xIndex: integer;
  screenPtr: PByte;
  color: byte;
begin
  with ALineInfo, Driver^ do begin
    imageStream := PStream(Image);
    screenPtr := Screen;
    screenOffset := Offset;
    imageStream^.Seek(Start + (YIndex + ImageRect.Y) * longint(ImageRect.Width) +
      ImageRect.X, soFromBeginning);
    imageStream^.Read(@LineBuffer, ImageRect.Width);
    for xIndex := 0 to ImageRect.Width - 1 do begin
      color := LineBuffer[xIndex];
      if color <> TransparentColor then
        screen^ := color;
      Inc(screenPtr);
      Inc(screenOffset);
      if screenOffset > FMaxOffset then
        screenPtr := InternalGetScreenPointer(drawRect.X + xIndex + 1,
          sy, true, screenOffset);
    end;
    Driver^.CheckReRaise(imageStream);
  end;
end;

procedure TSVga8Driver.DrawImageZoom(const ARect: TRect; AImage: pointer; AFlags: TImageFlags;
  AZoom: integer);
var
  imageRect, drawRect: TRect;
  yIndex: longint;
  drawLine: TDrawLineProc;
  offset: longint;
  sy: integer;
  info: TLineInfo;
begin
end;

procedure TSVga8Driver.DrawBufferRect(var ASourceBounds, ASourceRect: TRect;
  const ADestPoint: TPoint; ABuffer: pointer);
var
  image: PByte;
  screenPtr, imagePtr: PByte;
  source, dest: TRect;
  yIndex: integer;
  offset: longint;
  lineWidth, partialWidth: integer;
begin
  image := PByte(ABuffer);
  dest.CreateRect(ASourceRect);
  dest.X := ADestPoint.X;
  dest.Y := ADestPoint.Y;
  dest.Intersect(Mode^.Bounds);
  dest.Intersect(State^.ViewPort);
  source.CreateRect(ASourceRect);
  source.Intersect(ASourceBounds);
  if dest.IsEmpty then
    exit;
  lineWidth := source.Width;
  for yIndex := 0 to dest.Height - 1 do begin
    screenPtr := InternalGetScreenPointer(dest.X, dest.Y + yIndex, true, offset);
    imagePtr := image;
    Inc(imagePtr, yIndex * ASourceBounds.Width + ASourceRect.X);
    if offset + lineWidth > FMaxOffset then begin
      partialWidth := FMaxOffset - offset + 1;
      Move(imagePtr^, screenPtr^, partialWidth);
      Inc(imagePtr, partialWidth);
      SetBank(SvgaState^.FCurrentBank + 1);
      screenPtr := Mode^.FrameBuffer;
      Move(imagePtr^, screenPtr^, lineWidth - partialWidth);
    end
    else
      Move(imagePtr^, screenPtr^, lineWidth);
  end;
end;

procedure TSVga8Driver.DrawImageCoords(APX, APY, AWidth, AHeight: integer;
  AImage: pointer; AFlags: TImageFlags);
var
  imageRect, drawRect: TRect;
  yIndex: longint;
  drawLine: TDrawLineProc;
  offset: longint;
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
  info.Image := pointer(AImage);
  info.DrawRect.CreateRect(drawRect);
  info.ImageRect.CreateRect(imageRect);
  info.Start := 0;
  info.Driver := @self;
  if AFlags * [ifStreamed] = [ifStreamed] then
    info.Start := PStream(AImage)^.Position;
  for yIndex := 0 to drawRect.Height - 1 do begin
    info.Screen := InternalGetScreenPointer(DrawRect.X, sy + yIndex, true,
      info.Offset);
    info.YIndex := yIndex;
    drawLine(info);
    if HasException then
      break;
  end;
end;

procedure TSVga8Driver.SetDisplayPage(APage: word);
var
  offset: longint;
  x, y: integer;
begin
  inherited SetDisplayPage(APage);
  if State^.DisplayPage = APage then
    exit;
  offset := APage * SvgaMode^.BanksPerPage * SvgaMode^.FullGranularity;
  x := offset mod Mode^.BytesPerScanLine;
  y := offset div Mode^.BytesPerScanLine;
  asm
    mov ax, 4F07h
    xor bx, bx
    mov cx, x
    mov dx, y
    int 10h
  end;
end;

procedure TSVga8Driver.SetDrawPage(APage: word);
begin
  inherited SetDrawPage(APage);
end;

procedure TSVga8Driver.CopyRect(const ASource, ADest: TRect; ASourcePage, ADestPage: word);
var
  sx, dx, sy, dy: word;
  buffer, ptr: PByte;
  sourcePtr, destPtr: PByte;
  source, dest: TRect;
  soffset, doffset: longint;
  lineWidth, partial: word;
  index: integer;
begin
  if HasException then
    exit;
  if Mode^.PageCount < 2 then
    exit;
  source.CreateRect(ASource);
  dest.CreateRect(ADest);
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

  lineWidth := source.Width * Mode^.Bpp div 8;
  GetMem(buffer, lineWidth);
  if NilPtr(buffer, ecNotEnoughMemory) then
    exit;

  PushState;

  for index := sy to source.Bottom do begin
    SetDrawPage(ASourcePage);
    sourcePtr := InternalGetScreenPointer(sx, sy, true, soffset);
    ptr := buffer;
    if soffset + lineWidth > FMaxOffset then begin
      partial := FMaxOffset - soffset + 1;
      Move(sourcePtr^, ptr^, partial);
      SetBank(SvgaState^.FCurrentBank + 1);
      Inc(ptr, partial);
      sourcePtr := Mode^.FrameBuffer;
      Move(sourcePtr^, ptr^, lineWidth - partial);
    end
    else
      Move(sourcePtr^, buffer^, lineWidth);

    SetDrawPage(ADestPage);
    destPtr := InternalGetScreenPointer(dx, dy, true, doffset);
    ptr := buffer;
    if doffset + lineWidth > FMaxOffset then begin
      partial := FMaxOffset - doffset + 1;
      Move(buffer^, destPtr^, partial);
      SetBank(SvgaState^.FCurrentBank + 1);
      Inc(ptr, partial);
      destPtr := Mode^.FrameBuffer;
      Move(ptr^, destPtr^, lineWidth - partial);
    end
    else
      Move(ptr^, destPtr^, lineWidth);
    Inc(dy);
    Inc(sy);
  end;

  FreeMem(buffer, lineWidth);
  PopState;
end;

procedure TSVga8Driver.CopyFromOffScreen(const ASource, ADest: TRect);
begin
  CopyRect(ASource, ADest, OffscreenPage, 0);
end;

procedure TSVga8Driver.CopyToOffScreen(const ASource, ADest: TRect);
begin
  CopyRect(ASource, ADest, 0, OffscreenPage);
end;

procedure TSVga8Driver.GetImage(APX, APY, AWidth, AHeight: longint; ABuffer: PByte);
var
  imageRect, drawRect: TRect;
  yIndex: integer;
  screen, image: PByte;
  sy: word;
  lineWidth, partialWidth: integer;
  offset: longint;
begin
  if HasException then
    exit;
  GetImageDrawRects(APX, APY, AWidth, AHeight, imageRect, drawRect);
  if drawRect.IsEmpty then
    exit;
  sy := drawRect.Y;
  lineWidth := drawRect.Width;
  for yIndex := 0 to drawRect.Height - 1 do begin
    screen := InternalGetScreenPointer(drawRect.X, sy, true, offset);
    image := ABuffer;
    Inc(image, (yIndex + imageRect.Y) * imageRect.Width + imageRect.X);
    if offset + lineWidth > FMaxOffset then begin
      partialWidth := FMaxOffset - offset + 1;
      Move(screen^, image^, partialWidth);
      Inc(image, partialWidth);
      SetBank(SvgaState^.FCurrentBank + 1);
      screen := Mode^.FrameBuffer;
      Move(screen^, image^, lineWidth - partialWidth);
      Inc(image, lineWidth - partialWidth);
    end
    else begin
      Move(screen^, image^, lineWidth);
      Inc(image, lineWidth);
    end;
    Inc(sy);
  end;
end;

procedure TSVga8Driver.GetImageStream(APX, APY, AWidth, AHeight: longint; AStream: PStream);
var
  imageRect, drawRect: TRect;
  yIndex: integer;
  screen: PByte;
  sy: longint;
  lineWidth, partialWidth: integer;
  streamStart: longint;
  offset: longint;
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
    screen := InternalGetScreenPointer(drawRect.X, sy, true, offset);
    AStream^.Seek(streamStart + (yIndex + imageRect.Y) * longint(imageRect.Width) + imageRect.X, soFromBeginning);
    if offset + lineWidth > FMaxOffset then begin
      partialWidth := FMaxOffset - offset + 1;
      AStream^.Write(screen, partialWidth);
      SetBank(SvgaState^.FCurrentBank + 1);
      screen := Mode^.FrameBuffer;
      AStream^.Write(screen, lineWidth - partialWidth);
    end
    else
      AStream^.Write(screen, lineWidth);
    Inc(sy);
  end;
  if AStream^.HasException then
    Raise(AStream^.Exception^.Code);
end;

procedure TSVga8Driver.WaitForVSync; assembler;
asm
  mov dx, 3DAh
  @loop:
  in al, dx
  test al, 8h
  jz @loop
end;

function TSvga8Driver.SvgaState: PSvga8State;
begin
  SvgaState := PSvga8State(State);
end;

destructor TSVga8Driver.Free;
begin
  inherited Free;
end;

constructor TSvga8State.Create(AOwner: PSVga8Driver);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TSvga8State.Init;
begin
  inherited Init;
  FCurrentBank := 0;
  FOwner := nil;
end;

destructor TSvga8State.Free;
begin
  inherited Free;
end;

procedure TSvga8State.Assign(var ASource: TObject);
var
  source: PSvga8State;
begin
  inherited Assign(ASource);
  source := PSvga8State(@ASource);
  FOwner := source^.FOwner;
end;

begin
end.