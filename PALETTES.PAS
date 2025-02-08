{$I COMPILER.INC}
unit Palettes;

interface

uses
  AplObj,
  AplTypes,
  AplUtils,
  Compress,
  Streams,
  AplConst,
  Lists;

type
  PRgbPalette = ^TRgbPalette;
  PRgbColor = ^TRgbColor;
  PRgbColors = ^TRgbColors;

  TStandardColor =
  (
    scEga,
    scWhite,
    scRed,
    scGreen,
    scBlue,
    scCyan,
    scYellow,
    scMagenta,
    scOrange,
    scBrown,
    scSpringGreen,
    scAzure,
    scViolet,
    scFleshTone
  );

  TColor = record
    Color: TStandardColor;
    Shade: byte;
  end;

  TPaletteFormat =
  (
    pfApl,
    pfJasc,
    pfGimp
  );

  TRgbColor = record
    Red: byte;
    Green: byte;
    Blue: byte;
  end;

  TRgbColors = array[0..MaxVarSize div SizeOf(TRgbColor) - 1] of TRgbColor;

  TRgbPalette = object(TPersistent)
  private
    FColors: PRgbColors;
    FColorCount: word;
    FFormat: TPaletteFormat;
    FCompression: TAplCompression;
    FCompressionLevel: TCompressionLevel;
    procedure LoadAplPalette(AStream: PStream);
    procedure LoadJascPalette(AStream: PStream);
    procedure LoadGimpPalette(AStream: PStream);
    procedure SaveAplPalette(AStream: PStream);
    procedure SaveJascPalette(AStream: PStream);
    procedure SaveGimpPalette(AStream: PStream);
    function ReadLine(AStream: PStream): string;
    procedure WriteLine(AStream: PStream; const ALine: string);
  public
    constructor Create(AFormat: TPaletteFormat);
    constructor CreateFromFile(AFilename: string; AFormat: TPaletteFormat);
    constructor CreateFromStream(AStream: PStream; AFormat: TPaletteFormat);
    constructor CreateVgaStandard;
    function Colors: PRgbColors;
    function Format: TPaletteFormat;
    function GetPaletteDataVga: PRgbColors;
    function ColorCount: word;
    function ByteSize: word;
    function Compression: TAplCompression;
    function CompressionLevel: TCompressionLevel;
    procedure SetCount(ACount: word);
    procedure SetFormat(AFormat: TPaletteFormat);
    procedure SetPaletteData(AData: PRgbColors);
    procedure SetColor(AIndex: word; var AColor: TRgbColor);
    procedure SaveToStream(AStream: PStream); virtual;
    procedure LoadFromStream(AStream: PStream); virtual;
    procedure SetCompression(ACompression: TAplCompression;
      ACompressionLevel: TCompressionLevel);
    procedure Init; virtual;
    destructor Free; virtual;
  end;

const
  egaBlack = 0;
  egaBlue = 1;
  egaGreen = 2;
  egaCyan = 3;
  egaRed = 4;
  egaMagenta = 5;
  egaBrown = 6;
  egaLightGray = 7;
  egaDarkGray = 8;
  egaLightBlue = 9;
  egaLightGreen = 10;
  egaLightCyan = 11;
  egaLightRed = 12;
  egaLightMagenta = 13;
  egaYellow = 14;
  egaWhite = 15;

  rgbEgaBlack: TRgbColor = (Red: $00; Green: $00; Blue: $00);
  rgbEgaBlue: TRgbColor = (Red: $00; Green: $00; Blue: $AA);
  rgbEgaGreen: TRgbColor = (Red: $00; Green: $AA; Blue: $00);
  rgbEgaCyan: TRgbColor = (Red: $00; Green: $AA; Blue: $AA);
  rgbEgaRed: TRgbColor = (Red: $AA; Green: $00; Blue: $00);
  rgbEgaMagenta: TRgbColor = (Red: $AA; Green: $00; Blue: $AA);
  rgbEgaBrown: TRgbColor = (Red: $AA; Green: $55; Blue: $00);
  rgbEgaLightGray: TRgbColor = (Red: $AA; Green: $AA; Blue: $AA);
  rgbEgaDarkGray: TRgbColor = (Red: $55; Green: $55; Blue: $55);
  rgbEgaLightBlue: TRgbColor = (Red: $55; Green: $55; Blue: $FF);
  rgbEgaLightGreen: TRgbColor = (Red: $55; Green: $FF; Blue: $55);
  rgbEgaLightCyan: TRgbColor = (Red: $55; Green: $FF; Blue: $FF);
  rgbEgaLightRed: TRgbColor = (Red: $FF; Green: $55; Blue: $55);
  rgbEgaLightMagenta: TRgbColor = (Red: $FF; Green: $55; Blue: $FF);
  rgbEgaYellow: TRgbColor = (Red: $FF; Green: $FF; Blue: $55);
  rgbEgaWhite: TRgbColor = (Red: $FF; Green: $FF; Blue: $FF);

  MinIntensity: byte = 0;
  MaxIntensity: byte = 15;
  Intensity50: byte = 7;
  Intensity25: byte = 3;
  Intensity75: byte = 11;
  PaletteAnimationStart: byte = 224;
  PaletteAnimationEnd: byte = 254;
  TransparentColor: byte = 255;

implementation

uses
  Graphics,
  Gr8Drv;

procedure TRgbPalette.Init;
begin
  inherited Init;
  FColors := nil;
  FColorCount := 0;
  FFormat := pfApl;
  FCompression := acLzw;
  FCompressionLevel := clHigh;
end;

constructor TRgbPalette.CreateVgaStandard;
var
  colorIndex: TStandardColor;
  shadeIndex, shade: integer;
  index: integer;
  color: TRgbColor;
begin
  inherited Create;
  if Assigned(FColors) then begin
    FreeMem(FColors, FColorCount * SizeOf(TRgbColor));
    FColors := nil;
  end;
  FColorCount := 256;
  GetMem(FColors, FColorCount * SizeOf(TRgbColor));
  if NilPtr(FColors, ecNotEnoughMemory) then
    Exit;

  { Standard EGA colors }
  FColors^[0] := rgbEgaBlack;
  FColors^[1] := rgbEgaBlue;
  FColors^[2] := rgbEgaGreen;
  FColors^[3] := rgbEgaCyan;
  FColors^[4] := rgbEgaRed;
  FColors^[5] := rgbEgaMagenta;
  FColors^[6] := rgbEgaBrown;
  FColors^[7] := rgbEgaLightGray;
  FColors^[8] := rgbEgaDarkGray;
  FColors^[9] := rgbEgaLightBlue;
  FColors^[10] := rgbEgaLightGreen;
  FColors^[11] := rgbEgaLightCyan;
  FColors^[12] := rgbEgaLightRed;
  FColors^[13] := rgbEgaLightMagenta;
  FColors^[14] := rgbEgaYellow;
  FColors^[15] := rgbEgaWhite;
  index := 16;
  for colorIndex := scWhite to High(TStandardColor) do begin
    for shadeIndex := 1 to 16 do begin
      shade := shadeIndex * 16 - 1;
      case colorIndex of
        scWhite: begin
          color.Red := shade;
          color.Green := shade;
          color.Blue := shade;
        end;
        scRed: begin
          color.Red := shade;
          color.Green := 0;
          color.Blue := 0;
        end;
        scGreen: begin
          color.Red := 0;
          color.Green := shade;
          color.Blue := 0;
        end;
        scBlue: begin
          color.Red := 0;
          color.Green := 0;
          color.Blue := shade;
        end;
        scYellow: begin
          color.Red := shade;
          color.Green := shade;
          color.Blue := 0;
        end;
        scMagenta: begin
          color.Red := shade;
          color.Green := 0;
          color.Blue := shade;
        end;
        scCyan: begin
          color.Red := 0;
          color.Green := shade;
          color.Blue := shade;
        end;
        scOrange: begin
          color.Red := shade;
          color.Green := shade div 2;
          color.Blue := 0;
        end;
        scBrown: begin
          color.Red := Round(shade / 1.7);
          color.Green := shade div 2;
          color.Blue := 0;
        end;
        scSpringGreen: begin
          color.Red := shade div 2;
          color.Green := shade;
          color.Blue := shade div 2;
        end;
        scAzure: begin
          color.Red := shade div 3;
          color.Green := shade div 3;
          color.Blue := shade;
        end;
        scViolet: begin
          color.Red := shade div 2;
          color.Green := 0;
          color.Blue := shade;
        end;
        scFleshTone: begin
          color.Red := 215 - Round((shadeIndex / 18) * 115);
          color.Green := 190 - Round((shadeIndex / 18) * 135);
          color.Blue := 140 - Round((shadeIndex / 18) * 135);
        end;
      end;
      FColors^[index] := color;
      Inc(index);
    end;
  end;
  FillChar(color, SizeOf(TRgbColor), 0);
  while index < 256 do begin
    FColors^[index] := color;
    Inc(index);
  end;
end;

constructor TRgbPalette.Create(AFormat: TPaletteFormat);
begin
  inherited Create;
  FFormat := AFormat;
end;

constructor TRgbPalette.CreateFromFile(AFilename: string; AFormat: TPaletteFormat);
begin
  inherited Create;
  FFormat := AFormat;
  LoadFromFile(AFilename);
end;

constructor TRgbPalette.CreateFromStream(AStream: PStream; AFormat: TPaletteFormat);
begin
  inherited Create;
  FFormat := AFormat;
  LoadFromStream(AStream);
end;

procedure TRgbPalette.SetCompression(ACompression: TAplCompression;
  ACompressionLevel: TCompressionLevel);
begin
  FCompression := ACompression;
  FCompressionLevel := ACompressionLevel;
end;

function TRgbPalette.Colors: PRgbColors;
begin
  Colors := FColors;
end;

function TRgbPalette.Format: TPaletteFormat;
begin
  Format := FFormat;
end;

procedure TRgbPalette.SetPaletteData(AData: PRgbColors);
begin
  if Assigned(FColors) and (FColorCount > 0) then begin
    FreeMem(FColors, FColorCount * SizeOf(TRgbColor));
    FColors := nil;
  end;
  FColors := AData;
end;

procedure TRgbPalette.SetColor(AIndex: word; var AColor: TRgbColor);
begin
  if (not Assigned(FColors)) or (AIndex >= FColorCount) then
    exit;
  FColors^[AIndex] := AColor;
end;

function TRgbPalette.ByteSize: word;
begin
  ByteSize := FColorCount * SizeOf(TRgbColor);
end;

function TRgbPalette.Compression: TAplCompression;
begin
  Compression := FCompression;
end;

function TRgbPalette.CompressionLevel: TCompressionLevel;
begin
  CompressionLevel := FCompressionLevel;
end;

procedure TRgbPalette.WriteLine(AStream: PStream; const ALine: string);
var
  buffer: string;
begin
  buffer := ALine + #13#10;
  AStream^.Write(@buffer[1], Length(buffer));
  if CheckReRaise(AStream) then
    exit;
end;

function TRgbPalette.ReadLine(AStream: PStream): string;
var
  buffer: string;
  ch: char;
begin
  buffer := '';
  while not AStream^.EndOfStream do begin
    ch := Char(AStream^.ReadByte);
    if AStream^.HasException then
      Raise(AStream^.Exception^.Code);
    if ch = #13 then
      continue;
    if ch = #10 then
      break;
    buffer := buffer + ch;
  end;
  ReadLine := buffer;
end;

procedure TRgbPalette.LoadJascPalette(AStream: PStream);
var
  line: string;
  color: TRgbColor;
  count: word;
  index: word;
begin
  line := ReadLine(AStream);
  if CheckReRaise(AStream) then
    exit;
  if line <> 'JASC-PAL' then begin
    Raise(ecInvalidPalette);
    exit;
  end;
  line := ReadLine(AStream);
  if CheckReRaise(AStream) then
    exit;
  if line <> '0100' then begin
    Raise(ecInvalidPalette);
    exit;
  end;
  line := ReadLine(AStream);
  if CheckReRaise(AStream) then
    exit;
  count := StrToInt(line, 0);
  if CheckReRaise(AStream) then
    exit;
  GetMem(FColors, count * SizeOf(TRgbColor));
  if NilPtr(FColors, ecNotEnoughMemory) then
    exit;
  FColorCount := count;
  index := 0;
  while not AStream^.EndOfStream do begin
    line := ReadLine(AStream);
    if CheckReRaise(AStream) then
      exit;
    {// Change this to not read padding for each color component}
    color.Red := StrToInt(Trim(Copy(line, 1, 3)), 0);
    color.Green := StrToInt(Trim(Copy(line, 5, 3)), 0);
    color.Blue := StrToInt(Trim(Copy(line, 9, 3)), 0);
    FColors^[index] := color;
    if index > count then
      break;
    Inc(index);
  end;
end;

procedure TRgbPalette.LoadGimpPalette(AStream: PStream);
var
  line: string;
  color: TRgbColor;
  comment: boolean;
  count: word;
  index: word;
  pos: longint;
begin
  count := 0;
  pos := AStream^.Position;
  while not AStream^.EndOfStream do begin
    line := ReadLine(AStream);
    if StartsWith(line, '#') then
      continue;
    Inc(count);
  end;
  AStream^.Seek(pos, soFromBeginning);
  GetMem(FColors, count * SizeOf(TRgbColor));
  if NilPtr(FColors, ecNotEnoughMemory) then
    exit;
  index := 0;
  FColorCount := count;
  while not AStream^.EndOfStream do begin
    line := ReadLine(AStream);
    if StartsWith(line, '#') then
      continue;
    color.Red := StrToInt(Trim(Copy(line, 1, 3)), 0);
    color.Green := StrToInt(Trim(Copy(line, 5, 3)), 0);
    color.Blue := StrToInt(Trim(Copy(line, 9, 3)), 0);
    FColors^[index] := color;
    Inc(index);
  end;
end;

procedure TRgbPalette.LoadAplPalette(AStream: PStream);
var
  compressor: PCompressor;
  dest: PMemoryStream;
  size: word;
begin
  SetCount(AStream^.ReadWord);
  if NilPtr(FColors, ecNotEnoughMemory) then
    exit;
  case FCompression of
    acLzw: begin
      compressor := TCompression.GetCompressor(FCompression, FCompressionLevel);
      if NilPtr(compressor, ecNotEnoughMemory) then
        exit;
      dest := New(PMemoryStream, CreateBuffer(FColors, size));
      dest^.FreeBuffers := false;
      compressor^.DecompressStream(AStream, dest, size);
      FreeAndNil(compressor);
      FreeAndNil(dest);
    end;
    else
      AStream^.Read(FColors, size);
  end;
end;

procedure TRgbPalette.SaveAplPalette(AStream: PStream);
var
  compressor: PCompressor;
  source: PMemoryStream;
  size: word;
begin
  size := FColorCount * SizeOf(TRgbColor);
  AStream^.WriteWord(FColorCount);
  case FCompression of
    acLzw: begin
      compressor := TCompression.GetCompressor(FCompression, FCompressionLevel);
      if NilPtr(compressor, ecNotEnoughMemory) then
        exit;
      source := New(PMemoryStream, CreateBuffer(FColors, size));
      source^.FreeBuffers := false;
      compressor^.CompressStream(source, AStream, size);
      CheckReRaise(source);
      FreeAndNil(compressor);
      FreeAndNil(source);
    end;
    else
      AStream^.Write(FColors, size);
  end;
end;

procedure TRgbPalette.SaveJascPalette(AStream: PStream);
var
  index: word;
  color: TRgbColor;
begin
  WriteLine(AStream, 'JASC-PAL');
  WriteLine(AStream, '0100');
  WriteLine(AStream, IntToStr(FColorCount));
  for index := 0 to FColorCount - 1 do begin
    color := FColors^[index];
    WriteLine(AStream,
      IntToStr(color.Red) + ' '
      + IntToStr(color.Green) + ' '
      + IntToStr(color.Blue)
    );
  end;
end;

procedure TRgbPalette.SaveGimpPalette(AStream: PStream);
var
  index: integer;
  color: TRgbColor;
begin
  WriteLine(aStream, 'GIMP Palette');
  for index := 0 to FColorCount - 1 do begin
    color := FColors^[index];
    WriteLine(AStream,
      LeftPad(IntToStr(color.Red), 3, ' ') + ' '
      + LeftPad(IntToStr(color.Green), 3, ' ') + ' '
      + LeftPad(IntToStr(color.Blue), 3, ' ') + ' '
      + ' Untitled'
    );
  end;
end;

procedure TRgbPalette.LoadFromStream(AStream: PStream);
begin
  if Assigned(FColors) and (FColorCount > 0) then begin
    FreeMem(FColors, FColorCount * SizeOf(TRgbColor));
    FColors := nil;
  end;
  FColorCount := 0;
  FColors := nil;
  case FFormat of
    pfApl: LoadAplPalette(AStream);
    pfJasc: LoadJascPalette(AStream);
    pfGimp: LoadGimpPalette(AStream);
  end;
  CheckReRaise(AStream);
end;

procedure TRgbPalette.SetCount(ACount: word);
begin
  if Assigned(FColors) then begin
    FreeMem(FColors, FColorCount * SizeOf(TRgbColor));
    FColors := nil;
  end;
  FColorCount := ACount;
  GetMem(FColors, SizeOf(TRgbColor) * FColorCount);
  if NilPtr(FColors, ecNotEnoughMemory) then
    exit;
  FillChar(FColors^, SizeOf(TRgbColor) * FColorCount, 0);
end;

procedure TRgbPalette.SetFormat(AFormat: TPaletteFormat);
begin
  FFormat := AFormat;
end;

procedure TRgbPalette.SaveToStream(AStream: PStream);
begin
  case FFormat of
    pfApl: SaveAplPalette(AStream);
    pfJasc: SaveJascPalette(AStream);
    pfGimp: SaveGimpPalette(AStream);
  end;
  CheckReRaise(AStream);
end;

function TRgbPalette.GetPaletteDataVga: PRgbColors;
var
  index: integer;
  result: PRgbColors;
  color: TRgbColor;
begin
  GetPaletteDataVga := nil;
  if (not Assigned(FColors)) or (FColorCount <> 256) then
    exit;
  GetMem(result, 256 * SizeOf(TRgbColor));
  if NilPtr(result, ecNotEnoughMemory) then
    exit;
  for index := 0 to 255 do begin
    color := FColors^[index];
    color.Red := color.Red shr 2;
    color.Green := color.Green shr 2;
    color.Blue := color.Blue shr 2;
    result^[index] := color;
  end;
  GetPaletteDataVga := result;
end;

function TRgbPalette.ColorCount: word;
begin
  ColorCount := FColorCount;
end;

destructor TRgbPalette.Free;
begin
  if Assigned(FColors) and (FColorCount > 0) then
    FreeMem(FColors, FColorCount * SizeOf(TRgbColor));
  inherited Free;
end;

begin
end.