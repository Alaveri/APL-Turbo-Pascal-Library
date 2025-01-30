{$I COMPILER.INC}
unit Streams;

interface

uses
  Dos,
  AplObj,
  AplTypes,
  AplConst,
  DateTime,
  AplMath,
  AplUtils,
  Lists,
  MemDrv;

type
  PStream = ^TStream;
  PMemoryStream = ^TMemoryStream;
  PFileStream = ^TFileStream;
  PStreamList = ^TStreamList;
  PMemoryStreamList = ^TMemoryStreamList;
  PStreamListProc = ^TStreamListProc;
  PMemoryStreamListProc = ^TMemoryStreamListProc;
  PBufferStreamSizeFunc = ^TBufferStreamSizeFunc;

  TStreamListProc = procedure(AItem: PStream);
  TMemoryStreamListProc = procedure(AItem: PMemoryStream);
  TBufferStreamSizeFunc = function(ACapacity: longint): longint;

  TSeekOrigin =
  (
    soFromBeginning,
    soFromEnd,
    soFromPosition
  );

  TFileStreamMode =
  (
    fmCreate,
    fmRead,
    fmWrite,
    fmReadWrite
  );

  TStream = object(TStatusObject)
  private
    FClosed: boolean;
  public
    Position: longint;
    Size: longint;
    destructor Free; virtual;
    function EndOfStream: boolean; virtual;
    function CanRead: boolean; virtual;
    function CanWrite: boolean; virtual;
    function CanSeek: boolean; virtual;
    function Read(ABuffer: pointer; ACount: longint): longint; virtual;
    function ReadByte: byte; virtual;
    function ReadInteger: integer; virtual;
    function ReadWord: word; virtual;
    function ReadLong: longint; virtual;
    function ReadString: string; virtual;
    function ReadPChar: PChar; virtual;
    function ReadDouble: double; virtual;
    function ReadBool: boolean; virtual;
    function ReadReal: real; virtual;
    function ReadChar: char; virtual;
    function Write(ABuffer: pointer; ACount: longint): longint; virtual;
    function Seek(AOffset: longint; AOrigin: TSeekOrigin): longint; virtual;
    function WriteToStream(AStream: PStream; ACount: longint): longint; virtual;
    function ReadFromStream(AStream: PStream; ACount: longint): longint; virtual;
    procedure Init; virtual;
    procedure Close; virtual;
    procedure ReadDateTime(var ADateTime: TDateTime); virtual;
    procedure WriteByte(AValue: byte); virtual;
    procedure WriteInteger(AValue: integer); virtual;
    procedure WriteWord(AValue: word); virtual;
    procedure WriteLong(AValue: longint); virtual;
    procedure WriteString(const AString: string); virtual;
    procedure WriteDouble(AValue: double); virtual;
    procedure WriteReal(AValue: real); virtual;
    procedure WriteBool(AValue: boolean); virtual;
    procedure WriteDateTime(const ADateTime: TDateTime); virtual;
    procedure WritePChar(AValue: PChar); virtual;
  end;

  TPersistent = object(TStatusObject)
  private
  public
    function IsPersistent: boolean; virtual;
    procedure LoadFromFile(const AFileName: string); virtual;
    procedure LoadFromStream(AStream: PStream); virtual;
    procedure SaveToFile(const AFileName: string); virtual;
    procedure SaveToStream(AStream: PStream); virtual;
  end;

  TMemoryStream = object(TStream)
  private
    FReferences: PReferenceList;
    procedure DeallocateReferences;
  public
    FreeBuffers: boolean;
    constructor Create(ASize: longint);
    constructor CreateBuffer(ABuffer: pointer; ASize: word);
    destructor Free; virtual;
    function Read(ABuffer: pointer; ACount: longint): longint; virtual;
    function Write(ABuffer: pointer; ACount: longint): longint; virtual;
    function WriteToStream(AStream: PStream; ACount: longint): longint; virtual;
    function CanRead: boolean; virtual;
    function CanWrite: boolean; virtual;
    function CanSeek: boolean; virtual;
    function BufferPointer: pointer;
    function Fill(ACount: longint; AByte: byte): longint; virtual;
    function FillWord(ACount: longint; AWord: word): longint; virtual;
    function FillLong(ACount: longint; ALong: longint): longint; virtual;
    procedure SetSize(ASize: longint); virtual;
    procedure Init; virtual;
  end;

  TBufferStream = object(TMemoryStream)
  private
    FCapacity: longint;
    procedure SetCapacity(ACapacity: longint);
    procedure Resize(AMinCapacity: longint);
  public
    BufferStreamSizeFunc: PBufferStreamSizeFunc;
    constructor Create;
    constructor CreateCapacity(ACapacity: longint);
    function Write(ABuffer: pointer; ACount: longint): longint; virtual;
    function WriteToStream(AStream: PStream; ACount: longint): longint; virtual;
    procedure Init; virtual;
    destructor Free; virtual;
  end;

  TFileStream = object(TStream)
  private
    FMode: TFileStreamMode;
    FFile: file;
    FOpen: boolean;
    FFilename: string;
    function CheckRead: boolean;
    function CheckWrite: boolean;
  public
    BufferSize: word;
    constructor Create(AFilename: string; AMode: TFileStreamMode);
    constructor CreateBufferSize(AFilename: string; AMode: TFileStreamMode; ABufferSize: word);
    destructor Done; virtual;
    function Read(ABuffer: pointer; ACount: longint): longint; virtual;
    function Write(ABuffer: pointer; ACount: longint): longint; virtual;
    function WriteToStream(AStream: PStream; ACount: longint): longint; virtual;
    function CanRead: boolean; virtual;
    function CanWrite: boolean; virtual;
    function CanSeek: boolean; virtual;
    function Seek(AOffset: longint; AOrigin: TSeekOrigin): longint; virtual;
    procedure Init; virtual;
    procedure Open; virtual;
    procedure Close; virtual;
  end;

  TStreamList = object(TObjectList)
  private
  public
    procedure Init; virtual;
    function Add(AItem: PStream): integer;
    function GetItem(AIndex: integer): PStream;
    function IndexOf(AItem: PStream): integer;
    procedure SetItem(AIndex: integer; AItem: PStream);
    procedure Insert(AIndex: integer; AItem: PStream);
    procedure Delete(AIndex: integer); virtual;
  end;

  TMemoryStreamList = object(TStreamList)
  private
  public
    procedure Init; virtual;
    function Add(AItem: PMemoryStream): integer;
    function GetItem(AIndex: integer): PMemoryStream;
    function IndexOf(AItem: PMemoryStream): integer;
    procedure SetItem(AIndex: integer; AItem: PMemoryStream);
    procedure Insert(AIndex: integer; AItem: PMemoryStream);
    procedure Delete(AIndex: integer); virtual;
  end;

function DefaultBufferStreamSizeFunc(ACapacity: word): word; far;

implementation

uses
  Strings,
  AplStr;

function DefaultBufferStreamSizeFunc(ACapacity: word): word;
var
  newCapacity: word;
begin
  newCapacity := 0;
  while newCapacity < ACapacity do begin
    if newCapacity >= 64 then
      newCapacity := (newCapacity * 3) div 2
    else if newCapacity >= 8 then
      newCapacity := newCapacity + 16
    else
      newCapacity := newCapacity + 4;
  end;
  DefaultBufferStreamSizeFunc := newCapacity;
end;

const
  DefaultFileStreamBufferSize = 4096;
  DefaultyBufferStreamCapacity = 4096;

destructor TStream.Free;
begin
  Close;
  inherited Free;
end;

function TStream.EndOfStream: boolean;
begin
  EndOfStream := Position >= Size;
end;

function TStream.CanRead: boolean;
begin
  CanRead := true;
end;

function TStream.CanWrite: boolean;
begin
  CanWrite := true;
end;

function TStream.CanSeek: boolean;
begin
  CanSeek := true;
end;

function TStream.Read(ABuffer: pointer; ACount: longint): longint;
begin
  Abstract;
end;

function TStream.Write(ABuffer: pointer; ACount: longint): longint;
begin
  Abstract;
end;

function TStream.Seek(AOffset: longint; AOrigin: TSeekOrigin): longint;
var
  newPos: longint;
begin
  if not CanSeek then
    Raise(ecStreamSeekNotSupported);
  if HasException then
    exit;
  case AOrigin of
    soFromBeginning: begin
      newPos := AOffset;
    end;
    soFromEnd: begin
      newPos := Size - AOffset - 1;
    end;
    soFromPosition: begin
      newPos := Position + AOffset;
    end;
  end;
  Position := ClampL(newPos, 0, size);
end;

function TStream.ReadByte: byte;
var
  aNum: byte;
begin
  aNum := 0;
  Read(@aNum, SizeOf(byte));
  ReadByte := aNum;
end;

function TStream.ReadInteger: integer;
var
  aNum: integer;
begin
  aNum := 0;
  Read(@aNum, SizeOf(integer));
  ReadInteger := aNum;
end;

function TStream.ReadLong: longint;
var
  aNum: longint;
begin
  aNum := 0;
  Read(@aNum, SizeOf(longint));
  ReadLong := aNum;
end;

function TStream.ReadDouble: double;
var
  aNum: double;
begin
  aNum := 0;
  Read(@aNum, SizeOf(double));
  ReadDouble := aNum;
end;

function TStream.ReadReal;
var
  aNum: real;
begin
  aNum := 0;
  Read(@aNum, SizeOf(real));
  ReadReal := aNum;
end;

function TStream.ReadChar: char;
var
  aChar: char;
begin
  aChar := #0;
  Read(@aChar, SizeOf(char));
  ReadChar := aChar;
end;

function TStream.ReadBool: boolean;
var
  aBool: boolean;
begin
  aBool := false;
  Read(@aBool, SizeOf(boolean));
  ReadBool := aBool;
end;

function TStream.ReadWord: word;
var
  aNum: word;
begin
  aNum := 0;
  Read(@aNum, SizeOf(word));
  ReadWord := aNum;
end;

function TStream.WriteToStream(AStream: PStream; ACount: longint): longint;
begin
  Abstract;
end;

function TStream.ReadFromStream(AStream: PStream; ACount: longint): longint;
begin
  AStream^.WriteToStream(@self, ACount);
end;

procedure TStream.Init;
begin
  inherited Init;
  Position := 0;
  Size := 0;
  FClosed := true;
end;

procedure TStream.Close;
begin
  FClosed := true;
end;

procedure TStream.ReadDateTime(var ADateTime: TDateTime);
var
  ticks: double;
begin
  Read(@ticks, SizeOf(double));
  ADateTime.CreateTicks(ticks);
end;

procedure TStream.WriteDateTime(const ADateTime: TDateTime);
var
  ticks: double;
begin
  ticks := ADateTime.Ticks;
  Write(@ticks, SizeOf(double));
end;

procedure TStream.WriteByte(AValue: byte);
begin
  Write(@AValue, SizeOf(byte));
end;

procedure TStream.WritePChar(AValue: PChar);
var
  len: word;
begin
  if not Assigned(AValue) then begin
    len := 0;
    WriteWord(len);
    exit;
  end;
  len := StrLen(AValue);
  WriteWord(len);
  Write(AValue, len);
end;

function TStream.ReadPChar: PChar;
var
  len: word;
  result: PChar;
begin
  len := ReadWord;
  if HasException then
    exit;
  result := TString.Alloc(len);
  if NilPtr(result, ecNotEnoughMemory) then
    exit;
  if len = 0 then begin
    result[0] := #0;
    ReadPChar := result;
  end
  else
    Read(result, len);
  ReadPChar := result;
end;

function TStream.ReadString: string;
var
  len: byte;
  result: string;
begin
  result := '';
  len := ReadByte;
  if HasException then
    exit;
  Read(@result[1], len);
  if HasException then
    exit;
  result[0] := Chr(len);
  ReadString := result;
end;

procedure TStream.WriteString(const AString: string);
begin
  Write(@AString, Length(AString) + 1);
end;

procedure TStream.WriteInteger(AValue: integer);
begin
  Write(@AValue, SizeOf(integer));
end;

procedure TStream.WriteWord(AValue: word);
begin
  Write(@AValue, SizeOf(word));
end;

procedure TStream.WriteLong(AValue: longint);
begin
  Write(@AValue, SizeOf(longint));
end;

procedure TStream.WriteDouble(AValue: double);
begin
  Write(@AValue, SizeOf(double));
end;

procedure TStream.WriteReal(AValue: real);
begin
  Write(@AValue, SizeOf(real));
end;

procedure TStream.WriteBool(AValue: boolean);
begin
  Write(@AValue, SizeOf(boolean));
end;

constructor TMemoryStream.Create(ASize: longint);
begin
  inherited Create;
  SetSize(ASize);
end;

constructor TMemoryStream.CreateBuffer(ABuffer: pointer; ASize: word);
var
  reference: PReference;
begin
  inherited Create;
  reference := Memory.CreateReference(ABuffer, ASize);
  Size :=  ASize;
  if not Assigned(reference) then begin
    Raise(Memory.Exception^.Code);
    exit;
  end;
  FReferences^.Add(reference);
  Size := ASize;
end;

procedure TMemoryStream.SetSize(ASize: longint);
var
  reference: PReference;
  remaining: longint;
  refSize: longint;
begin
  DeallocateReferences;
  Memory.BeginAllocTransaction;
  remaining := ASize;
  while remaining > 0 do begin
    refSize := MinL(remaining, MaxVarSize);
    reference := Memory.Alloc(refSize);
    if Memory.HasException then begin
      Raise(Memory.Exception^.Code);
      Memory.ClearException;
      Memory.RollbackAllocTransaction;
      FReferences^.Clear;
      exit;
    end;
    FReferences^.Add(reference);
    Dec(remaining, refSize);
  end;
  Size := ASize;
  Memory.CommitAllocTransaction;
  Fill(Size, 0);
  Position := 0;
end;

procedure TMemoryStream.DeallocateReferences;
var
  index: integer;
  reference: PReference;
begin
  for index := FReferences^.Count - 1 downto 0 do begin
    reference := FReferences^.GetItem(index);
    if FreeBuffers then
      Memory.DeAlloc(reference)
    else begin
      Memory.FreeReferencePreserve(reference);
    end;
  end;
  Size := 0;
  Position := 0;
end;

function TMemoryStream.BufferPointer: pointer;
begin
  BufferPointer := Memory.ReferencePointer(FReferences^.First);
end;

destructor TMemoryStream.Free;
begin
  DeallocateReferences;
  FreeAndNil(FReferences);
  inherited Free;
end;

function TMemoryStream.Read(ABuffer: pointer; ACount: longint): longint;
var
  bytesRead: longint;
  index: integer;
  offset: longint;
  reference: PReference;
  readSize: longint;
  ptr: PByte;
  buffer: PByte;
begin
  if HasException then
    exit;
  buffer := PByte(ABuffer);
  Read := 0;
  bytesRead := 0;
  while bytesRead < ACount do begin
    index := Position div MaxVarSize;
    if index = -1 then
      break;
    offset := Position mod MaxVarSize;
    reference := FReferences^.GetItem(index);
    readSize := MinL(reference^.Size - offset, ACount - bytesRead);
    if readSize <= 0 then
      break;
    ptr := Memory.ReferencePointer(reference);
    Inc(ptr, offset);
    Move(ptr^, buffer^, readSize);
    Inc(buffer, readSize);
    Inc(bytesRead, readSize);
    Inc(Position, readSize);
  end;
  Read := bytesRead;
end;

function TMemoryStream.Fill(ACount: longint; AByte: byte): longint;
var
  index: integer;
  written: longint;
  reference: PReference;
  offset: longint;
  writeSize: word;
  aptr: PByte;
begin
  if HasException then
    exit;
  Fill := 0;
  written := 0;
  while written < ACount do begin
    index := Position div MaxVarSize;
    if index > FReferences^.Count - 1 then
      break;
    offset := Position mod MaxVarSize;
    reference := FReferences^.GetItem(index);
    writeSize := MinL(reference^.Size - offset, ACount - written);
    if writeSize < SizeOf(byte) then
      break;
    aptr := Memory.ReferencePointer(reference);
    Inc(aptr, offset);
    asm
      les di, aptr
      mov al, AByte
      mov cx, writeSize
      cld
      rep stosb
    end;
    Inc(written, writeSize);
    Inc(Position, writeSize);
  end;
  Fill := written;
end;

function TMemoryStream.FillWord(ACount: longint; AWord: word): longint;
var
  index: integer;
  written: longint;
  reference: PReference;
  offset: longint;
  writeSize: word;
  aptr: PWord;
  count: word;
begin
  if HasException then
    exit;
  FillWord := 0;
  written := 0;
  while written < ACount do begin
    index := Position div MaxVarSize;
    if index > FReferences^.Count - 1 then
      break;
    offset := Position mod MaxVarSize;
    reference := FReferences^.GetItem(index);
    writeSize := MinL(reference^.Size - offset, ACount - written);
    if writeSize < SizeOf(word) then
      break;
    count := writeSize div SizeOf(word);
    aptr := Memory.ReferencePointer(reference);
    Inc(aptr, offset);
    asm
      les di, aptr
      mov ax, AWord
      mov cx, count
      cld
      rep stosw
    end;
    Inc(written, writeSize);
    Inc(Position, writeSize);
  end;
  FillWord := written;
end;

function TMemoryStream.FillLong(ACount: longint; ALong: longint): longint;
var
  index: word;
  written: longint;
  reference: PReference;
  offset: longint;
  writeSize: word;
  aptr: PLongint;
  count: word;
begin
  if HasException then
    exit;
  FillLong := 0;
  written := 0;
  while written < ACount do begin
    index := Position div MaxVarSize;
    if index > FReferences^.Count - 1 then
      break;
    offset := Position mod MaxVarSize;
    reference := FReferences^.GetItem(index);
    writeSize := MinL(reference^.Size - offset, ACount - written);
    if writeSize < SizeOf(longint) then
      break;
    count := writeSize div SizeOf(longint);
    aptr := Memory.ReferencePointer(reference);
    Inc(aptr, offset);
    for index := 0 to count - 1 do begin
      aptr^ := ALong;
      Inc(aptr);
    end;
    Inc(written, writeSize);
    Inc(Position, writeSize);
  end;
  FillLong := written;
end;

function TMemoryStream.Write(ABuffer: pointer; ACount: longint): longint;
var
  index: integer;
  written: longint;
  reference: PReference;
  offset: longint;
  writeSize: longint;
  ptr: PByte;
  buffer: PByte;
begin
  if HasException then
    exit;
  buffer := PByte(ABuffer);
  Write := 0;
  written := 0;
  while written < ACount do begin
    index := Position div MaxVarSize;
    if index > FReferences^.Count - 1  then
      break;
    offset := Position mod MaxVarSize;
    reference := FReferences^.GetItem(index);
    writeSize := MinL(reference^.Size - offset, ACount - written);
    if writeSize <= 0 then
      break;
    ptr := Memory.ReferencePointer(reference);
    Inc(ptr, offset);
    Move(buffer^, ptr^, writeSize);
    Inc(buffer, writeSize);
    Inc(written, writeSize);
    Inc(Position, writeSize);
  end;
  Write := written;
end;

function TMemoryStream.WriteToStream(AStream: PStream; ACount: longint): longint;
var
  index: integer;
  refWritten: word;
  bytesWritten, total: longint;
  reference: PReference;
  offset: longint;
  writeSize: longint;
  ptr, destPtr: PByte;
begin
  if HasException then
    exit;
  WriteToStream := 0;
  total := 0;
  while total < ACount do begin
    index := Position div MaxVarSize;
    if index > FReferences^.Count - 1 then
      break;
    offset := Position mod MaxVarSize;
    reference := FReferences^.GetItem(index);
    writeSize := MinL(reference^.Size - offset, ACount - total);
    if writeSize <= 0 then
      break;
    ptr := Memory.ReferencePointer(reference);
    Inc(ptr, offset);
    bytesWritten := AStream^.Write(ptr, writeSize);
    if bytesWritten = 0 then
      exit;
    Inc(total, bytesWritten);
    Inc(Position, bytesWritten);
  end;
  WriteToStream := total;
end;

procedure TMemoryStream.Init;
begin
  inherited Init;
  FReferences := New(PReferenceList, Create);
  FreeBuffers := true;
end;

function TMemoryStream.CanRead: boolean;
begin
  CanRead := true;
end;

function TMemoryStream.CanWrite: boolean;
begin
  CanWrite := true;
end;

function TMemoryStream.CanSeek: boolean;
begin
  CanSeek := true;
end;

constructor TBufferStream.Create;
begin
  CreateCapacity(DefaultyBufferStreamCapacity);
end;

constructor TBufferStream.CreateCapacity(ACapacity: longint);
begin
  inherited Create(ACapacity);
end;

procedure TBufferStream.Init;
begin
  inherited Init;
  BufferStreamSizeFunc := @DefaultBufferStreamSizeFunc;
end;

function TBufferStream.Write(ABuffer: pointer; ACount: longint): longint;
begin
  if HasException then
    exit;
  if Position + ACount > Size then
    Resize(Position + ACount);
  Write := inherited Write(ABuffer, ACount);
end;

function TBufferStream.WriteToStream(AStream: PStream; ACount: longint): longint;
begin
  if HasException then
    exit;
  if Position + ACount > Size then
    Resize(Position + ACount);
  WriteToStream := inherited WriteToStream(AStream, ACount);
end;

procedure TBufferStream.Resize(AMinCapacity: longint);
var
  newCapacity: longint;
  reference, last: PReference;
  newSize, lastSize, refIndex: word;
  ptr, lastPtr: PByte;
  initial: boolean;
begin
  newCapacity := TBufferStreamSizeFunc(BufferStreamSizeFunc)(AMinCapacity);
  if newCapacity = Size then
    exit;
  if FReferences^.Count = 0 then begin
    SetSize(newCapacity);
    exit;
  end;
  if newCapacity > Size then begin
    last := FReferences^.Last;
    lastSize := last^.Size;
    lastPtr := Memory.ReferencePointer(last);
    Memory.FreeReferencePreserve(last);
    while newCapacity > 0 do begin
      newSize := MinL(newCapacity, MaxVarSize);
      reference := Memory.Alloc(newSize);
      if CheckReRaise(@Memory) then
        exit;
      if initial then begin
        if LastSize > newSize then begin
          Raise(ecNotEnoughMemory);
          exit;
        end;
        ptr := Memory.ReferencePointer(reference);
        Move(lastPtr^, ptr^, lastSize);
        initial := false;
      end;
      Dec(newCapacity, lastSize);
    end;
  end
  else begin
    SetSize(newCapacity);
  end;
  Size := newCapacity;
  if Position > Size then
    Position := Size;
end;

destructor TBufferStream.Free;
begin
  inherited Free;
end;

procedure TBufferStream.SetCapacity(ACapacity: longint);
var
  newCapacity: longint;
begin
  newCapacity := TBufferStreamSizeFunc(BufferStreamSizeFunc)(ACapacity);
end;

constructor TFileStream.Create(AFilename: string; AMode: TFileStreamMode);
begin
  CreateBufferSize(AFilename, AMode, DefaultFileStreamBufferSize);
end;

constructor TFileStream.CreateBufferSize(AFilename: string; AMode: TFileStreamMode; ABufferSize: word);
begin
  FMode := AMode;
  FFilename := AFilename;
  BufferSize := ABufferSize;
  Init;
end;

procedure TFileStream.Init;
begin
  inherited init;
  BufferSize := DefaultFileStreamBufferSize;
  FOpen := false;
  Open;
end;

destructor TFileStream.Done;
begin
  Close;
end;

function TFileStream.Read(ABuffer: pointer; ACount: longint): longint;
var
  bytesRead: word;
  total: longint;
  buffer: PByte;
begin
  Read := 0;
  buffer := PByte(ABuffer);
  if (ACount <= 0) or not CheckRead then
    exit;
  total := 0;
  while total < ACount do begin
    {$I-}
    if Eof(FFile) then
      break;
    BlockRead(FFile, buffer^, MinL(ACount - total, BufferSize), bytesRead);
    {$I+}
    if IOResult <> 0 then begin
      Raise(ecStreamReadError);
      exit;
    end;
    if bytesRead = 0 then
      break;
    Inc(buffer, bytesRead);
    Inc(total, bytesRead);
    Inc(Position, bytesRead);
  end;
  Read := total;
end;

function TFileStream.Write(ABuffer: pointer; ACount: longint): longint;
var
  bytesWritten: word;
  total: longint;
  buffer: PByte;
begin
  Write := 0;
  buffer := PByte(ABuffer);
  if (ACount <= 0) or not CheckWrite then
    exit;
  total := 0;
  while total < ACount do begin
    Seek(Position, soFromBeginning);
    {$I-}
    BlockWrite(FFile, buffer^, MinL(ACount - total, BufferSize), bytesWritten);
    {$I+}
    if IOResult <> 0 then begin
      Raise(ecStreamReadError);
      exit;
    end;
    if bytesWritten = 0 then
      break;

    if Position + bytesWritten >= Size then
      Size := Position + bytesWritten;
    Inc(buffer, bytesWritten);
    Inc(total, bytesWritten);
    Inc(Position, bytesWritten);
  end;
  Write := total;
end;

function TFileStream.WriteToStream(AStream: PStream; ACount: longint): longint;
var
  bytesWritten, bytesRead: word;
  buffer: PByte;
  total: longint;
begin
  WriteToStream := 0;
  if (ACount <= 0) or (not CheckRead) then
    exit;
  total := 0;
  GetMem(buffer, BufferSize);
  while total < ACount do begin
    {$I-}
    Seek(Position, soFromBeginning);
    bytesRead := Read(buffer, BufferSize);
    if bytesRead = 0 then
      break;
    {$I+}
    if IOResult <> 0 then begin
      Raise(ecStreamReadError);
      break;
    end;
    bytesWritten := AStream^.Write(buffer, bytesRead);
    if AStream^.HasException then begin
      Raise(AStream^.Exception^.Code);
      break;
    end;
    if bytesWritten = 0 then
      break;
    Inc(total, bytesWritten);
  end;
  FreeMem(buffer, BufferSize);
  WriteToStream := total;
end;

function TFileStream.CanRead: boolean;
begin
  CanRead := NoException and ((FMode = fmRead) or (FMode = fmReadWrite));
end;

function TFileStream.CanWrite: boolean;
begin
  CanWrite := NoException and
  ((FMode = fmWrite) or (FMode = fmReadWrite) or (FMode = fmCreate));
end;

function TFileStream.CanSeek: boolean;
begin
  CanSeek := true;
end;

function TFileStream.Seek(AOffset: longint; AOrigin: TSeekOrigin): longint;
begin
  inherited Seek(AOffset, AOrigin);
  if HasException then
    exit;
  {$I-}
  System.Seek(FFile, Position);
  if (IOResult <> 0) then
    Raise(ecStreamSeekError);
  {$I+}
end;

procedure TFileStream.Open;
begin
  if FOpen then
     exit;
  FOpen := true;
  {$I-}
  if FileExists(FFilename) then begin
    System.Assign(FFile, FFilename);
    case FMode of
      fmRead, fmReadWrite, fmWrite: begin
        Reset(FFile, 1);
        Size := FileSize(FFile);
      end;
      fmCreate: begin
        Rewrite(FFile, 1);
        Size := 0;
      end;
    end;
  end
  else begin
    Size := 0;
    System.Assign(FFile, FFilename);
    case FMode of
      fmRead, fmReadWrite: Raise(ecFileNotFound);
      fmWrite, fmCreate: Rewrite(FFile, 1);
    end;
  end;
  if IOResult <> 0 then
    Raise(ecStreamWriteError);
  {$I+}

  if HasException then
    FOpen := false;
end;

procedure TFileStream.Close;
begin
  {$I-}
  if FOpen then
    System.Close(FFile);
  if IOResult <> 0 then
    Raise(ecStreamCloseError);
  {$I+}
end;

function TFileStream.CheckRead: boolean;
begin
  CheckRead := true;
  if not CanRead then begin
    Raise(ecStreamReadNotSupported);
    CheckRead := false;
  end;
end;

function TFileStream.CheckWrite: boolean;
begin
  CheckWrite := true;
  if not CanWrite then begin
    Raise(ecStreamWriteNotSupported);
    CheckWrite := false;
  end;
end;

procedure TStreamList.Init;
begin
  inherited Init;
end;

function TStreamList.Add(AItem: PStream): integer;
begin
  Add := inherited Add(AItem);
end;

function TStreamList.GetItem(AIndex: integer): PStream;
begin
  GetItem := PStream(inherited GetItem(AIndex));
end;

function TStreamList.IndexOf(AItem: PStream): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TStreamList.SetItem(AIndex: integer; AItem: PStream);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TStreamList.Insert(AIndex: integer; AItem: PStream);
begin
  inherited Insert(AIndex, AItem);
end;

procedure TStreamList.Delete(AIndex: integer);
begin
  inherited Delete(AIndex);
end;

procedure TMemoryStreamList.Init;
begin
  inherited Init;
end;

function TMemoryStreamList.Add(AItem: PMemoryStream): integer;
begin
  Add := inherited Add(AItem);
end;

function TMemoryStreamList.GetItem(AIndex: integer): PMemoryStream;
begin
  GetItem := PMemoryStream(inherited GetItem(AIndex));
end;

function TMemoryStreamList.IndexOf(AItem: PMemoryStream): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TMemoryStreamList.SetItem(AIndex: integer; AItem: PMemoryStream);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TMemoryStreamList.Insert(AIndex: integer; AItem: PMemoryStream);
begin
  inherited Insert(AIndex, AItem);
end;

procedure TMemoryStreamList.Delete(AIndex: integer);
begin
  inherited Delete(AIndex);
end;

function TPersistent.IsPersistent: boolean;
begin
  IsPersistent := true;
end;

procedure TPersistent.LoadFromFile(const AFileName: string);
var
  stream: PFileStream;
begin
  stream := New(PFileStream, Create(AFileName, fmRead));
  if not CheckReRaise(stream) then
    LoadFromStream(stream);
  CheckReRaise(stream);
  FreeAndNil(stream);
end;

procedure TPersistent.LoadFromStream(AStream: PStream);
begin
  Abstract;
end;

procedure TPersistent.SaveToFile(const AFileName: string);
var
  stream: PFileStream;
begin
  stream := New(PFileStream, Create(AFileName, fmCreate));
  if not CheckReRaise(stream) then
    SaveToStream(stream);
  CheckReRaise(stream);
  FreeAndNil(stream);
end;

procedure TPersistent.SaveToStream(AStream: PStream);
begin
  Abstract;
end;

begin
end.