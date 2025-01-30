{$I COMPILER.INC}
unit AplUtils;

interface

uses
  Dos,
  AplTypes,
  AplObj;

const
  HexDigits: String[16] = '0123456789ABCDEF';

function Trim(AString: string): string;
function IntToStr(ANum: longint): string;
function IntToHex(ANum: longint): THexString;
function IntToBool(ANum: longint): boolean;
function StrToLong(const AString: string; ADefault: longint): longint;
function StrToShort(const AString: string; ADefault: shortint): shortint;
function StrToByte(const AString: string; ADefault: byte): byte;
function StrToWord(const AString: string; ADefault: word): word;
function StrToInt(const AString: string; ADefault: integer): integer;
function IncludeBackSlash(const AString: string): string;
function ExcludeBackSlash(const AString: string): string;
function DoubleToStr(ADouble: double; ADigits: byte): string;
function BoolToStr(ABool: boolean): string;
function BoolToYN(ABool: boolean): string;
function BoolToYesNo(ABool: boolean): string;
function BoolToInt(ABool: boolean): byte;
function BoolToIntStr(ABool: boolean): string;
function FileExists(const AFilename: string): boolean;
function DirectoryExists(const ADir: string): boolean;
function GetExtension(const AFilename: string): string;
function UpperCase(const AString: string): string;
function LowCase(const AChar: char): char;
function FirstUpper(const AString: string): string;
function LowerCase(const AString: string): string;
function ExtractDirectory(const AFilename: string): string;
function ExtractFilename(const AFilename: string): string;
function ExtractFullName(const AFilename: string): string;
function ExtractExtension(const AFilename: string): string;
function Equal(var AVar1, AVar2; ASize: word): boolean;
function Replace(const AString, APattern, AReplacePattern: string): string;
function ZeroPad(AInt: longint; ALength: byte): string;
function LeftPad(AString: string; ALength: byte; AChar: char): string;
function RightPad(AString: string; ALength: byte; AChar: char): string;
function EndZeroPad(AInt: longint; ALength: byte): string;
function FormatLong(ALong: longint): string;
function StartsWith(const AString, AStartsWith: string): boolean;
function EndsWith(const AString, AEndsWith: string): boolean;
function GetCurrentDirectory: string;
function ChangeDirectory(const ADirectory: string): boolean;
function StringsEqualInsensitive(const AString1, AString2: string): boolean;
function HasWildcard(const AFilename: string): boolean;
function IsDirectory(const AFilename: string): boolean;
function IsWhitespace(const AString: string): boolean;
function AppDir: string;
function IsAlphaString(const AString: string): boolean;
function IsAlpha(AString: PChar): boolean;
function IsAlphaNumeric(AString: PChar): boolean;
function IsAlphaNumericString(const AString: string): boolean;
function IsNumericString(const AString: string): boolean;
function IsNumeric(AString: PChar): boolean;
function CharUpCase(AChar: char): char;
function CharLowCase(AChar: char): char;
function StringCompare(const AString1, AString2: string): integer;
function StringCompareInsensitive(const AString1, AString2: string): integer;
procedure Swap(var ANum1: integer; var ANum2: integer);
procedure SwapShort(var ANum1: shortint; var ANum2: shortint);
procedure SwapByte(var ANum1: byte; var ANum2: byte);
procedure SwapWord(var ANum1: word; var ANum2: word);
procedure SwapLong(var ANum1: longint; var ANum2: longint);
procedure SwapPointer(var APointer1: pointer; var APointer2: pointer);
procedure FillCharLarge(var APtr; ACount: longint; AValue: byte);
procedure Delete(var AString: string; AStart, ACount: integer);
procedure DeletePChar(var AString: PChar; AStart, ACount: integer);

implementation

uses
  AplConst,
  AplMath,
  Strings,
  Files;

var
  PreviousExitProc: PProc;
  LastDir: string;

procedure FillCharLarge(var APtr; ACount: longint; AValue: byte);
var
  ptr: PByte;
  bytes: longint;
begin
  ptr := @APtr;
  while ACount > 0 do begin
    bytes := MinL(ACount, MaxVarSize);
    FillChar(ptr^, bytes, AValue);
    Inc(ptr, bytes);
    Dec(ACount, bytes);
  end;
end;

function StartsWith(const AString, AStartsWith: string): boolean;
begin
  StartsWith := LowerCase(Copy(AString, 1, Length(AStartsWith))) = LowerCase(AStartsWith);
end;

function EndsWith(const AString, AEndsWith: string): boolean;
begin
  EndsWith := LowerCase(Copy(AString, Length(AString) - Length(AEndsWith) + 1, Length(AEndsWith))) = LowerCase(AEndsWith);
end;

function Trim(AString: string): string;
var
  result: string;
  index: integer;
begin
  result := '';
  index := 1;
  while (index <= Length(AString)) and (AString[index] in WhiteSpaceChars) do
    Inc(index);
  result := Copy(AString, index, Length(AString) - index + 1);
  index := Length(result);
  while (index >= 1) and (result[index] in WhiteSpaceChars) do
    Dec(index);
  result := Copy(result, 1, index);
  Trim := result;
end;

function Equal(var AVar1, AVar2; ASize: word): boolean;
var
  index: integer;
  byte1, byte2: PByte;
begin
  byte1 := @AVar1;
  byte2 := @AVar2;
  Equal := true;
  if (ASize <= 0) then exit;
  for index := 0 to ASize - 1 do begin
    if (byte1^ <> byte2^) then begin
      Equal := false;
      exit;
    end;
    Inc(byte1);
    Inc(byte2);
  end;
end;

procedure Swap(var ANum1: integer; var ANum2: integer);
var
  temp: integer;
begin
  temp := ANum1;
  ANum1 := ANum2;
  ANum2 := temp;
end;

procedure SwapShort(var ANum1: shortint; var ANum2: shortint);
var
  temp: shortint;
begin
  temp := ANum1;
  ANum1 := ANum2;
  ANum2 := temp;
end;

procedure SwapByte(var ANum1: byte; var ANum2: byte);
var
  temp: byte;
begin
  temp := ANum1;
  ANum1 := ANum2;
  ANum2 := temp;
end;

procedure SwapWord(var ANum1: word; var ANum2: word);
var
  temp: word;
begin
  temp := ANum1;
  ANum1 := ANum2;
  ANum2 := temp;
end;

procedure SwapLong(var ANum1: longint; var ANum2: longint);
var
  temp: longint;
begin
  temp := ANum1;
  ANum1 := ANum2;
  ANum2 := temp;
end;

procedure SwapPointer(var APointer1: pointer; var APointer2: pointer);
var
  temp: pointer;
begin
  temp := APointer1;
  APointer1 := APointer2;
  APointer2 := temp;
end;

function GetExtension(const AFilename: string): string;
var
  dotPos: integer;
  index: integer;
begin
  dotPos := -1;
  for index := length(AFilename) downto 1 do begin
    if AFilename[index] = '.' then begin
      dotPos := index;
      break;
    end;
  end;
  if (dotPos < 0) then
    GetExtension := ''
  else
    GetExtension := Copy(AFilename, dotPos, Length(AFilename) - dotPos + 1);
end;

function LowCase(const AChar: char): char;
begin
  if (ord(AChar) < 65) or (ord(AChar) > 90) then
    LowCase := AChar
  else
    LowCase := Chr(Ord(AChar) + 32);
end;

function LowerCase(const AString: string): string;
var
  index: integer;
  result: string;
begin
  result := AString;
  for index := 1 to Length(AString) do
    result[index] := CharLowCase(result[index]);
  LowerCase := result;
end;

function UpperCase(const AString: string): string;
var
  index: integer;
  result: string;
begin
  result := AString;
  for index := 1 to Length(AString) do
    result[index] := CharUpCase(result[index]);
  UpperCase := result;
end;

function FirstUpper(const AString: string): string;
var
  result: string;
begin
  result := LowerCase(AString);
  if Length(result) > 1 then
    result[1] := CharUpCase(result[1]);
  FirstUpper := result;
end;

function IntToStr(ANum: longint): string;
var
  result: string;
begin
  Str(ANum, result);
  IntToStr := result;
end;

function DoubleToStr(ADouble: double; ADigits: byte): string;
var
  result: string;
begin
  Str(ADouble:10:ADigits, result);
  DoubleToStr := Trim(result);
end;

function BoolToStr(ABool: boolean): string;
begin
  if ABool then
    BoolToStr := 'true'
  else
    BoolToStr := 'false';
end;

function BoolToYN(ABool: boolean): string;
begin
  if ABool then
    BoolToYN := 'Y'
  else
    BoolToYN := 'N';
end;

function BoolToYesNo(ABool: boolean): string;
begin
  if ABool then
    BoolToYesNo := 'Yes'
  else
    BoolToYesNo := 'No';
end;

function BoolToInt(ABool: boolean): byte;
begin
  if ABool then
    BoolToInt := 1
  else
    BoolToInt := 0;
end;

function BoolToIntStr(ABool: boolean): string;
begin
  if ABool then
    BoolToIntStr := '1'
  else
    BoolToIntStr := '0';
end;

function IntToBool(ANum: longint): boolean;
begin
  if ANum <> 0 then
    IntToBool := true
  else
    IntToBool := false;
end;

function IntToHex(ANum: longint): THexString;
var
  digit, numPos: byte;
  result: THexString;
  width: byte;
begin
  FillChar(result, SizeOf(result), ord('0'));
  result[1] := '0';
  result[2] := 'x';
  if (ANum > High(word)) then
    width := 8
  else if (ANum > High(byte)) then
    width := 4
  else
    width := 2;
  result[0] := chr(width + 2);
  numPos := width + 2;
  while (ANum > 0) do begin
    result[numPos] := HexDigits[ANum mod 16 + 1];
    Dec(numPos);
    ANum := ANum div 16;
  end;
  IntToHex := result;
end;

function ExtractDirectory(const AFilename: string): string;
var
  dir, name, ext: string;
begin
  FSplit(AFilename, dir, name, ext);
  ExtractDirectory := dir;
end;

function ExtractExtension(const AFilename: string): string;
var
  dir, name, ext: string;
begin
  FSplit(AFilename, dir, name, ext);
  ExtractExtension := ext;
end;

function ExtractFilename(const AFilename: string): string;
var
  dir, name, ext: string;
begin
  FSplit(AFilename, dir, name, ext);
  name := name;
  ExtractFilename := name;
end;

function ExtractFullName(const AFilename: string): string;
var
  dir, name, ext: string;
begin
  FSplit(AFilename, dir, name, ext);
  name := name + ext;
  ExtractFullName := name;
end;

function GetCurrentDirectory: string;
var
  result: string;
begin
  GetDir(0, result);
  result := FExpand(result);
  GetCurrentDirectory := result;
end;

function ChangeDirectory(const ADirectory: string): boolean;
var
  result: integer;
begin
  ChangeDirectory := false;
  {$I-}
  ChDir(ADirectory);
  result := IOResult;
  if result = 0 then
    ChangeDirectory := true;
  {$I+}
end;

function Replace(const AString, APattern, AReplacePattern: string): string;
var
  index, patternIndex, currentIndex: integer;
  result: string;
  stringLength: integer;
  patternLength: integer;
  patternString: string;
  aChar: char;
begin
  index := 1;
  stringLength := Length(AString);
  patternLength := Length(APattern);
  result := '';
  while index <= stringLength do begin
    patternString := '';
    currentIndex := index;
    for patternIndex := 1 to patternLength do begin
      aChar := AString[currentIndex];
      if (index + patternIndex - 1 > stringLength)
        or (APattern[patternIndex] <> aChar) then
        break;
      patternString := patternString + aChar;
      Inc(CurrentIndex);
    end;
    if Length(patternString) = patternLength then begin
      result := result + AReplacePattern;
      Inc(index, patternLength);
      continue;
    end;
    result := result + AString[index];
    Inc(index);
  end;
  Replace := result;
end;

function ZeroPad(aInt: longint; aLength: byte): string;
var
  result: string;
begin
  result := IntToStr(aInt);
  while Length(result) < aLength do
    result := '0' + result;
  ZeroPad := result;
end;

function EndZeroPad(aInt: longint; aLength: byte): string;
var
  result: string;
begin
  result := IntToStr(aInt);
  while Length(result) < aLength do
    result := result + '0';
  EndZeroPad := result;
end;

function FormatLong(ALong: longint): string;
var
  result: string;
begin
  result := '';
  while true do begin
    if aLong div 1000 = 0 then begin
      result := IntToStr(aLong mod 1000) + result;
      break;
    end;
    result := numberSeparator + ZeroPad(aLong mod 1000, 3) + result;
    aLong := aLong div 1000;
  end;
  FormatLong := result;
end;

function FileExists(const AFilename: string): boolean;
var
  tempFile: file;
  attributes: word;
  error: integer;
begin
  Assign(tempFile, AFilename);
  GetFAttr(tempFile, attributes);
  error := DosError;
  if (error = 0) and not (faDirectory in TFileAttributes(byte(attributes))) then
    FileExists := true
  else
    FileExists := false;
end;

function DirectoryExists(const ADir: string): boolean;
var
  tempFile: file;
  attributes: word;
  error: integer;
begin
  Assign(tempFile, ADir);
  GetFAttr(tempFile, attributes);
  error := DosError;
  if (error = 0) and (faDirectory in TFileAttributes(byte(attributes))) then
    DirectoryExists := true
  else
    DirectoryExists := false;
end;


function IncludeBackslash(const AString: string): string;
begin
  if not EndsWith(AString, '\') then
    IncludeBackslash := AString + '\'
  else
    IncludeBackslash := AString;
end;

function ExcludeBackSlash(const AString: string): string;
begin
  if EndsWith(AString, '\') then
    ExcludeBackslash := Copy(AString, 1, Length(AString) - 1)
  else
    ExcludeBackslash := AString;
end;

function StringsEqualInsensitive(const AString1, AString2: string): boolean;
begin
  StringsEqualInsensitive := UpperCase(Trim(AString1)) = UpperCase(Trim(AString2));
end;

function IsValidFilename(const AFilename: string; AValidChars: TCharSet): boolean;
var
  charPos: byte;
  result: boolean;
  index: integer;
  dir: string;
  name: string;
  ext: string;
begin
  result := true;
  for index := 1 to Length(AFilename) do begin
    if not (AFilename[index] in AValidChars) then begin
      result := false;
      exit;
    end;
  end;
  charPos := Pos(':', AFilename);
  if charPos > 2 then begin
    result := false;
    exit;
  end;
  FSplit(AFilename, dir, name, ext);
  if Length(ext) > 4 then begin
    result := false;
    exit;
  end;
  if Length(name) > 8 then begin
    result := false;
    exit;
  end;
end;

function IsDirectory(const AFilename: string): boolean;
var
  search: SearchRec;
  error: integer;
begin
  FindFirst(AFilename, byte(faDirectory), search);
  error := DosError;
  if error = 0 then
    IsDirectory := faDirectory in TFileAttributes(search.Attr)
  else
    IsDirectory := false;
end;

function HasWildcard(const AFilename: string): boolean;
var
  charPos: boolean;
  found: boolean;
  dir, name, ext: string;
begin
  FSplit(AFilename, dir, name, ext);
  found :=
    (
      (Pos('*', ext) > 0)
      or (Pos('?', ext) > 0)
      or (Pos('*', name) > 0)
      or (Pos('?', name) > 0)
    )
    and not
    (
      (Pos('*', dir) > 0)
      or (Pos('?', dir) > 0)
    );
  HasWildCard := found;
end;

function LeftPad(AString: string; ALength: byte; AChar: char): string;
var
  result: string;
begin
  result := AString;
  while Length(result) < ALength do
    result := AChar + result;
  LeftPad := result;
end;

function RightPad(AString: string; ALength: byte; AChar: char): string;
var
  result: string;
begin
  result := AString;
  while Length(result) < ALength do
    result := result + AChar;
  RightPad := result;
end;

function StrToLong(const AString: string; ADefault: longint): longint;
var
  result: longint;
  error: integer;
begin
  Val(AString, result, error);
  if error <> 0 then
    result := ADefault;
  StrToLong := result;
end;

function StrToShort(const AString: string; ADefault: shortint): shortint;
var
  result: shortint;
  error: integer;
begin
  Val(AString, result, error);
  if error <> 0 then
    result := ADefault;
  StrToShort := result;
end;

function StrToByte(const AString: string; ADefault: byte): byte;
var
  result: byte;
  error: integer;
begin
  Val(AString, result, error);
  if error <> 0 then
    result := ADefault;
  StrToByte := result;
end;

function StrToWord(const AString: string; ADefault: word): word;
var
  result: word;
  error: integer;
begin
  Val(AString, result, error);
  if error <> 0 then
    result := ADefault;
  StrToWord := result;
end;

function StrToInt(const AString: string; ADefault: integer): integer;
var
  result: integer;
  error: integer;
begin
  Val(AString, result, error);
  if error <> 0 then
    result := ADefault;
  StrToInt := result;
end;

function IsWhitespace(const AString: string): boolean;
var
  index: integer;
begin
  IsWhiteSpace := true;
  for index := 1 to Length(AString) do begin
    if not (AString[index] in WhiteSpaceChars) then begin
      IsWhiteSpace := false;
      exit;
    end;
  end;
end;

function AppDir: string;
begin
  AppDir := ExtractDirectory(ParamStr(0));
end;

procedure Delete(var AString: string; AStart, ACount: integer);
begin
  AString := Copy(AString, 1, AStart - 1)
    + Copy(AString, AStart + ACount, Length(AString) - AStart - ACount + 1);
end;

procedure DeletePChar(var AString: PChar; AStart, ACount: integer);
begin
  Move(AString[AStart + ACount], AString[AStart],
    StrLen(AString) - AStart - ACount + 1);
end;

function IsCharType(AString: PChar; ALength: word; ACharSet: TCharSet): boolean;
var
  ptr: PChar;
  index: word;
begin
  if (not Assigned(AString)) or (ALength = 0) then begin
    IsCharType := false;
    exit;
  end;
  ptr := AString;
  IsCharType := true;
  index := 0;
  while ptr^ <> #0 do begin
    if (index > ALength) or not (ptr^ in ACharSet) then begin
      IsCharType := false;
      exit;
    end;
    Inc(ptr);
  end;
end;

function IsAlpha(AString: PChar): boolean;
begin
  IsAlpha := IsCharType(AString, StrLen(AString), Alpha);
end;

function IsAlphaString(const AString: string): boolean;
begin
  IsAlphaString := IsCharType(@AString[1], Length(AString), Alpha);
end;

function IsAlphaNumeric(AString: PChar): boolean;
begin
  IsAlphaNumeric := IsCharType(AString, StrLen(AString), AlphaNumeric);
end;

function IsAlphaNumericString(const AString: string): boolean;
begin
  IsAlphaNumericString := IsCharType(@AString[1], Length(AString), AlphaNumeric);
end;

function IsNumeric(AString: PChar): boolean;
begin
  IsNumeric := IsCharType(AString, StrLen(AString), Numeric);
end;

function IsNumericString(const AString: string): boolean;
begin
  IsNumericString := IsCharType(@AString[1], Length(AString), Numeric);
end;

function CharUpCase(AChar: char): char;
begin
  if not (AChar in AlphaInternat) then begin
    CharUpCase := AChar;
    exit;
  end;
  if AChar in LowerChars then begin
    AChar := Chr(Ord(AChar) - 32);
  end
  else begin
    case AChar of
      #129: AChar := #154;
      #130: AChar := #144;
      #132: AChar := #142;
      #134: AChar := #143;
      #135: AChar := #128;
      #145: AChar := #146;
      #148: AChar := #153;
      #164: AChar := #165;
    end;
  end;
  CharUpCase := AChar;
end;

function CharLowCase(AChar: char): char;
begin
  if not (AChar in AlphaInternat) then begin
    CharLowCase := AChar;
    exit;
  end;
  if AChar in UpperChars then begin
    AChar := Chr(Ord(AChar) + 32);
  end
  else begin
    case AChar of
      #154: AChar := #129;
      #144: AChar := #130;
      #142: AChar := #132;
      #143: AChar := #134;
      #128: AChar := #135;
      #146: AChar := #145;
      #153: AChar := #148;
      #165: AChar := #164;
    end;
  end;
  CharLowCase := AChar;
end;

function StringCompare(const AString1, AString2: string): integer;
var
  index: integer;
begin
  index := 1;
  while (index <= Length(AString1)) and (index <= Length(AString2)) do begin
    if AString1[index] < AString2[index] then begin
      StringCompare := -1;
      exit;
    end;
    if AString1[index] > AString2[index] then begin
      StringCompare := 1;
      exit;
    end;
    Inc(index);
  end;
  if Length(AString1) < Length(AString2) then
    StringCompare := -1
  else if Length(AString1) > Length(AString2) then
    StringCompare := 1
  else
    StringCompare := 0;
end;

function StringCompareInsensitive(const AString1, AString2: string): integer;
begin
  StringCompareInsensitive := StringCompare(UpperCase(AString1), UpperCase(AString2));
end;

procedure Finalize; far;
begin
  ExitProc := PreviousExitProc;
  ChangeDirectory(LastDir);
end;

begin
 NumberSeparator := ',';
 LastDir := GetCurrentDirectory;
 PreviousExitProc := ExitProc;
 ExitProc := @Finalize;
end.