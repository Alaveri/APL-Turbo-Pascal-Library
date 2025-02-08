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
  PAplImage = ^TAplImage;
  PAplBufferImage = ^TAplBufferImage;
  PAplStreamImage = ^TAplStreamImage;

  TAplBlockType = (btImage, btPalette);

  TAplImageBlock = record
    BlockType: TAplBlockType;
    Size: longint;
    Compression: TAplCompression;
    CompressionLevel: TCompressionLevel;
  end;

  TAplImageHeader = record
    Identifier: array[0..5] of char;
    MajorVersion: byte;
    MinorVersion: byte;
    Width: word;
    Height: word;
    Bpp: byte;
    Planes: byte;
    TotalBlocks: word;
  end;

  TAplImage = object(TPersistent)
  private
    FBuffer: pointer;
    FPalette: PRgbPalette;
    FWidth: word;
    FHeight: word;
    FBpp: byte;
    FPlanes: byte;
    FCompression: TAplCompression;
    FCompressionLevel: TCompressionLevel;
    function CheckVersion(var AHeader: TAplImageHeader): word;
    procedure SaveHeader(AStream: PStream; var AHeader: TAplImageHeader);
    procedure LoadHeader(AStream: PStream; var AHeader: TAplImageHeader);
    procedure InitAll(AWidth, AHeight, ABpp, APlanes: word;
      APalette: PRgbPalette);
  public
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
    function Palette: PRgbPalette;
    procedure GetHeader(var AHeader: TAplImageHeader);
    procedure SetHeader(var AHeader: TAplImageHeader);
    procedure ResetDims(AWidth, AHeight: integer);
    procedure CreateBuffer; virtual;
    procedure SetPalette(APalette: PRgbPalette);
    procedure SetCompression(const ACompression: TAplCompression;
      const ALevel: TCompressionLevel);
    procedure LoadFromStream(AStream: PStream); virtual;
    procedure SaveToStream(AStream: PStream); virtual;
    procedure Clear(AColor: byte); virtual;
    procedure ClearWord(AColor: word); virtual;
    procedure ClearLong(AColor: longint); virtual;
    procedure Init; virtual;
    procedure LoadImage(AStream: PStream; const ABlock: TAplImageBlock); virtual;
    procedure LoadPalette(AStream: PStream; const ABlock: TAplImageBlock); virtual;
    procedure SaveImage(AStream: PStream); virtual;
    procedure SavePalette(AStream: PStream); virtual;
    destructor Free; virtual;
  end;

  TAplBufferImage = object(TAplImage)
  private
  public
    function Buffer: PByte;
    destructor Free; virtual;
    procedure SetBuffer(ABuffer: PByte);
    procedure CreateBuffer; virtual;
    procedure Clear(AColor: byte); virtual;
    procedure ClearWord(AColor: word); virtual;
    procedure ClearLong(AColor: longint); virtual;
    procedure LoadImage(AStream: PStream; const ABlock: TAplImageBlock); virtual;
    procedure SaveImage(AStream: PStream); virtual;
  end;

  TAplStreamImage = object(TAplImage)
  public
    function Buffer: PMemoryStream;
    destructor Free; virtual;
    procedure CreateBuffer; virtual;
    procedure Clear(AColor: byte); virtual;
    procedure ClearWord(AColor: word); virtual;
    procedure ClearLong(AColor: longint); virtual;
    procedure LoadImage(AStream: PStream; const ABlock: TAplImageBlock); virtual;
    procedure SaveImage(AStream: PStream); virtual;
  end;

implementation

uses
  Lzw;

procedure TAplImage.InitAll(AWidth, AHeight, ABpp, APlanes: word;
  APalette: PRgbPalette);
begin
  FWidth := AWidth;
  FHeight := AHeight;
  FBpp := ABpp;
  FPlanes := APlanes;
  SetPalette(APalette);
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
  else if AHeader.Identifier <> AplImageIdentifier then
    CheckVersion := ecInvalidImage;
end;

function TAplImage.Compression: TAplCompression;
begin
  Compression := FCompression;
end;

function TAplImage.CompressionLevel: TCompressionLevel;
begin
  CompressionLevel := FCompressionLevel;
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
  Width := FWidth;
end;

function TAplImage.Height: word;
begin
  Height := FHeight;
end;

function TAplImage.Bpp: byte;
begin
  Bpp := FBpp;
end;

function TAplImage.Planes: byte;
begin
  Planes := FPlanes;
end;

function TAplImage.Palette: PRgbPalette;
begin
  Palette := FPalette;
end;

function TAplImage.DataSize: longint;
begin
  DataSize := longint(FWidth) * FHeight * FBpp div 8;
end;

procedure TAplImage.GetHeader(var AHeader: TAplImageHeader);
begin
  FillChar(AHeader, SizeOf(AHeader), 0);
  Move(AplImageIdentifier[1], AHeader.Identifier, Length(AplImageIdentifier));
  AHeader.MajorVersion := AplImageMajorVersion;
  AHeader.MinorVersion := AplImageMinorVersion;
  AHeader.Width := FWidth;
  AHeader.Height := FHeight;
  AHeader.Bpp := FBpp;
  AHeader.Planes := FPlanes;
  AHeader.TotalBlocks := 1;
  if Assigned(FPalette) then
    Inc(AHeader.TotalBlocks);
end;

procedure TAplImage.SetHeader(var AHeader: TAplImageHeader);
begin
  FWidth := AHeader.Width;
  FHeight := AHeader.Height;
  FBpp := AHeader.Bpp;
  FPlanes := AHeader.Planes;
end;

procedure TAplImage.SetCompression(const ACompression: TAplCompression;
  const ALevel: TCompressionLevel);
begin
  FCompression := ACompression;
  FCompressionLevel := ALevel;
end;

procedure TAplImage.SaveHeader(AStream: PStream; var AHeader: TAplImageHeader);
begin
  AStream^.Write(@AHeader, SizeOf(AHeader));
  CheckReRaise(AStream);
end;

procedure TAplImage.LoadHeader(AStream: PStream; var AHeader: TAplImageHeader);
begin
  AStream^.Read(@AHeader, SizeOf(AHeader));
  CheckReRaise(AStream);
end;

procedure TAplImage.ResetDims(AWidth, AHeight: integer);
begin
  FWidth := AWidth;
  FHeight := AHeight;
end;

procedure TAplImage.LoadFromStream(AStream: PStream);
var
  error: word;
  header: TAplImageHeader;
  blockCount: word;
  block: TAplImageBlock;
begin
  if HasException then
    exit;
  if Assigned(FBuffer) and (DataSize > 0) then begin
    FreeMem(FBuffer, DataSize);
    FBuffer := nil;
  end;

  { read header }
  LoadHeader(AStream, header);
  if CheckForExceptions(AStream) then
    exit;
  error := CheckVersion(header);
  if error <> ecNone then begin
    Raise(error);
    exit;
  end;
  SetHeader(header);

  { read blocks }
  blockCount := 0;
  while (blockCount < header.TotalBlocks) and not AStream^.EndOfStream do begin
    AStream^.Read(@block, SizeOf(block));
    CheckForExceptions(AStream);
    case block.BlockType of
      btImage: begin
        if block.Size > MaxVarSize then begin
          Raise(ecImageTooLarge);
          exit;
        end;
        LoadImage(AStream, block);
      end;
      btPalette: LoadPalette(AStream, block);
      else begin
        Raise(ecInvalidImage);
        exit;
      end;
    end;
    Inc(blockCount);
    if HasException then
      exit;
  end;
  if blockCount < header.TotalBlocks then
    Raise(ecInvalidImage);
  if not Assigned(FBuffer) then
    Raise(ecInvalidImage);
end;

procedure TAplImage.LoadImage(AStream: PStream; const ABlock: TAplImageBlock);
begin
  Abstract;
end;

procedure TAplImage.LoadPalette(AStream: PStream; const ABlock: TAplImageBlock);
begin
  if HasException then
    exit;
  FreeAndNil(FPalette);
  FPalette := New(PRgbPalette, Create(pfApl));
  FPalette^.SetCompression(ABlock.Compression, ABlock.CompressionLevel);
  CheckForExceptions(FPalette);
  if not HasException then
    FPalette^.LoadFromStream(AStream);
  CheckForExceptions(FPalette);
  CheckForExceptions(AStream);
end;

procedure TAplImage.CreateBuffer;
begin
  Abstract;
end;

procedure TAplImage.SaveToStream(AStream: PStream);
var
  header: TAplImageHeader;
  compressor: PCompressor;
begin
  if HasException then
    exit;
  GetHeader(header);
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;

  { write header }
  SaveHeader(AStream, header);
  if CheckForExceptions(AStream) then
    exit;

  { write palette if present }
  if Assigned(FPalette) and not HasException then
    SavePalette(AStream);

  { write image data to data stream }
  if not HasException then
    SaveImage(AStream);
end;

procedure TAplImage.SaveImage(AStream: PStream);
begin
  Abstract;
end;

procedure TAplImage.SavePalette(AStream: PStream);
var
  block: TAplImageBlock;
  compressor: PCompressor;
begin
  if not Assigned(FPalette) then
    exit;
  FillChar(block, SizeOf(block), 0);
  block.BlockType := btPalette;
  block.Size := FPalette^.ByteSize;
  block.Compression := FPalette^.Compression;
  block.CompressionLevel := FPalette^.CompressionLevel;
  AStream^.Write(@block, SizeOf(block));
  FPalette^.SaveToStream(AStream);
  CheckForExceptions(FPalette);
  CheckForExceptions(AStream);
end;

procedure TAplImage.SetPalette(APalette: PRgbPalette);
begin
  FPalette := APalette;
end;

destructor TAplImage.Free;
begin
  FreeAndNil(FPalette);
  inherited Free;
end;

procedure TAplImage.Init;
begin
  inherited Init;
  FBuffer := nil;
  FPalette := nil;
  FCompression := acLzw;
  FCompressionLevel := clHigh;
  FWidth := 0;
  FHeight := 0;
  FBpp := 0;
  FPlanes := 0;
end;

function TAplBufferImage.Buffer: PByte;
begin
  Buffer := FBuffer;
end;

procedure TAplBufferImage.SetBuffer(ABuffer: PByte);
begin
  if Assigned(FBuffer) then
    FreeMem(FBuffer, DataSize);
  FBuffer := ABuffer;
end;

procedure TAplBufferImage.Clear(AColor: byte);
var
  size: word;
  buff: pointer;
begin
  if HasException then
    exit;
  if DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  size := DataSize;
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
  if DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  size := DataSize div SizeOf(word);
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
  if DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  size := DataSize div SizeOf(longint);
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
  if DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if DataSize > MaxVarSize then begin
    Raise(ecImageTooLarge);
    exit;
  end;
  GetMem(FBuffer, DataSize);
  if NilPtr(FBuffer, ecNotEnoughMemory) then
    exit;
end;

procedure TAplBufferImage.LoadImage(AStream: PStream; const ABlock: TAplImageBlock);
var
  compressor: PCompressor;
begin
  if HasException then
    exit;
  CreateBuffer;
  if HasException then
    exit;
  if ABlock.Compression = acNone then
    AStream^.Read(FBuffer, ABlock.Size)
  else begin
    compressor := TCompression.GetCompressor(ABlock.Compression, ABlock.CompressionLevel);
    compressor^.DecompressToBuffer(AStream, FBuffer, ABlock.Size);
    CheckForExceptions(AStream);
    CheckForExceptions(compressor);
    FreeAndNil(compressor);
  end;
end;

procedure TAplBufferImage.SaveImage(AStream: PStream);
var
  block: TAplImageBlock;
  compressor: PCompressor;
begin
  FillChar(block, SizeOf(block), 0);
  block.BlockType := btImage;
  block.Size := DataSize;
  block.Compression := FCompression;
  block.CompressionLevel := FCompressionLevel;
  AStream^.Write(@block, SizeOf(block));
  if FCompression = acNone then
    AStream^.Write(FBuffer, block.Size)
  else begin
    compressor := TCompression.GetCompressor(FCompression, FCompressionLevel);
    compressor^.CompressFromBuffer(FBuffer, AStream, block.Size);
    CheckForExceptions(compressor);
    FreeAndNil(compressor);
  end;
  CheckForExceptions(AStream);
end;

destructor TAplBufferImage.Free;
begin
  if Assigned(FBuffer) and (DataSize > 0) then begin
    FreeMem(FBuffer, DataSize);
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
  if DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  PMemoryStream(FBuffer)^.Seek(0, soFromBeginning);
  PMemoryStream(FBuffer)^.Fill(DataSize, AColor);
end;

procedure TAplStreamImage.ClearWord(AColor: word);
begin
  if HasException then
    exit;
  if DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  PMemoryStream(FBuffer)^.Seek(0, soFromBeginning);
  PMemoryStream(FBuffer)^.FillWord(DataSize, AColor);
end;

procedure TAplStreamImage.ClearLong(AColor: longint);
begin
  if HasException then
    exit;
  if DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  if not Assigned(FBuffer) then begin
    Raise(ecInvalidImage);
    exit;
  end;
  PMemoryStream(FBuffer)^.Seek(0, soFromBeginning);
  PMemoryStream(FBuffer)^.FillLong(DataSize, AColor);
end;

procedure TAplStreamImage.CreateBuffer;
begin
  if HasException then
    exit;
  if DataSize = 0 then begin
    Raise(ecInvalidImage);
    exit;
  end;
  FBuffer := New(PMemoryStream, Create(DataSize));
  if NilPtr(FBuffer, ecNotEnoughMemory) then
    exit;
  PMemoryStream(FBuffer)^.FreeBuffers := true;
end;

procedure TAplStreamImage.LoadImage(AStream: PStream; const ABlock: TAplImageBlock);
var
  compressor: PCompressor;
begin
  if HasException then
    exit;
  CreateBuffer;
  if HasException then
    exit;
  if ABlock.Compression = acNone then
    AStream^.WriteToStream(Buffer, ABlock.Size)
  else begin
    CreateBuffer;
    compressor := TCompression.GetCompressor(ABlock.Compression, ABlock.CompressionLevel);
    compressor^.DecompressStream(AStream, Buffer, ABlock.Size);
    CheckForExceptions(compressor);
    FreeAndNil(compressor);
  end;
  CheckForExceptions(Buffer);
  CheckForExceptions(AStream);
end;

procedure TAplStreamImage.SaveImage(AStream: PStream);
var
  block: TAplImageBlock;
  compressor: PCompressor;
  position: longint;
begin
  FillChar(block, SizeOf(block), 0);
  block.BlockType := btImage;
  block.Size := DataSize;
  block.Compression := FCompression;
  block.CompressionLevel := FCompressionLevel;
  position := AStream^.Position;
  AStream^.Write(@block, SizeOf(block));
  Buffer^.Seek(0, soFromBeginning);
  if FCompression = acNone then
    Buffer^.WriteToStream(AStream, DataSize)
  else begin
    compressor := TCompression.GetCompressor(FCompression, FCompressionLevel);
    block.Size := compressor^.CompressFromBuffer(Buffer, AStream, DataSize);
    CheckForExceptions(compressor);
    FreeAndNil(compressor);
    AStream^.Seek(position, soFromBeginning);
    AStream^.Write(@block, SizeOf(block));
  end;
  CheckForExceptions(Buffer);
  CheckForExceptions(AStream);
end;

destructor TAplStreamImage.Free;
begin
  if Assigned(FBuffer) then
    FreeAndNil(FBuffer);
  inherited Free;
end;

begin
end.