{$I COMPILER.INC}
unit AplImage;

interface

uses
  AplTypes,
  AplConst,
  AplObj,
  Compress,
  Palettes,
  AplUtils,
  Streams;

const
  AplImageIdentifier: string[6] = 'APLIMG';
  AplImageExtension = 'AMG';
  AplImageMajorVersion = 1;
  AplImageMinorVersion = 0;

type
  PAplImageHeader = ^TAplImageHeader;
  PAplImageReader = ^TAplImageReader;
  PAplImageWriter = ^TAplImageWriter;
  PAplImageStreamReader = ^TAplImageStreamReader;
  PAplImageStreamWriter = ^TAplImageStreamWriter;
  PAplImageBufferReader = ^TAplImageBufferReader;
  PAplImageBufferWriter = ^TAplImageBufferWriter;
  PAplImage = ^TAplImage;
  PAplBufferImage = ^TAplBufferImage;
  PAplStreamImage = ^TAplStreamImage;

  TAplImageHeader = object(TPersistent)
  private
  public
    Identifier: array[0..5] of char;
    MajorVersion: byte;
    MinorVersion: byte;
    Width: word;
    Height: word;
    Bpp: byte;
    Planes: byte;
    HasPalette: boolean;
    PaletteSize: word;
    Compression: TAplCompression;
    CompressionLevel: TCompressionLevel;
    DataSize: longint;
    HasExtendedData: boolean;
    constructor CreateFromStream(AStream: PStream);
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    procedure SaveToStream(AStream: PStream); virtual;
    procedure LoadFromStream(AStream: PStream); virtual;
  end;

  TAplImageReader = object(TStatusObject)
  private
    FStream: PStream;
    FFreeStream: boolean;
    FCompression: TAplCompression;
    FCompressionLevel: TCompressionLevel;
  public
    constructor Create(const AStream: PStream; ACompression: TAplCompression;
      ACompressionLevel: TCompressionLevel);
    constructor CreateFromFile(const AFileName: string);
    destructor Free; virtual;
    procedure Init; virtual;
    procedure ReadHeader(var AHeader: TAplImageHeader); virtual;
    function GetHeader: PAplImageHeader; virtual;
    function ReadPalette: PRgbPalette; virtual;
  end;

  TAplImageWriter = object(TStatusObject)
  private
    FStream: PStream;
    FFreeStream: boolean;
    FCompression: TAplCompression;
    FCompressionLevel: TCompressionLevel;
  public
    constructor Create(const AStream: PStream; ACompression: TAplCompression;
      ACompressionLevel: TCompressionLevel);
    constructor CreateFromFile(const AFileName: string);
    destructor Free; virtual;
    procedure Init; virtual;
    procedure WriteHeader(var AHeader: TAplImageHeader); virtual;
    procedure WritePalette(var APalette: TRgbPalette); virtual;
  end;

  TAplImageStreamReader = object(TAplImageReader)
  public
    function ReadImage(var AHeader: TAplImageHeader): PMemoryStream;
  end;

  TAplImageStreamWriter = object(TAplImageWriter)
  public
    procedure WriteImage(AImageData: PMemoryStream; var AHeader: TAplImageHeader);
  end;

  TAplImageBufferReader = object(TAplImageReader)
  private
  public
    function ReadImage(var AHeader: TAplImageHeader): pointer;
  end;

  TAplImageBufferWriter = object(TAplImageWriter)
  public
    procedure WriteImage(AImageData: pointer; var AHeader: TAplImageHeader);
  end;

  TAplImage = object(TPersistent)
  private
    FBuffer: pointer;
    FPalette: PRgbPalette;
    FHeader: TAplImageHeader;
    function CheckVersion(var AHeader: TAplImageHeader): word;
    procedure SaveHeaderAndPalette(AStream: PStream; AWriter: PAplImageWriter);
    procedure LoadHeaderAndPalette(AStream: PStream; AReader: PAplImageReader);
    procedure InitAll(AWidth, AHeight, ABpp, APlanes: word;
      APalette: PRgbPalette);
  public
    FreePalette: boolean;
    constructor Create(AWidth, AHeight, ABpp, APlanes: word;
      APalette: PRgbPalette);
    constructor CreateHeaderPalette(var AHeader: TAplImageHeader;
      APalette: PRgbPalette);
    constructor CreateHeader(var AHeader: TAplImageHeader);
    constructor CreateFromStream(const AStream: PStream);
    constructor CreateFromFile(const AFileName: string);
    constructor CreateDimsBpp(const AWidth, AHeight, ABpp: word);
    constructor CreateDims(const AWidth, AHeight: word);
    function Compression: TAplCompression;
    function CompressionLevel: TCompressionLevel;
    function Width: word;
    function Height: word;
    function Bpp: byte;
    function Planes: byte;
    function DataSize: longint;
    function HasExtendedData: boolean;
    function Palette: PRgbPalette;
    procedure CreateBuffer; virtual;
    procedure SetPalette(APalette: PRgbPalette; var AHeader: TAplImageHeader);
    procedure SetCompression(const ACompression: TAplCompression;
      const ALevel: TCompressionLevel);
    procedure LoadFromStream(AStream: PStream); virtual;
    procedure SaveToStream(AStream: PStream); virtual;
    procedure Clear(AColor: byte); virtual;
    procedure ClearWord(AColor: word); virtual;
    procedure ClearLong(AColor: longint); virtual;
    procedure Init; virtual;
    destructor Free; virtual;
  end;

  TAplBufferImage = object(TAplImage)
  private
  public
    function Buffer: PByte;
    destructor Free; virtual;
    procedure CreateBuffer; virtual;
    procedure Clear(AColor: byte); virtual;
    procedure ClearWord(AColor: word); virtual;
    procedure ClearLong(AColor: longint); virtual;
    procedure SaveToStream(AStream: PStream); virtual;
    procedure LoadFromStream(AStream: PStream); virtual;
  end;

  TAplStreamImage = object(TAplImage)
  public
    function Buffer: PMemoryStream;
    destructor Free; virtual;
    procedure CreateBuffer; virtual;
    procedure Clear(AColor: byte); virtual;
    procedure ClearWord(AColor: word); virtual;
    procedure ClearLong(AColor: longint); virtual;
    procedure SaveToStream(AStream: PStream); virtual;
    procedure LoadFromStream(AStream: PStream); virtual;
  end;

implementation

uses
  Lzw;

procedure TAplImageHeader.Init;
begin
  inherited Init;
  Move(AplImageIdentifier[1], Identifier, Length(AplImageIdentifier));
  MajorVersion := AplImageMajorVersion;
  MinorVersion := AplImageMinorVersion;
  Width := 0;
  Height := 0;
  Bpp := 0;
  Planes := 0;
  HasPalette := false;
  PaletteSize := 0;
  Compression := acLzw;
  CompressionLevel := clHigh;
  DataSize := 0;
  HasExtendedData := false;
end;

constructor TAplImageHeader.CreateFromStream(AStream: PStream);
begin
  inherited Create;
  LoadFromStream(AStream);
end;

procedure TAplImageHeader.Assign(var ASource: TObject);
var
  source: PAplImageHeader;
begin
  inherited Assign(ASource);
  source := PAplImageHeader(@ASource);
  Identifier := source^.Identifier;
  MajorVersion := source^.MajorVersion;
  MinorVersion := source^.MinorVersion;
  Width := source^.Width;
  Height := source^.Height;
  Bpp := source^.Bpp;
  Planes := source^.Planes;
  HasPalette := source^.HasPalette;
  PaletteSize := source^.PaletteSize;
  Compression := source^.Compression;
  CompressionLevel := source^.CompressionLevel;
  DataSize := source^.DataSize;
  HasExtendedData := source^.HasExtendedData;
end;

procedure TAplImageHeader.SaveToStream(AStream: PStream);
begin
  if HasException then
    exit;
  AStream^.Write(@Identifier, SizeOf(Identifier));
  AStream^.Write(@MajorVersion, SizeOf(MajorVersion));
  AStream^.Write(@MinorVersion, SizeOf(MinorVersion));
  AStream^.Write(@Width, SizeOf(Width));
  AStream^.Write(@Height, SizeOf(Height));
  AStream^.Write(@Bpp, SizeOf(Bpp));
  AStream^.Write(@Planes, SizeOf(Planes));
  AStream^.Write(@HasPalette, SizeOf(HasPalette));
  AStream^.Write(@PaletteSize, SizeOf(PaletteSize));
  AStream^.Write(@Compression, SizeOf(Compression));
  AStream^.Write(@CompressionLevel, SizeOf(CompressionLevel));
  AStream^.Write(@DataSize, SizeOf(DataSize));
  AStream^.Write(@HasExtendedData, SizeOf(HasExtendedData));
  CheckReRaise(AStream);
end;

procedure TAplImageHeader.LoadFromStream(AStream: PStream);
begin
  if HasException then
    exit;
  AStream^.Read(@Identifier, SizeOf(Identifier));
  AStream^.Read(@MajorVersion, SizeOf(MajorVersion));
  AStream^.Read(@MinorVersion, SizeOf(MinorVersion));
  AStream^.Read(@Width, SizeOf(Width));
  AStream^.Read(@Height, SizeOf(Height));
  AStream^.Read(@Bpp, SizeOf(Bpp));
  AStream^.Read(@Planes, SizeOf(Planes));
  AStream^.Read(@HasPalette, SizeOf(HasPalette));
  AStream^.Read(@PaletteSize, SizeOf(PaletteSize));
  AStream^.Read(@Compression, SizeOf(Compression));
  AStream^.Read(@CompressionLevel, SizeOf(CompressionLevel));
  AStream^.Read(@DataSize, SizeOf(DataSize));
  AStream^.Read(@HasExtendedData, SizeOf(HasExtendedData));
  CheckReRaise(AStream);
end;

procedure TAplImage.InitAll(AWidth, AHeight, ABpp, APlanes: word;
  APalette: PRgbPalette);
begin
  FHeader.Create;
  FHeader.Width := AWidth;
  FHeader.Height := AHeight;
  FHeader.Bpp := ABpp;
  FHeader.Planes := APlanes;
  FHeader.DataSize := longint(FHeader.Width) * FHeader.Height * FHeader.Bpp div 8;
  SetPalette(APalette, FHeader);
end;

constructor TAplImage.Create(AWidth, AHeight, ABpp, APlanes: word;
  APalette: PRgbPalette);
begin
  inherited Create;
  InitAll(AWidth, AHeight, ABpp, APlanes, APalette);
  CreateBuffer;
end;

constructor TAplImage.CreateHeaderPalette(var AHeader: TAplImageHeader;
  APalette: PRgbPalette);
begin
  inherited Create;
  InitAll(AHeader.Width, AHeader.Height, AHeader.Bpp, AHeader.Planes, APalette);
  CreateBuffer;
end;

constructor TAplImage.CreateHeader(var AHeader: TAplImageHeader);
begin
  inherited Create;
  InitAll(AHeader.Width, AHeader.Height, AHeader.Bpp, AHeader.Planes, nil);
  CreateBuffer;
end;

constructor TAplImage.CreateFromStream(const AStream: PStream);
begin
  inherited Create;
  LoadFromStream(AStream);
end;

constructor TAplImage.CreateFromFile(const AFileName: string);
begin
  inherited Create;
  LoadFromFile(AFileName);
end;

constructor TAplImage.CreateDimsBpp(const AWidth, AHeight, ABpp: word);
begin
  inherited Create;
  InitAll(AWidth, AHeight, ABpp, 1, nil);
  CreateBuffer;
end;

constructor TAplImage.CreateDims(const AWidth, AHeight: word);
begin
  inherited Create;
  InitAll(AWidth, AHeight, 8, 1, nil);
  CreateBuffer;
end;

function TAplImage.CheckVersion(var AHeader: TAplImageHeader): word;
begin
  CheckVersion := ecNone;
  if (AHeader.MajorVersion > AplImageMajorVersion) or
    ((AHeader.MajorVersion = AplImageMajorVersion) and
    (AHeader.MinorVersion > AplImageMinorVersion)) then
    CheckVersion := ecImageVersionNotSupported
  else if FHeader.Identifier <> AplImageIdentifier then
    CheckVersion := ecInvalidImage;
end;

function TAplImage.Compression: TAplCompression;
begin
  Compression := FHeader.Compression;
end;

function TAplImage.CompressionLevel: TCompressionLevel;
begin
  CompressionLevel := FHeader.CompressionLevel;
end;

procedure TAplImage.Clear(AColor: byte);
begin
end;

procedure TAplImage.ClearWord(AColor: word);
begin
end;

procedure TAplImage.ClearLong(AColor: longint);
begin
end;

function TAplImage.Width: word;
begin
  Width := FHeader.Width;
end;

function TAplImage.Height: word;
begin
  Height := FHeader.Height;
end;

function TAplImage.Bpp: byte;
begin
  Bpp := FHeader.Bpp;
end;

function TAplImage.Planes: byte;
begin
  Planes := FHeader.Planes;
end;

function TAplImage.DataSize: longint;
begin
  DataSize := FHeader.DataSize;
end;

function TAplImage.HasExtendedData: boolean;
begin
  HasExtendedData := FHeader.HasExtendedData;
end;

function TAplImage.Palette: PRgbPalette;
begin
  Palette := FPalette;
end;

procedure TAplImage.SetCompression(const ACompression: TAplCompression;
  const ALevel: TCompressionLevel);
begin
  FHeader.Compression := ACompression;
  FHeader.CompressionLevel := ALevel;
end;

procedure TAplImage.SaveHeaderAndPalette(AStream: PStream; AWriter: PAplImageWriter);
begin
  FHeader.HasPalette := Assigned(FPalette);
  if FHeader.HasPalette then
    FHeader.PaletteSize := FPalette^.ColorCount;
  AWriter^.WriteHeader(FHeader);
  if CheckReRaise(AWriter) then
    exit;
  if FHeader.HasPalette then begin
    AWriter^.WritePalette(FPalette^);
    if CheckReRaise(AWriter) then
      exit;
  end;
end;

procedure TAplImage.LoadHeaderAndPalette(AStream: PStream; AReader: PAplImageReader);
begin
  AReader^.ReadHeader(FHeader);
  if CheckReRaise(AReader) then
    exit;
  FreeAndNil(FPalette);
  FHeader.PaletteSize := 0;
  if FHeader.HasPalette then begin
    FPalette := AReader^.ReadPalette;
    if CheckReRaise(FPalette) then
      exit;
    FHeader.PaletteSize := FPalette^.ColorCount;
  end;
end;

procedure TAplImage.LoadFromStream(AStream: PStream);
begin
  Abstract;
end;

procedure TAplImage.CreateBuffer;
begin
  Abstract;
end;

procedure TAplImage.SaveToStream(AStream: PStream);
begin
  Abstract;
end;

procedure TAplImage.SetPalette(APalette: PRgbPalette; var AHeader: TAplImageHeader);
begin
  if HasException then
    exit;
  FPalette := nil;
  AHeader.HasPalette := false;
  AHeader.PaletteSize := 0;
  if not Assigned(APalette) then
    exit;
  FPalette := APalette;
  AHeader.PaletteSize := FPalette^.ColorCount;
  AHeader.HasPalette := true;
end;

destructor TAplImage.Free;
begin
  if FreePalette then
    FreeAndNil(FPalette);
  inherited Free;
end;

procedure TAplImage.Init;
begin
  inherited Init;
  FHeader.Create;
  FBuffer := nil;
  FPalette := nil;
  FreePalette := false;
end;

function TAplBufferImage.Buffer: PByte;
begin
  Buffer := FBuffer;
end;

procedure TAplBufferImage.Clear(AColor: byte);
var
  size: word;
  buff: pointer;
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if FHeader.DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  size := FHeader.DataSize;
  buff := FBuffer;
  asm
    les di, buff
    mov cx, size
    mov al, AColor
    cld
    rep stosb
  end;
end;

procedure TAplBufferImage.ClearWord(AColor: word);
var
  size: word;
  buff: pointer;
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if FHeader.DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  size := FHeader.DataSize div SizeOf(word);
  buff := FBuffer;
  asm
    les di, buff
    mov cx, size
    mov ax, AColor
    cld
    rep stosw
  end;
end;

procedure TAplBufferImage.ClearLong(AColor: longint);
var
  index: word;
  size: word;
  ptr: PLongint;
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if FHeader.DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  size := FHeader.DataSize div SizeOf(longint);
  ptr := FBuffer;
  for index := 0 to size - 1 do begin
    ptr^ := AColor;
    Inc(ptr);
  end;
end;

procedure TAplBufferImage.CreateBuffer;
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if FHeader.DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  GetMem(FBuffer, FHeader.DataSize);
  if NilPtr(FBuffer, ecNotEnoughMemory) then
    exit;
end;

procedure TAplBufferImage.SaveToStream(AStream: PStream);
var
  writer: TAplImageBufferWriter;
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  writer.Create(AStream, FHeader.Compression, FHeader.CompressionLevel);
  SaveHeaderAndPalette(AStream, @writer);
  if CheckReRaise(@writer) then begin
    writer.Free;
    exit;
  end;
  writer.WriteImage(FBuffer, FHeader);
  CheckReRaise(@writer);
  writer.Free;
end;

procedure TAplBufferImage.LoadFromStream(AStream: PStream);
var
  reader: TAplImageBufferReader;
  error: word;
begin
  if HasException then
    exit;
  if Assigned(FBuffer) and (FHeader.DataSize > 0) then begin
    FreeMem(FBuffer, FHeader.DataSize);
    FHeader.DataSize := 0;
    FBuffer := nil;
    FreeAndNil(FPalette);
  end;
  reader.Create(AStream, FHeader.Compression, FHeader.CompressionLevel);
  LoadHeaderAndPalette(AStream, @reader);
  if CheckReRaise(@reader) then
    exit;
  error := CheckVersion(FHeader);
  if error <> ecNone then begin
    Raise(error);
    exit;
  end;
  FBuffer := reader.ReadImage(FHeader);
  CheckReRaise(@reader);
  reader.Free;
end;

destructor TAplBufferImage.Free;
begin
  if Assigned(FBuffer) and (FHeader.DataSize > 0) then begin
    FreeMem(FBuffer, FHeader.DataSize);
    FHeader.DataSize := 0;
    FBuffer := nil;
  end;
  inherited Free;
end;

function TAplStreamImage.Buffer: PMemoryStream;
begin
  Buffer := PMemoryStream(FBuffer);
end;

procedure TAplStreamImage.Clear(AColor: byte);
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  PMemoryStream(FBuffer)^.Seek(0, soFromBeginning);
  PMemoryStream(FBuffer)^.Fill(FHeader.DataSize, AColor);
end;

procedure TAplStreamImage.ClearWord(AColor: word);
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  PMemoryStream(FBuffer)^.Seek(0, soFromBeginning);
  PMemoryStream(FBuffer)^.FillWord(FHeader.DataSize, AColor);
end;

procedure TAplStreamImage.ClearLong(AColor: longint);
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  PMemoryStream(FBuffer)^.Seek(0, soFromBeginning);
  PMemoryStream(FBuffer)^.FillLong(FHeader.DataSize, AColor);
end;

procedure TAplStreamImage.CreateBuffer;
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  FBuffer := New(PMemoryStream, Create(FHeader.DataSize));
  if NilPtr(FBuffer, ecNotEnoughMemory) then
    exit;
  PMemoryStream(FBuffer)^.FreeBuffers := true;
end;

procedure TAplStreamImage.SaveToStream(AStream: PStream);
var
  writer: TAplImageStreamWriter;
begin
  if HasException then
    exit;
  if FHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  writer.Create(AStream, FHeader.Compression, FHeader.CompressionLevel);
  SaveHeaderAndPalette(AStream, @writer);
  if CheckReRaise(@writer) then begin
    writer.Free;
    exit;
  end;
  writer.WriteImage(PMemoryStream(FBuffer), FHeader);
  CheckReRaise(@writer);
  writer.Free;
end;

procedure TAplStreamImage.LoadFromStream(AStream: PStream);
var
  reader: TAplImageStreamReader;
  error: word;
begin
  if HasException then
    exit;
  if Assigned(FBuffer) then begin
    FreeAndNil(FBuffer);
    FHeader.DataSize := 0;
    FreeAndNil(FPalette);
  end;
  reader.Create(AStream, FHeader.Compression, FHeader.CompressionLevel);
  LoadHeaderAndPalette(AStream, @reader);
  if CheckReRaise(@reader) then
    exit;
  error := CheckVersion(FHeader);
  if error <> ecNone then begin
    Raise(error);
    exit;
  end;
  FBuffer := reader.ReadImage(FHeader);
  CheckReRaise(@reader);
  reader.Free;
end;

destructor TAplStreamImage.Free;
begin
  if Assigned(FBuffer) then
    FreeAndNil(FBuffer);
  inherited Free;
end;

constructor TAplImageReader.Create(const AStream: PStream; ACompression: TAplCompression;
  ACompressionLevel: TCompressionLevel);
begin
  inherited Create;
  FStream := AStream;
  FFreeStream := false;
  FCompressionLevel := ACompressionLevel;
end;

constructor TAplImageReader.CreateFromFile(const AFileName: string);
begin
  inherited Create;
  FStream := New(PFileStream, Create(AFileName, fmRead));
  if NilPtr(FStream, ecNotEnoughMemory) then
    exit;
  FFreeStream := true;
end;

procedure TAplImageReader.Init;
begin
  inherited Init;
  FStream := nil;
  FFreeStream := false;
end;

destructor TAplImageReader.Free;
begin
  if FFreeStream then
    FreeAndNil(FStream);
  inherited Free;
end;

procedure TAplImageReader.ReadHeader(var AHeader: TAplImageHeader);
begin
  if HasException then
    exit;
  AHeader.LoadFromStream(FStream);
  CheckReRaise(FStream);
end;

function TAplImageReader.GetHeader: PAplImageHeader;
var
  result: PAplImageHeader;
begin
  GetHeader := nil;
  if HasException then
    exit;
  result := New(PAplImageHeader, CreateFromStream(FStream));
  if NilPtr(result, ecNotEnoughMemory) then
    exit;
  if CheckReRaise(FStream) then
    exit;
  GetHeader := result;
end;

function TAplImageReader.ReadPalette: PRgbPalette;
var
  result: PRgbPalette;
begin
  ReadPalette := nil;
  if HasException then
    exit;
  result := New(PRgbPalette, CreateFromStream(FStream, pfApl));
  if NilPtr(result, ecNotEnoughMemory) then
    exit;
  if CheckReRaise(result) then
    exit;
  ReadPalette := result;
end;

constructor TAplImageWriter.Create(const AStream: PStream; ACompression: TAplCompression;
  ACompressionLevel: TCompressionLevel);
begin
  inherited Create;
  FStream := AStream;
  FFreeStream := false;
  FCompression := ACompression;
  FCompressionLevel := ACompressionLevel;
end;

constructor TAplImageWriter.CreateFromFile(const AFileName: string);
begin
  inherited Create;
  FStream := New(PFileStream, Create(AFileName, fmWrite));
  if NilPtr(FStream, ecNotEnoughMemory) then
    exit;
  FFreeStream := true;
end;

procedure TAplImageWriter.Init;
begin
  inherited Init;
  FStream := nil;
  FFreeStream := false;
end;

destructor TAplImageWriter.Free;
begin
  if FFreeStream then
    FreeAndNil(FStream);
  inherited Free;
end;

procedure TAplImageWriter.WriteHeader(var AHeader: TAplImageHeader);
begin
  if HasException then
    exit;
  AHeader.SaveToStream(FStream);
  CheckReRaise(FStream);
end;

procedure TAplImageWriter.WritePalette(var APalette: TRgbPalette);
begin
  if HasException then
    exit;
  APalette.SetCompression(FCompression, FCompressionLevel);
  APalette.SetFormat(pfApl);
  APalette.SaveToStream(FStream);
  CheckReRaise(FStream);
end;

function TAplImageStreamReader.ReadImage(var AHeader: TAplImageHeader): PMemoryStream;
var
  result: PMemoryStream;
  compressor: PCompressor;
begin
  ReadImage := nil;
  if HasException then
    exit;
  if AHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  result := New(PMemoryStream, Create(AHeader.DataSize));
  if NilPtr(result, ecNotEnoughMemory) then
    exit;
  if AHeader.Compression = acNone then
    result^.ReadFromStream(FStream, AHeader.DataSize)
  else begin
    compressor := TCompression.GetCompressor(AHeader.Compression, AHeader.CompressionLevel);
    if NilPtr(compressor, ecNotEnoughMemory) then begin
      FreeAndNil(result);
      exit;
    end;
    compressor^.DecompressStream(FStream, result, AHeader.DataSize);
    CheckReRaise(compressor);
    FreeAndNil(compressor);
  end;
  CheckReRaise(FStream);
  if HasException then begin
    result := nil;
    FreeAndNil(result);
  end;
  result^.Seek(0, soFromBeginning);
  CheckReRaise(result);
  ReadImage := result;
end;

function TAplImageBufferReader.ReadImage(var AHeader: TAplImageHeader): pointer;
var
  result: PByte;
  compressor: PCompressor;
  stream: PMemoryStream;
begin
  ReadImage := nil;
  if HasException then
    exit;
  if AHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if AHeader.DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  GetMem(result, AHeader.DataSize);;
  if NilPtr(result, ecNotEnoughMemory) then
    exit;
  stream := New(PMemoryStream, CreateBuffer(result, AHeader.DataSize));
  if NilPtr(stream, ecNotEnoughMemory) then
    exit;
  if CheckReRaise(stream) then
    exit;
  stream^.FreeBuffers := false;
  if AHeader.Compression = acNone then
    FStream^.Read(result, AHeader.DataSize)
  else begin
    compressor := TCompression.GetCompressor(AHeader.Compression, AHeader.CompressionLevel);
    compressor^.DecompressStream(FStream, stream, AHeader.DataSize);
    CheckReRaise(compressor);
    FreeAndNil(compressor);
  end;
  FreeAndNil(stream);
  CheckReRaise(FStream);
  if HasException then begin
    result := nil;
    FreeMem(result, AHeader.DataSize);
  end;
  ReadImage := result;
end;

procedure TAplImageBufferWriter.WriteImage(AImageData: pointer; var AHeader: TAplImageHeader);
var
  compressor: PCompressor;
  stream: PMemoryStream;
begin
  if HasException then
    exit;
  if AHeader.DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  if AHeader.Compression = acNone then
    FStream^.Write(AImageData, AHeader.DataSize)
  else begin
    stream := New(PMemoryStream, CreateBuffer(AImageData, AHeader.DataSize));
    if NilPtr(stream, ecNotEnoughMemory) then
      exit;
    if CheckReRaise(stream) then
      exit;
    stream^.FreeBuffers := false;
    compressor := TCompression.GetCompressor(AHeader.Compression, AHeader.CompressionLevel);
    compressor^.CompressStream(stream, FStream, AHeader.DataSize);
    CheckReRaise(compressor);
    FreeAndNil(compressor);
    FreeAndNil(stream);
  end;
  CheckReRaise(FStream);
end;

procedure TAplImageStreamWriter.WriteImage(AImageData: PMemoryStream; var AHeader: TAplImageHeader);
var
  compressor: PCompressor;
begin
  if HasException then
    exit;
  if AHeader.DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  AImageData^.Seek(0, soFromBeginning);
  if AHeader.Compression = acNone then
    AImageData^.WriteToStream(FStream, AHeader.DataSize)
  else begin
    compressor := TCompression.GetCompressor(AHeader.Compression, AHeader.CompressionLevel);
    compressor^.CompressStream(AImageData, FStream, AHeader.DataSize);
    CheckReRaise(compressor);
    FreeAndNil(compressor);
  end;
  CheckReRaise(FStream);
end;

begin
end.