{$I COMPILER.INC}
unit Compress;

interface

uses
  AplObj,
  AplTypes,
  AplConst,
  Streams,
  AplUtils;

type
  PCompressor = ^TCompressor;
  PNonCompressor = ^TNonCompressor;
  PCompressProgressProc = ^TCompressProgressProc;

  TAplCompression = (
    acNone,
    acLzw,
    acGif
  );

  TCompressionLevel = (
    clLow,
    clMedium,
    clHigh
  );

  TCompressProgressProc = procedure(var AEvent: TProgressEvent);

  TCompressor = object(TStatusObject)
  private
    FReadBufferSize: word;
    FWriteBufferSize: word;
    FSource, FDest: PStream;
    FWriteSize, FReadSize: word;
    FReadPos, FWritePos: word;
    FReadBitCounter: shortint;
    FWriteBitCounter: shortint;
    FReadBitBuffer: longint;
    FWriteBitBuffer: longint;
    FReadBuffer, FWriteBuffer: PByte;
    FReadPtr, FWritePtr: PByte;
    FProgressCounter: longint;
    procedure SetBufferSize(AReadBufferSize, AWriteBufferSize: word);
  public
    OnProgress: PCompressProgressProc;
    Source, Dest: PStream;
    ProgressIncrement: word;
    ReadTotal, WriteTotal: longint;
    AddTotalToStream: boolean;
    CompressionLevel: TCompressionLevel;
    constructor CreateBufferSize(AReadBufferSize, AWriteBufferSize: word);
    constructor Create;
    function CompressStream(ASource, ADest: PStream; ALength: longint): longint; virtual;
    function CompressFromBuffer(ASource: pointer; ADest: PStream; ALength: word): longint;
    function CompressBufferToBuffer(ASource: pointer; var ADest: pointer;
      ALength: word): longint;
    function ReadByte: byte;
    function ReadBits(ABitCount: shortint): word;
    function FlushWriteBuffer: boolean;
    function GetOriginalSize(ASource: PStream): longint; virtual;
    procedure WriteBits(ANum: word; ABitCount: shortint);
    procedure WriteByte(AByte: byte);
    procedure EndWriteBits; virtual;
    procedure DecompressStream(ASource, ADest: PStream; AOriginalSize: longint); virtual;
    procedure DecompressToBuffer(ASource: PStream; ADest: pointer; AOriginalSize: word);
    procedure DecompressBufferToBuffer(ASource: pointer; ADest: pointer;
      ALength, AOriginalSize: word);
    procedure Init; virtual;
    procedure InitCompression; virtual;
    procedure UpdateProgress(const AMax, ACurrent: longint);
    procedure SetCompressionLevel(ALevel: TCompressionLevel); virtual;
    destructor Free; virtual;
  end;

  TNonCompressor = object(TCompressor)
    function CompressStream(ASource, ADest: PStream; ALength: longint): longint; virtual;
    function GetOriginalSize(ASource: PStream): longint; virtual;
    procedure DecompressStream(ASource, ADest: PStream; AOriginalSize: longint); virtual;
  end;

  TCompressionManager = object(TStatusObject)
  private
  public
    function GetCompressor(const ACompression: TAplCompression;
      const ALevel: TCompressionLevel): PCompressor;
  end;

var
  TCompression: TCompressionManager;

implementation

uses
  Lzw;

const
  DefaultProgressIncrement = 4096;
  DefaultBufferSize = 4096;

procedure TCompressor.SetBufferSize(AReadBufferSize, AWriteBufferSize: word);
begin
  FReadBufferSize := AReadBufferSize;
  FWriteBufferSize := AWriteBufferSize;
  GetMem(FReadBuffer, FReadBufferSize);
  GetMem(FWriteBuffer, FWriteBufferSize);
end;

constructor TCompressor.Create;
begin
  inherited Create;
  SetBufferSize(DefaultBufferSize, DefaultBufferSize);
end;

constructor TCompressor.CreateBufferSize(AReadBufferSize, AWriteBufferSize: word);
begin
  inherited Create;
  SetBufferSize(AReadBufferSize, AWriteBufferSize);
end;

procedure TCompressor.Init;
begin
  inherited Init;
  OnProgress := nil;
  FWriteSize := 0;
  FReadSize := 0;
  ReadTotal := 0;
  WriteTotal := 0;
  FReadPos := MaxVarSize;
  FWritePos := 0;
  FReadPtr := nil;
  FWritePtr := nil;
  Source := nil;
  Dest := nil;
  CompressionLevel := clHigh;
  FReadBitCounter := 0;
  FWriteBitCounter := 0;
  FReadBitBuffer := 0;
  FWriteBitBuffer := 0;
  FReadBuffer := nil;
  FWriteBuffer := nil;
  AddTotalToStream := false;
  ProgressIncrement := DefaultProgressIncrement;
end;

function TCompressor.GetOriginalSize(ASource: PStream): longint;
begin
  GetOriginalSize := 0;
end;

procedure TCompressor.WriteByte(AByte: byte);
var
  written: longint;
begin
  if FWritePos >= FWriteSize then begin
    written := Dest^.Write(FWriteBuffer, FWritePos);
    if written = 0 then begin
      Raise(ecWritePastStreamEnd);
      exit;
    end;
    if CheckReRaise(Dest) then
      exit;
    FWritePos := 0;
    FWritePtr := FWriteBuffer;
    FWriteSize := written;
  end;
  FWritePtr^ := AByte;
  Inc(WriteTotal);
  Inc(FWritePtr);
  Inc(FWritePos);
end;

procedure TCompressor.EndWriteBits;
var
  aByte: byte;
  written: word;
  event: TProgressEvent;
begin
  if HasException then
    exit;
  if FWriteBitCounter > 0 then begin
    aByte := FWriteBitBuffer;
    WriteByte(aByte);
    if HasException then
      exit;
    FWriteBitBuffer := 0;
    FWriteBitCounter := 0;
  end;
  FlushWriteBuffer;
  if Assigned(OnProgress) and (ReadTotal mod ProgressIncrement = 0) then begin
    event.Create;
    event.Max := Source^.Size;
    event.Current := ReadTotal;
    event.Sender := @self;
    TCompressProgressProc(OnProgress)(event);
  end;
end;

function TCompressor.ReadByte: byte;
var
  bytesRead: longint;
begin
  if (FReadPos = MaxVarSize) or (FReadPos >= FReadSize) then begin
    bytesRead := Source^.Read(FReadBuffer, FReadBufferSize);
    if bytesRead = 0 then begin
      Raise(ecReadPastStreamEnd);
      exit;
    end;
    if CheckReRaise(Source) then
      exit;
    FReadPos := 0;
    FReadPtr := FReadBuffer;
    FReadSize := bytesRead;
  end;
  ReadByte := FReadPtr^;
  Inc(ReadTotal);
  Inc(FReadPtr);
  Inc(FReadPos);
end;

procedure TCompressor.WriteBits(ANum: word; ABitCount: shortint);
var
  aByte: byte;
begin
  FWriteBitBuffer := FWriteBitBuffer or (longint(ANum) shl FWriteBitCounter);
  Inc(FWriteBitCounter, ABitCount);
  while FWriteBitCounter >= 8 do begin
    aByte := byte(FWriteBitBuffer and $FF);
    WriteByte(aByte);
    FWriteBitBuffer := FWriteBitBuffer shr 8;
    Dec(FWriteBitCounter, 8);
  end;
end;

function TCompressor.ReadBits(ABitCount: shortint): word;
var
  readResult: word;
  bytesRead: word;
begin
  while FReadBitCounter < ABitCount do begin
    readResult := ReadByte;
    FReadBitBuffer := FReadBitBuffer or (readResult shl FReadBitCounter);
    Inc(FReadBitCounter, 8);
  end;
  ReadBits := word(FReadBitBuffer and ((1 shl longint(ABitCount)) - 1));
  FReadBitBuffer := FReadBitBuffer shr ABitCount;
  Dec(FReadBitCounter, ABitCount);
end;

procedure TCompressor.UpdateProgress(const AMax, ACurrent: longint);
var
  event: TProgressEvent;
begin
  if (ACurrent >= AMax) or (FProgressCounter >= ProgressIncrement) then begin
    if Assigned(OnProgress) then begin
      event.Create;
      event.Max := AMax;
      event.Current := ACurrent;
      event.Sender := @self;
      TCompressProgressProc(OnProgress)(event);
    end;
    FProgressCounter := 0;
    exit;
  end;
  Inc(FProgressCounter);
end;

function TCompressor.FlushWriteBuffer: boolean;
var
  written: word;
begin
  FlushWriteBuffer := true;
  if Dest^.HasException or HasException or (FWritePos < 1) then begin
    FlushWriteBuffer := false;
    exit;
  end;
  if FWritePos > 0 then begin
    written := Dest^.Write(FWriteBuffer, FWritePos);
    if written = 0 then begin
      Raise(ecWritePastStreamEnd);
      FlushWriteBuffer := false;
      exit;
    end;
  end;
  if Dest^.HasException then begin
    Raise(Dest^.Exception^.Code);
    Dest^.ClearException;
    FlushWriteBuffer := false;
  end;
end;

destructor TCompressor.Free;
begin
  if Assigned(FReadBuffer) then begin
    FreeMem(FReadBuffer, FReadBufferSize);
    FReadBuffer := nil;
  end;
  if Assigned(FWriteBuffer) then begin
    FreeMem(FWriteBuffer, FWriteBufferSize);
    FWriteBuffer := nil;
  end;
  inherited Free;
end;

procedure TCompressor.InitCompression;
begin
  FReadPos := MaxVarSize;
  FWritePos := 0;
  WriteTotal := 0;
  ReadTotal := 0;
  FWritePtr := FWriteBuffer;
  FWriteSize := FWriteBufferSize;
  FReadSize := FReadBufferSize;
  FWriteBitBuffer := 0;
  FReadBitCounter := 0;
  FWriteBitCounter := 0;
  FReadBitBuffer := 0;
  FReadPtr := FReadBuffer;
  FProgressCounter := 0;
end;

function TCompressor.CompressFromBuffer(ASource: pointer; ADest: PStream; ALength: word): longint;
var
  sourceStream: PMemoryStream;
begin
  CompressFromBuffer := 0;
  sourceStream := New(PMemoryStream, CreateBuffer(ASource, ALength));
  if NilPtr(sourceStream, ecNotEnoughMemory) then
    exit;
  sourceStream^.FreeBuffers := false;
  CompressFromBuffer := CompressStream(sourceStream, ADest, ALength);
  CheckReRaise(ADest);
  CheckReRaise(sourceStream);
  FreeAndNil(sourceStream);
end;

procedure TCompressor.DecompressToBuffer(ASource: PStream; ADest: pointer; AOriginalSize: word);
var
  destStream: PMemoryStream;
begin
  destStream := New(PMemoryStream, CreateBuffer(ADest, AOriginalSize));
  if NilPtr(destStream, ecNotEnoughMemory) then
    exit;
  destStream^.FreeBuffers := false;
  DecompressStream(ASource, destStream, AOriginalSize);
  CheckReRaise(ASource);
  CheckReRaise(destStream);
  FreeAndNil(destStream);
end;

procedure TCompressor.DecompressBufferToBuffer(ASource: pointer; ADest: pointer;
  ALength, AOriginalSize: word);
var
  sourceStream: PMemoryStream;
  destStream: PMemoryStream;
begin
  sourceStream := New(PMemoryStream, CreateBuffer(ASource, ALength));
  if NilPtr(sourceStream, ecNotEnoughMemory) then
    exit;
  sourceStream^.FreeBuffers := false;
  destStream := New(PMemoryStream, CreateBuffer(ADest, AOriginalSize));
  if NilPtr(destStream, ecNotEnoughMemory) then begin
    FreeAndNil(sourceStream);
    exit;
  end;
  destStream^.FreeBuffers := false;
  DecompressStream(sourceStream, destStream, AOriginalSize);
  CheckReRaise(sourceStream);
  CheckReRaise(destStream);
  FreeAndNil(sourceStream);
  FreeAndNil(destStream);
end;

function TCompressor.CompressBufferToBuffer(ASource: pointer; var ADest: pointer;
  ALength: word): longint;
var
  sourceStream: PMemoryStream;
  destStream: PBufferStream;
  size: longint;
begin
  ADest := nil;
  sourceStream := New(PMemoryStream, CreateBuffer(ASource, ALength));
  if NilPtr(sourceStream, ecNotEnoughMemory) then
    exit;
  sourceStream^.FreeBuffers := false;
  destStream := New(PBufferStream, Create);
  if NilPtr(destStream, ecNotEnoughMemory) then begin
    FreeAndNil(sourceStream);
    exit;
  end;
  destStream^.FreeBuffers := false;
  size := CompressStream(sourceStream, destStream, ALength);
  CheckReRaise(sourceStream);
  CheckReRaise(destStream);
  if size > MaxVarSize then
    Raise(ecCompressedDataTooLarge);
  if not HasException then begin
    destStream^.Resize(size);
    ADest := destStream^.BufferPointer;
  end;
  FreeAndNil(sourceStream);
  FreeAndNil(destStream);
  CompressBufferToBuffer := ALength;
end;

function TCompressor.CompressStream(ASource, ADest: PStream; ALength: longint): longint;
begin
  InitCompression;
  Source := ASource;
  Dest := ADest;
  CompressStream := 0;
end;

procedure TCompressor.DecompressStream(ASource, ADest: PStream; AOriginalSize: longint);
begin
  Source := ASource;
  Dest := ADest;
  InitCompression;
end;

procedure TCompressor.SetCompressionLevel(ALevel: TCompressionLevel);
begin
  CompressionLevel := ALevel;
end;

function TNonCompressor.CompressStream(ASource, ADest: PStream; ALength: longint): longint;
begin
  ASource^.WriteToStream(ADest, ALength);
  CompressStream := ALength;
end;

function TNonCompressor.GetOriginalSize(ASource: PStream): longint;
begin
  GetOriginalSize := ASource^.Size;
end;

procedure TNonCompressor.DecompressStream(ASource, ADest: PStream; AOriginalSize: longint);
begin
  ASource^.WriteToStream(ADest, AOriginalSize);
end;

function TCompressionManager.GetCompressor(const ACompression: TAplCompression;
  const ALevel: TCompressionLevel): PCompressor;
var
  result: PCompressor;
  bitSize: byte;
begin
  case ACompression of
    acNone:
      result := New(PNonCompressor, Create);
    acLzw: begin
      bitSize := LzwCompressionBitSize[ALevel];
      result := New(PLzw, CreateBitSize(bitSize));
      PLzw(result)^.SetLzwCodesProc := @SetLzwCodes;
      result^.AddTotalToStream := false;
    end;
    acGif: begin
      result := New(PLzw, CreateBitSize(13));
      PLzw(result)^.SetLzwCodesProc := @SetGifLzwCodes;
      result^.AddTotalToStream := false;
    end;
    else
      result := nil;
  end;
  GetCompressor := result;
end;

var
  PreviousExitProc: PProc;

procedure Finalize; far;
begin
  ExitProc := PreviousExitProc;
  TCompression.Free;
end;

begin
  PreviousExitProc := ExitProc;
  ExitProc := @Finalize;
  TCompression.Create;
end.