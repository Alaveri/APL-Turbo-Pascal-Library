{$I COMPILER.INC}
unit Lzw;

interface

uses
  AplTypes,
  AplObj,
  Compress,
  AplConst,
  Streams,
  AplUtils;

type
  PDictEntry = ^TDictEntry;
  PLzw = ^TLzw;
  PLzwCodes = ^TLzwCodes;
  PSetLzwCodesProc = ^TSetLzwCodesProc;

  TLzwCompressionLevels = array[TCompressionLevel] of byte;

  TDictEntry = record
    Code: word;
    Prefix: word;
    Char: byte;
  end;

  TLzwCodes = record
    EndOfStream: word;
    IncreaseCodeSize: word;
    ClearDict: word;
    EmptyCode: word;
    FirstCode: word;
    DeferredClear: boolean;
    { If true, the bit size of the data is encoded in the stream. }
    { If false, data is assumed to be 8-bit bytes. }
    { TODO: Implement this for GIF. }
    EncodeDataBitSize: boolean;
  end;

  TSetLzwCodesProc = procedure(var ACodes: TLzwCodes; ABitSize: byte);

  TLzw = object(TCompressor)
  private
    FDict: PDictEntry;
    FDictEntries: word;
    FDictSize: word;
    FDecodeBuffer: PByte;
    FCurrentBitSize: byte;
    FMaxCode: word;
    FCurrentMaxCode: word;
    FNextCode: word;
    FOverflow: boolean;
    FHashShift: byte;
    FCodes: TLzwCodes;
    function AllocateDictionary: boolean;
    function AllocateDecodeBuffer: boolean;
    function FindEntry(APrefix: word; AChar: byte): word;
    function DecodeString(ACount: word; ACode: word): word;
    procedure DeallocateDictionary;
    procedure DeallocateDecodeBuffer;
    procedure InitCoder;
    procedure InitCompression; virtual;
  public
    BitSize: byte;
    SetLzwCodesProc: PSetLzwCodesProc;
    constructor CreateBitSize(ABitSize: byte);
    constructor CreateCodes(ASetCodesProc: PSetLzwCodesProc);
    constructor CreateAll(ABitSize: byte; ASetCodesProc: PSetLzwCodesProc);
    destructor Free; virtual;
    function CompressStream(ASource, ADest: PStream; ALength: longint): longint; virtual;
    function GetOriginalSize(ASource: PStream): longint; virtual;
    procedure Init; virtual;
    procedure DecompressStream(ASource, ADest: PStream; AOriginalSize: longint); virtual;
    procedure SetCompressionLevel(ALevel: TCompressionLevel); virtual;
  end;

procedure SetLzwCodes(var ACodes: TLzwCodes; ABitSize: byte); far;
procedure SetGifLzwCodes(var ACodes: TLzwCodes; ABitSize: byte); far;

const
  LzwCompressionBitSize: TLzwCompressionLevels = (12, 12, 13);

implementation

procedure SetLzwCodes(var ACodes: TLzwCodes; ABitSize: byte);
begin
  ACodes.EndOfStream := 256;
  ACodes.IncreaseCodeSize := 257;
  ACodes.ClearDict := 258;
  ACodes.EmptyCode := 259;
  ACodes.FirstCode := 260;
  ACodes.DeferredClear := false;
  ACodes.EncodeDataBitSize := false;
end;

procedure SetGifLzwCodes(var ACodes: TLzwCodes; ABitSize: byte);
begin
  ACodes.ClearDict := 256;
  ACodes.EndOfStream := ACodes.ClearDict + 1;
  ACodes.FirstCode := ACodes.ClearDict + 2;
  ACodes.IncreaseCodeSize := ACodes.ClearDict + 3;
  ACodes.EmptyCode := $FFFF;
  ACodes.DeferredClear := true;
  ACodes.EncodeDataBitSize := true;
end;

const
  SupportedBitSizes = [12, 13];

const
  DefaultBitSize = 13;
  StartBitSize = 9;

constructor TLzw.CreateBitSize(ABitSize: byte);
begin
  inherited Create;
  if not (ABitSize in [12, 13]) then begin
    Raise(ecStreamFormatNotSupported);
    exit;
  end;
  BitSize := ABitSize;
end;

destructor TLzw.Free;
begin
  DeallocateDecodeBuffer;
  DeallocateDictionary;
  inherited Free;
end;

procedure TLzw.Init;
begin
  inherited Init;
  BitSize := DefaultBitSize;
  FMaxCode := 0;
  FDict := nil;
  FDictEntries := 0;
  FDictSize := 0;
  FDecodeBuffer := nil;
  FOverflow := false;
  FNextCode := 0;
  FCurrentBitSize := BitSize;
  SetLzwCodesProc := nil;
  AddTotalToStream := true;
end;

function TLzw.AllocateDecodeBuffer: boolean;
begin
  AllocateDecodeBuffer := true;
  DeallocateDecodeBuffer;
  GetMem(FDecodeBuffer, FDictEntries);
  if not Assigned(FDecodeBuffer) then begin
    Raise(ecNotEnoughMemory);
    AllocateDecodeBuffer := false;
  end;
end;

procedure TLzw.DeallocateDecodeBuffer;
begin
  if Assigned(FDecodeBuffer) then
    FreeMem(FDecodeBuffer, FDictEntries);
  FDecodeBuffer := nil;
end;

function TLzw.AllocateDictionary: boolean;
begin
  AllocateDictionary := true;
  DeallocateDictionary;

  GetMem(FDict, FDictSize);

  if not Assigned(FDict) then begin
    Raise(ecNotEnoughMemory);
    AllocateDictionary := false;
  end;
end;

procedure TLzw.DeallocateDictionary;
begin
  if Assigned(FDict) then
    FreeMem(FDict, FDictSize);
  FDict := nil;
end;

function TLzw.FindEntry(APrefix: word; AChar: byte): word;
var
  index, offset: longint;
  entry: PDictEntry;
begin
  index := (AChar shl FHashShift) xor APrefix;
  offset := 1;
  if index <> 0 then
    offset :=  FDictEntries - index;
  repeat
    entry := FDict;
    Inc(entry, index);
    if entry^.Code = FCodes.EmptyCode then
      break;
    if (entry^.Prefix = APrefix) and (entry^.Char = AChar) then
      break;
    Dec(index, offset);
    if index < 0 then
      Inc(index, FDictEntries);
  until false;
  FindEntry := index;
end;

function TLzw.DecodeString(ACount: word; ACode: word): word;
var
  bufferPtr: PByte;
  entry: PDictEntry;
begin
  bufferPtr := FDecodeBuffer;
  Inc(bufferPtr, ACount);
  while ACode > High(byte) do begin
    entry := FDict;
    Inc(entry, ACode);
    ACode := entry^.Prefix;
    bufferPtr^ := entry^.Char;
    Inc(ACount);
    Inc(bufferPtr);
  end;
  bufferPtr^ := ACode;
  Inc(ACount);
  DecodeString := ACount;
end;

constructor TLzw.CreateCodes(ASetCodesProc: PSetLzwCodesProc);
begin
  Create;
  SetLzwCodesProc := ASetCodesProc;
end;

constructor TLzw.CreateAll(ABitSize: byte; ASetCodesProc: PSetLzwCodesProc);
begin
  CreateBitSize(ABitSize);
  SetLzwCodesProc := ASetCodesProc;
end;

procedure TLzw.SetCompressionLevel(ALevel: TCompressionLevel);
begin
  inherited SetCompressionLevel(ALevel);
  BitSize := LzwCompressionBitSize[ALevel];
end;

procedure TLzw.InitCompression;
begin
  inherited InitCompression;
  if Assigned(SetLzwCodesProc) then
    TSetLzwCodesProc(SetLzwCodesProc)(FCodes, BitSize)
  else
    SetLzwCodes(FCodes, BitSize);

  if BitSize = 12 then
    FDictEntries := 5021
  else if BitSize = 13 then
    FDictEntries := 9029
  else if BitSize = 14 then
    FDictEntries := 18041
  else if BitSize = 15 then
    FDictEntries := 49063;
  FHashShift := BitSize - 8;
  FDictSize := FDictEntries * SizeOf(TDictEntry);
  AllocateDictionary;
  InitCoder;
end;

procedure TLzw.InitCoder;
var
  index: word;
  entry: PDictEntry;
begin
  FCurrentBitSize := StartBitSize;
  FMaxCode := 1 shl BitSize - 1;
  FCurrentMaxCode := 1 shl FCurrentBitSize - 1;
  FNextCode := FCodes.FirstCode;
  entry := FDict;
  for index := 0 to FDictEntries - 1 do begin
    entry^.Code := FCodes.EmptyCode;
    Inc(entry);
  end;
  FOverflow := false;
end;

function TLzw.GetOriginalSize(ASource: PStream): longint;
var
  bits: byte;
  total: longint;
  startPos: longint;
begin
  GetOriginalSize := 0;
  startPos := ASource^.Position;
  bits := ASource^.ReadByte;
  total := ASource^.ReadLong;
  ASource^.Seek(startPos, soFromBeginning);
  CheckReRaise(ASource);
  if HasException then
    exit;
  GetOriginalSize := total;
end;

function TLzw.CompressStream(ASource, ADest: PStream; ALength: longint): longint;
var
  character: byte;
  code: word;
  index: word;
  entry: PDictEntry;
  endPos: longint;
  written: longint;
  destStart: longint;
begin
  inherited CompressStream(ASource, ADest, ALength);
  destStart := ADest^.Position;

  if Source^.Position + ALength > Source^.Size then
    Raise(ecReadPastStreamEnd);
  if HasException then
    exit;

  ADest^.WriteByte(BitSize);
  code := ReadByte;
  if ASource^.HasException then begin
    Raise(ADest^.Exception^.Code);
    exit;
  end;

  if AddTotalToStream then
    ADest^.WriteLong(ALength);

  while ReadTotal < ALength do begin
    character:= ReadByte;
    if HasException then
      exit;

    UpdateProgress(ALength, ReadTotal);
    index := FindEntry(code, character);
    entry := FDict;
    Inc(entry, index);

    if entry^.Code <> FCodes.EmptyCode then begin
      code := Entry^.Code;
      continue;
    end;

    if FNextCode < FMaxCode then begin
      entry^.Code := FNextCode;
      entry^.Prefix := code;
      entry^.Char := character;
      Inc(FNextCode);
    end
    else
      FOverflow := true;

    if (code >= FCurrentMaxCode) and (FCurrentBitSize < BitSize) then begin
      WriteBits(FCodes.IncreaseCodeSize, FCurrentBitSize);
      Inc(FCurrentBitSize);
      FCurrentMaxCode := 1 shl FCurrentBitSize - 1;
    end;

    WriteBits(code, FCurrentBitSize);
    code := character;
    if FOverflow then begin
      WriteBits(FCodes.ClearDict, FCurrentBitSize);
      InitCoder;
    end;
  end;
  WriteBits(code, FCurrentBitSize);
  WriteBits(FCodes.EndOfStream, FCurrentBitSize);
  EndWriteBits;
  UpdateProgress(ALength, ReadTotal);
  CompressStream := ADest^.Position - destStart;
end;

procedure TLzw.DecompressStream(ASource, ADest: PStream; AOriginalSize: longint);
var
  oldCode, code: word;
  character: word;
  count, index: word;
  decodePtr: PByte;
  entry: PDictEntry;
begin
  inherited DecompressStream(ASource, ADest, AOriginalSize);

  if HasException then
    exit;

  BitSize := ASource^.ReadByte;
  if not (BitSize in SupportedBitSizes) then begin
    Raise(ecStreamFormatNotSupported);
    exit;
  end;
  if AddTotalToStream then
    AOriginalSize := ASource^.ReadLong;

  InitCoder;
  AllocateDecodeBuffer;

  oldCode := ReadBits(FCurrentBitSize);
  if HasException or (oldCode = FCodes.EndOfStream) then
    exit;

  character := oldCode;
  WriteByte(oldCode);
  if HasException then
    exit;

  repeat
    code := ReadBits(FCurrentBitSize);
    if code = FCodes.IncreaseCodeSize then begin
      Inc(FCurrentBitSize);
      continue;
    end
    else if code = FCodes.ClearDict then begin
      InitCoder;
      oldCode := ReadBits(FCurrentBitSize);
      if oldCode = FCodes.EndOfStream then
        break;
      WriteByte(oldCode);
      continue;
    end
    else if code = FCodes.EndOfStream then
      break;
    if code >= FNextCode then begin
      FDecodeBuffer^ := byte(character);
      count := DecodeString(1, oldCode);
    end
    else
      count := DecodeString(0, code);

    decodePtr := FDecodeBuffer;
    Inc(decodePtr, count - 1);
    character := word(decodePtr^);
    while count > 0 do begin
      WriteByte(decodePtr^);
      Dec(decodePtr);
      Dec(count);
    end;
    if HasException then
      break;
    UpdateProgress(AOriginalSize, WriteTotal);

    if FNextCode <= FMaxCode then begin
      entry := FDict;
      Inc(entry, FNextCode);
      entry^.Prefix := oldCode;
      entry^.Char := character;
      Inc(FNextCode);
      if FCodes.DeferredClear and (FNextCode >= FMaxCode) and (FCurrentBitSize < BitSize) then begin
        FCurrentBitSize := BitSize;
        FMaxCode := FMaxCode shl 1;
      end;
    end;
    oldCode := code;
  until false;
end;

end.
