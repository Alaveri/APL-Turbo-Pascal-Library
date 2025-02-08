{$I COMPILER.INC}
unit AplObj;

interface

uses
  AplConst,
  AplStr,
  Strings;

type
  PObject = ^TObject;
  PException = ^TException;
  PIdentifiable = ^TIdentifiable;
  PStatusObject = ^TStatusObject;
  PStringBuilder = ^TStringBuilder;

  TComparer = function(AItem1, AItem2: pointer): integer;
  TPredicate = function(AItem: pointer; var AValue): boolean;
  TCustomErrorMessageProc = function(AErrorCode: word; var AFound: boolean): string;
  TObjectStatus = integer;
  TExceptionCode = word;

  TExceptionSeverity =
  (
    esNone,
    esHint,
    esWarning,
    esError,
    esFatal
  );

  TObject = object
    constructor Create;
    function IsPersistent: boolean; virtual;
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    procedure AssignTo(var ADest: TObject); virtual;
    procedure Abstract; virtual;
    destructor Free; virtual;
  end;

  TIdentifiable = object(TObject)
  private
  public
    Id: PChar;
    constructor CreateId(AId: string);
    procedure Init; virtual;
    procedure Assign(var ASource: TObject); virtual;
    procedure SetId(const AId: string);
    function GetId: string;
    destructor Free; virtual;
  end;

  TException = object(TObject)
  private
  public
    Code: TExceptionCode;
    Severity: TExceptionSeverity;
    InnerException: PException;
    constructor Create(ACode: TExceptionCode);
    procedure Init; virtual;
    procedure Clear;
    procedure Assign(var ASource: TObject); virtual;
    function Message: string;
    destructor Free; virtual;
  end;

  TStatusObject = object(TIdentifiable)
  private
  public
    Exception: PException;
    Status: TObjectStatus;
    procedure Init; virtual;
    procedure Raise(ACode: TExceptionCode);
    procedure RaiseException(AException: PException);
    procedure RaiseNullParameter(AParam: string);
    procedure RaiseInvalidOperation(AMessage: string);
    procedure RaiseWarning(ACode: TExceptionCode);
    procedure RaiseHint(ACode: TExceptionCode);
    procedure RaiseSeverity(ACode: TExceptionCode; ASeverity: TExceptionSeverity);
    procedure ReRaise(AObject: PStatusObject);
    procedure ClearException;
    procedure Assign(var ASource: TObject); virtual;
    function HasException: boolean;
    function NoException: boolean;
    function GetBaseException: PException;
    function CheckReRaise(AObject: PStatusObject): boolean;
    function NilPtr(APtr: pointer; ACode: TExceptionCode): boolean;
    function NilPtrSeverity(APtr: pointer; ACode: TExceptionCode;
      ASeverity: TExceptionSeverity): boolean;
    function CheckForExceptions(AObject: PStatusObject): boolean;
    destructor Free; virtual;
  end;

  TStringBuilder = object(TStatusObject)
  private
    FBuffer: PChar;
    FLength: word;
    FCapacity: word;
    FInitialCapacity: word;
    procedure SetCapacity(ACapacity: word);
    function Grow(AMin: word): word;
  public
    constructor CreateCapacity(ACapacity: word);
    constructor CreateString(const AString: string);
    destructor Free; virtual;
    procedure Init; virtual;
    function Append(AString: PChar): PStringBuilder;
    function AppendString(const AString: string): PStringBuilder;
    function AppendBuilder(const AStringBuilder: TStringBuilder): PStringBuilder;
    function AppendChar(AChar: char): PStringBuilder;
    function AppendLine(AString: PChar): PStringBuilder;
    function AppendLineString(const AString: string): PStringBuilder;
    function Replace(AOldValue, ANewValue: PChar;
      ACompareOptions: TStringCompareOptions): PStringBuilder;
    function ReplaceString(const AOldValue, ANewValue: string;
      ACompareOptions: TStringCompareOptions): PStringBuilder;
    function Insert(AIndex: word; AString: PChar): PStringBuilder;
    function InsertString(AIndex: word; const AString: string): PStringBuilder;
    function InsertChar(AIndex: word; AChar: char): PStringBuilder;
    function Clear: PStringBuilder;
    function Find(AString: PChar; AStart: word;
      ACompareOptions: TStringCompareOptions; var APos: word): PChar;
    function FindString(const AString: string; AStart: word;
      ACompareOptions: TStringCompareOptions; var APos: word): PChar;
    function ToPChar: PChar;
    function ToString: string;
    function AsPChar: PChar;
    function Length: word;
    function Capacity: word;
  end;

  { Represents a variable of 0 size that can be used as a dummy value for var
    parameters that require a variable where none is needed. }
  TNothing = object
  end;

procedure FreeAndNil(var AObject); far;

var
  OutOfMemoryException: PException;
  Nothing: TNothing;

implementation

uses
  AplTypes;

procedure FreeAndNil(var AObject);
var
  obj: PObject;
  ptr: PPointer;
begin
  obj := PObject(AObject);
  if Assigned(obj) then
    Dispose(obj, Free);
  ptr := @AObject;
  ptr^ := nil;
end;

constructor TObject.Create;
begin
  Init;
end;

procedure TObject.Abstract;
begin
  RunError(211);
end;

procedure TObject.Init;
begin
end;

procedure TObject.Assign(var ASource: TObject);
begin
end;

procedure TObject.AssignTo(var ADest: TObject);
begin
  ADest.Assign(Self);
end;

function TObject.IsPersistent: boolean;
begin
  IsPersistent := false;
end;

destructor TObject.Free;
begin
end;

constructor TIdentifiable.CreateId(AId: string);
begin
  inherited Create;
  Id := TString.New(AId);
end;

procedure TIdentifiable.Init;
begin
  inherited Init;
  Id := nil;
end;

procedure TIdentifiable.Assign(var ASource: TObject);
var
  source: PIdentifiable;
begin
  inherited Assign(ASource);
  source := PIdentifiable(@ASource);
  SetId(source^.GetId);
end;

function TIdentifiable.GetId: string;
begin
  if not Assigned(Id) then
    GetId := ''
  else
    GetId := TString.GetString(Id);
end;

procedure TIdentifiable.SetId(const AId: string);
begin
  TString.AssignString(Id, AId);
end;

destructor TIdentifiable.Free;
begin
  TString.Free(Id);
  inherited Free;
end;

constructor TException.Create(ACode: TExceptionCode);
begin
  inherited Create;
  Code := ACode;
end;

procedure TException.Init;
begin
  inherited Init;
  Code := 0;
  Severity := esError;
  InnerException := nil;
end;

procedure TException.Clear;
begin
  FreeAndNil(InnerException);
  Code := ecNone;
  Severity := esError;
end;

destructor TException.Free;
begin
  Clear;
  inherited Free;
end;

procedure TException.Assign(var ASource: TObject);
var
  source: PException;
begin
  inherited Assign(ASource);
  source := PException(@ASource);
  Clear;
  if Assigned(source^.InnerException) then begin
    InnerException := New(PException, Create(ecNone));
    InnerException^.Assign(source^.InnerException^);
  end;
  Code := source^.Code;
  Severity := source^.Severity;
end;

function TException.Message: string;
begin
  Message := ErrorMessage(Code);
end;

function TStatusObject.GetBaseException: PException;
var
  result: PException;
begin
  GetBaseException := Exception;
  if not Assigned(Exception) then
    exit;
  result := Exception;
  while Assigned(Exception^.InnerException) do
    result := result^.InnerException;
  GetBaseException := result;
end;

function TStatusObject.HasException: boolean;
begin
  HasException := Assigned(Exception);
end;

function TStatusObject.NoException: boolean;
begin
  NoException := not Assigned(Exception);
end;

procedure TStatusObject.Raise(ACode: TExceptionCode);
var
  newException: PException;
  prev: PException;
begin
  newException := New(PException, Create(ACode));
  if not Assigned(newException) then
    newException := OutOfMemoryException;
  if not Assigned(Exception) then begin
    Exception := newException;
    exit;
  end;
  prev := Exception;
  Exception := newException;
  Exception^.InnerException := prev;
  Status := sException;
end;

procedure TStatusObject.RaiseException(AException: PException);
begin
  if not Assigned(AException) then
    exit;
  RaiseSeverity(AException^.Code, AException^.Severity);
end;

procedure TStatusObject.RaiseSeverity(ACode: TExceptionCode; ASeverity: TExceptionSeverity);
begin
  Raise(ACode);
  Exception^.Severity := ASeverity;
end;

function TStatusObject.CheckReRaise(AObject: PStatusObject): boolean;
var
  result: boolean;
begin
  CheckReRaise := false;
  if not Assigned(AObject) then
    exit;
  result := AObject^.HasException;
  if result then
    ReRaise(AObject);
  CheckReRaise := result;
end;

function TStatusObject.CheckForExceptions(AObject: PStatusObject): boolean;
var
  result: boolean;
begin
  result := false;
  if not Assigned(AObject) then begin
    Raise(ecNotEnoughMemory);
    result := true;
  end
  else
  if AObject^.HasException then begin
    ReRaise(AObject);
    result := true;
  end;
  CheckForExceptions := result;
end;

function TStatusObject.NilPtr(APtr: pointer; ACode: TExceptionCode): boolean;
var
  result: boolean;
begin
  result := not Assigned(APtr);
  if result then
    Raise(ACode);
  NilPtr := result;
end;

function TStatusObject.NilPtrSeverity(APtr: pointer; ACode: TExceptionCode;
  ASeverity: TExceptionSeverity): boolean;
var
  result: boolean;
begin
  result := not Assigned(APtr);
  if result then
    RaiseSeverity(ACode, ASeverity);
  NilPtrSeverity := result;
end;

procedure TStatusObject.ReRaise(AObject: PStatusObject);
begin
  if not (Assigned(AObject) and AObject^.HasException) then
    exit;
  RaiseException(AObject^.Exception);
  AObject^.ClearException;
end;

procedure TStatusObject.RaiseWarning(ACode: TExceptionCode);
begin
  RaiseSeverity(ACode, esWarning);
end;

procedure TStatusObject.RaiseHint(ACode: TExceptionCode);
begin
  RaiseSeverity(ACode, esHint);
end;

procedure TStatusObject.ClearException;
begin
  FreeAndNil(Exception);
  Status := sOk;
end;

destructor TStatusObject.Free;
begin
  ClearException;
  inherited Free;
end;

procedure TStatusObject.Assign(var ASource: TObject);
var
  source: PStatusObject;
begin
  inherited Assign(ASource);
  source := PStatusObject(@ASource);
  ClearException;
  Exception := New(PException, Create(ecNone));
  Exception^.Assign(source^.Exception^);
  Status := source^.Status;
end;

procedure TStatusObject.RaiseNullParameter(AParam: string);
begin
  Raise(ecNullParameter);
end;

procedure TStatusObject.RaiseInvalidOperation(AMessage: string);
begin
  Raise(ecInvalidOperation);
end;

procedure TStatusObject.Init;
begin
  inherited Init;
  Exception := nil;
  Status := sOk;
end;

constructor TStringBuilder.CreateCapacity(ACapacity: word);
begin
  inherited Create;
  Grow(ACapacity);
  FInitialCapacity := ACapacity;
end;

constructor TStringBuilder.CreateString(const AString: string);
begin
  inherited Create;
  Grow(System.Length(AString) + 1);
  AppendString(AString);
  FInitialCapacity := FCapacity;
end;

procedure TStringBuilder.Init;
begin
  inherited Init;
  FBuffer := nil;
  FLength := 0;
  FCapacity := 0;
end;

destructor TStringBuilder.Free;
begin
  if Assigned(FBuffer) then
    FreeMem(FBuffer, FCapacity);
  FBuffer := nil;
  inherited Free;
end;

procedure TStringBuilder.SetCapacity(ACapacity: word);
var
  newBuffer: PChar;
begin
  if ACapacity = FCapacity then
    exit;
  if ACapacity = 0 then begin
    if Assigned(FBuffer) then
      FreeMem(FBuffer, FCapacity);
    FBuffer := nil;
    FCapacity := 0;
    exit;
  end;
  if not Assigned(FBuffer) then begin
    GetMem(FBuffer, ACapacity);
    if NilPtr(FBuffer, ecNotEnoughMemory) then
      exit;
    FillChar(FBuffer^, ACapacity, 0);
    FCapacity := ACapacity;
    exit;
  end;
  GetMem(newBuffer, ACapacity);
  FillChar(newBuffer^, ACapacity, 0);
  if NilPtr(newBuffer, ecNotEnoughMemory) then
    exit;
  if ACapacity < FCapacity then
    Move(FBuffer^, newBuffer^, ACapacity)
  else
    Move(FBuffer^, newBuffer^, FCapacity);
  FreeMem(FBuffer, FCapacity);
  FBuffer := newBuffer;
  FCapacity := ACapacity;
end;

function TStringBuilder.Grow(AMin: word): word;
var
  newCapacity: integer;
begin
  newCapacity := 0;
  while newCapacity < AMin do begin
    if newCapacity > 64 then
      newCapacity := (newCapacity * 3) div 2
    else if newCapacity > 8 then
      Inc(newCapacity, 16)
    else
      Inc(newCapacity, 4);
  end;
  SetCapacity(newCapacity);
  Grow := newCapacity;
end;

function TStringBuilder.Append(AString: PChar): PStringBuilder;
var
  len: word;
  cap: word;
begin
  if not Assigned(AString) then
    exit;
  len := StrLen(AString);
  if len = 0 then
    exit;
  cap := FLength + len;
  if cap > FCapacity then
    Grow(cap);
  Move(AString^, FBuffer[FLength], len);
  Inc(FLength, len);
  Append := @Self;
end;

function TStringBuilder.AppendString(const AString: string): PStringBuilder;
var
  len: word;
  cap: word;
  str: PChar;
begin
  len := System.Length(AString);
  if System.Length(AString) = 0 then
    exit;
  cap := FLength + len;
  if cap > FCapacity then
    Grow(cap);
  str := @AString[1];
  Move(str^, FBuffer[FLength], len);
  Inc(FLength, len);
  AppendString := @Self;
end;

function TStringBuilder.AppendBuilder(const AStringBuilder: TStringBuilder): PStringBuilder;
begin
  AppendBuilder := Append(AStringBuilder.FBuffer);
end;

function TStringBuilder.AppendChar(AChar: char): PStringBuilder;
var
  str: array[0..1] of char;
begin
  str[0] := AChar;
  str[1] := #0;
  AppendChar := Append(@str);
end;

function TStringBuilder.AppendLine(AString: PChar): PStringBuilder;
var
  str: array[0..1] of char;
begin
  str := #13#10;
  AppendLine := Append(AString);
  Append(@str);
end;

function TStringBuilder.AppendLineString(const AString: string): PStringBuilder;
begin
  AppendLineString := AppendString(AString);
  AppendChar(#13);
  AppendChar(#10);
end;

function TStringBuilder.Replace(AOldValue, ANewValue: PChar;
  ACompareOptions: TStringCompareOptions): PStringBuilder;
var
  str, ptr: PChar;
  pos, len, oldLen, newLen, diff: word;
begin
  Replace := @Self;
  if not Assigned(AOldValue) then
    exit;
  pos := 0;
  str := Find(AOldValue, pos, ACompareOptions, pos);
  if not Assigned(str) then
    exit;
  newLen := StrLen(ANewValue);
  oldLen := StrLen(AOldValue);
  len := FLength;
  while Assigned(str) do begin
    if newLen > oldLen then begin
      diff := newLen - oldLen;
      Grow(FLength + diff + 1);
      str := FBuffer;
      Inc(str, pos);
      Inc(FLength, diff);
      len := FLength - pos;
      ptr := str;
      Inc(ptr, diff);
      Move(str^, ptr^, len - diff);
    end
    else if newLen < oldLen then begin
      diff := oldLen - newLen;
      Grow(FLength - diff + 1);
      str := FBuffer;
      Inc(str, pos);
      len := FLength - pos;
      ptr := str;
      Inc(ptr, newLen);
      Move(ptr^, str^, len - newLen);
      FillChar(ptr^, diff, 0);
      Dec(FLength, diff);
    end;
    Move(ANewValue^, str^, newLen);
    Inc(str, newLen);
    str := Find(AOldValue, pos, ACompareOptions, pos);
  end;
end;

function TStringBuilder.ReplaceString(const AOldValue, ANewValue: string;
  ACompareOptions: TStringCompareOptions): PStringBuilder;
var
  old, new: PChar;
  oldValue, newValue: string;
begin
  oldValue := AOldValue + #0;
  newValue := ANewValue + #0;
  old := @oldValue[1];
  new := @newValue[1];
  ReplaceString := Replace(old, new, ACompareOptions);
end;

function TStringBuilder.Insert(AIndex: word; AString: PChar): PStringBuilder;
var
  len, cap: word;
  ptr, dest: PChar;
begin
  Insert := @Self;
  if not Assigned(AString) then
    exit;
  len := StrLen(AString);
  if len = 0 then
    exit;
  if AIndex > FLength then
    AIndex := FLength;
  cap := FLength + len;
  if cap > FCapacity then
    Grow(cap);
  ptr := FBuffer;
  Inc(ptr, AIndex);
  dest := ptr;
  Inc(dest, len);
  Move(ptr^, dest^, FLength - AIndex);
  Move(AString^, ptr^, len);
  Inc(FLength, len);
end;

function TStringBuilder.InsertString(AIndex: word; const AString: string): PStringBuilder;
var
  ptr: PChar;
  str: string;
begin
  str := AString + #0;
  ptr := @str[1];
  InsertString := Insert(AIndex, ptr);
end;

function TStringBuilder.InsertChar(AIndex: word; AChar: char): PStringBuilder;
var
  str: array[0..1] of char;
begin
  str[0] := AChar;
  str[1] := #0;
  InsertChar := Insert(AIndex, @str);
end;

function TStringBuilder.Clear: PStringBuilder;
begin
  if FCapacity = FInitialCapacity then
    FillChar(FBuffer^, FCapacity, 0)
  else
    SetCapacity(FInitialCapacity);
  FLength := 0;
  Clear := @Self;
end;

function TStringBuilder.ToPChar: PChar;
var
  str: PChar;
begin
  GetMem(str, FLength + 1);
  FillChar(str^, FLength + 1, 0);
  if NilPtr(str, ecNotEnoughMemory) then
    exit;
  StrLCopy(str, FBuffer, FLength);
  ToPChar := FBuffer;
end;

function TStringBuilder.ToString: string;
begin
  ToString := TString.GetString(FBuffer);
end;

function TStringBuilder.AsPChar: PChar;
begin
  AsPChar := FBuffer;
end;

function TStringBuilder.Length: word;
begin
  Length := FLength;
end;

function TStringBuilder.Capacity: word;
begin
  Capacity := FCapacity;
end;

function TStringBuilder.Find(AString: PChar; AStart: word;
  ACompareOptions: TStringCompareOptions; var APos: word): PChar;
var
  str, bufferPtr, stringPtr: PChar;
  index: word;
begin
  Find := nil;
  APos := 0;
  if not Assigned(AString) then
    exit;
  if AStart >= FLength then
    exit;
  str := nil;
  index := AStart;
  stringPtr := AString;
  for index := AStart to FLength - 1 do begin
    bufferPtr := FBuffer;
    Inc(bufferPtr, index);
    if scIgnoreCase in ACompareOptions then begin
      if StrLIComp(bufferPtr, stringPtr, StrLen(AString)) = 0 then begin
        str := bufferPtr;
        APos := index;
        break;
      end;
    end
    else begin
      if StrLComp(bufferPtr, stringPtr, StrLen(AString)) = 0 then begin
        str := bufferPtr;
        APos := index;
        break;
      end;
    end;
  end;
  if not Assigned(str) then
    exit;
  Find := str;
end;

function TStringBuilder.FindString(const AString: string; AStart: word;
  ACompareOptions: TStringCompareOptions; var APos: word): PChar;
var
  ptr: PChar;
  str: string;
begin
  str := AString + #0;
  ptr := @str[1];
  FindString := Find(ptr, AStart, ACompareOptions, APos);
end;

var
  PreviousExitProc: PProc;

procedure Finalize; far;
begin
  ExitProc := PreviousExitProc;
  FreeAndNil(OutOfMemoryException);
end;

begin
  PreviousExitProc := ExitProc;
  ExitProc := @Finalize;
  OutOfMemoryException := New(PException, Create(ecNotEnoughMemory));
end.