{$I COMPILER.INC}
unit AplConst;

interface

const
  Alpha = ['A'..'Z', 'a'..'z'];
  AlphaInternat = ['a'..'z', 'A'..'Z', #128..#154, #160..#165];
  AlphaNumeric = ['0'..'9', 'A'..'Z', 'a'..'z'];
  AlphaNumericInternat = ['0'..'9', 'a'..'z', 'A'..'Z', #128..#154, #160..#165];
  AlphaNumericSpace = AlphaNumeric + [#32];
  AlphaNumericSpaceInternat = AlphaNumericInternat + [#32];
  InternatUpperChars = [#128, #142..#144, #146, #153..#154, #165];
  InternatLowerChars = [#129, #130, #132, #134, #135, #145, #148, #164];
  UpperCharsInternat = ['A'..'Z'] + InternatUpperChars;
  LowerCharsInternat = ['a'..'z'] + InternatLowerChars;
  UpperChars = ['A'..'Z'];
  LowerChars = ['a'..'z'];
  Numeric = ['0'..'9'];
  Puncuation = ['.', ',', ';', ':', '!', '?', '"', '''', '(', ')', '[', ']',
    '{', '}', '/', '\', '|', '-', '+', '=', '*', '&', '^', '%', '$', '#',
    '@', '~', '`', '<', '>'
  ];
  Hexadecimal = ['0'..'9', 'A'..'F', 'a'..'f'];

type
  PCustomErrorMessageProc = ^TCustomErrorMessageProc;
  PProc = ^TProc;

  TCustomErrorMessageProc = function(AErrorCode: integer; var found: boolean): string;
  TProc = procedure;

  String1 = string[1];
  String2 = string[2];
  String3 = string[3];
  String4 = string[4];
  String5 = string[5];
  String6 = string[6];
  String7 = string[7];
  String8 = string[8];
  String9 = string[9];
  String10 = string[10];
  String11 = string[11];
  String12 = string[12];
  String13 = string[13];
  String14 = string[14];
  String15 = string[15];
  String16 = string[16];
  String17 = string[17];
  String18 = string[18];
  String19 = string[19];
  String20 = string[20];
  String25 = string[25];
  String30 = string[30];
  String35 = string[35];
  String40 = string[40];
  String45 = string[45];
  String50 = string[50];
  String75 = string[75];
  String80 = string[80];
  String85 = string[80];
  String90 = string[80];
  String100 = string[100];

const
  HexDigits: string16 = '0123456789ABCDEF';
  PointerSize: longint = SizeOf(Pointer);
  MaxVarSize = $FFF0;

  ecNone = 0;

  { IO Codes }
  ecFileNotFound = 101;
  ecFileCreateError = 102;
  ecFileOpenError = 103;
  ecFileReadError = 104;
  ecFileWriteError = 105;
  ecFileVersionError = 106;
  ecFileTypeError = 106;
  ecFileInvalid = 107;
  ecMouseError = 108;

  { Graphics errors }
  ecGraphicsNotSupported = 201;
  ecGraphicsDriverError = 202;
  ecGraphicsModeNotFound = 203;
  ecUnsupportedPaletteFormat = 204;
  ecInvalidPalette = 205;

  { Memory errors }
  ecMemoryReferenceNotFound = 301;
  ecInvalidMemoryReference = 302;
  ecNotEnoughMemory = 303;
  ecInvalidAllocSize = 304;
  ecXmsNotInitialized = 305;
  ecXmsNotSupported = 306;
  ecXmsError = 307;

  { Stream errors }
  ecSeekPastStreamEnd = 400;
  ecWritePastStreamEnd = 401;
  ecReadPastStreamEnd = 402;
  ecStreamSeekNotSupported = 403;
  ecStreamWriteNotSupported = 404;
  ecStreamReadNotSupported = 405;
  ecStreamNotOpen = 406;
  ecStreamCloseError = 407;
  ecStreamOpenError = 408;
  ecStreamReadError = 409;
  ecStreamWriteError = 410;
  ecStreamSeekError = 411;
  ecStreamFormatNotSupported = 412;
  ecStreamBufferOverflow = 413;

  { Text errors }
  ecTextDriverNotSupported = 501;
  ecTextDriverError = 502;
  ecTextModeNotFound = 503;

  { Compression errors }
  ecInvalidCompressionSource = 601;
  ecCompressionBitSizeError = 602;
  ecCompressorNotSpecified = 603;
  ecCompressedDataTooLarge = 604;

  { List Errors }
  ecListCapacityOverflow = 701;
  ecIndexOutOfBounds = 702;

  { Image errors }
  ecImageBppNotSupported = 801;
  ecInvalidImage = 802;
  ecImageCompressionNotSupported = 803;
  ecImageVersionNotSupported = 804;
  ecImageTooLarge = 805;

  { Font Errors }
  ecFontVersionNotSupported = 901;
  ecFontCompressionNotSupported = 902;

  { File Errors }
  ecPathNotFound = 1001;
  ecFileAccessDenied = 1003;
  ecFileInvalidHandle = 1004;
  ecFileInvalidEnvironment = 1005;
  ecFileInvalidFormat = 1006;
  ecDirChangeError = 1007;
  ecFileInvalidVersion = 1008;
  ecFileTooLarge = 1009;

  { System errors }
  ecNullParameter = 1101;
  ecInvalidOperation = 1102;
  ecInvalidArgument = 1103;

  { Dictionary errors }
  ecKeyNotFound = 1201;
  ecDuplicateKey = 1202;

  { User defined errors }
  ecUser = 5000;

  { Status codes }
  sOk = 0;
  sHint = 1;
  sWarning = 2;
  sException = 3;
  sFileStatus = 100;
  sUserStatus = 1000;

function ErrorMessage(AErrorCode: word): string; far;

var
  CustomErrorMessageProc: PCustomErrorMessageProc;

implementation

uses
  AplObj,
  AplStr,
  AplUtils,
  Strings,
  Lists;

type
  PError = ^TError;
  PErrorList = ^TErrorList;

  TError = object(TObject)
  private
  public
    ErrorCode: integer;
    ErrorMessage: PChar;
    constructor Create(AErrorCode: word; AErrorMessage: string);
    constructor CreateCode(AErrorCode: word);
    destructor Free; virtual;
    procedure Init; virtual;
    function GetErrorMessage: string;
  end;

  TErrorList = object(TObjectList)
  private
  public
    constructor Create;
    procedure Init; virtual;
    function Add(AItem: PError): integer;
    function GetItem(AIndex: integer): PError;
    function GetErrorByCode(AErrorCode: word): PError;
    function IndexOf(AItem: PError): integer;
    procedure SetItem(AIndex: integer; AItem: PError);
    procedure Insert(AIndex: integer; AItem: PError);
    procedure RemoveItem(AItem: PError);
    procedure AddError(AErrorCode: word; AErrorMessage: string);
  end;

var
  ErrorList: PErrorList;

function ErrorMessage(AErrorCode: word): string;
var
  error: PError;
  found: boolean;
begin
  error := ErrorList^.GetErrorByCode(AErrorCode);
  if Assigned(error) then
    ErrorMessage := error^.GetErrorMessage
  else begin
    if AErrorCode >= ecUser then begin
      if Assigned(CustomErrorMessageProc) then begin
        found := false;
        ErrorMessage := TCustomErrorMessageProc(CustomErrorMessageProc)(AErrorCode, found);
        if found then
          exit;
      end;
    end;
    ErrorMessage := 'Unknown error';
  end;
end;

constructor TError.Create(AErrorCode: word; AErrorMessage: string);
begin
  inherited Create;
  ErrorCode := AErrorCode;
  ErrorMessage := TString.New(AErrorMessage);
end;

constructor TError.CreateCode(AErrorCode: word);
begin
  inherited Create;
  ErrorCode := AErrorCode;
end;

destructor TError.Free;
begin
  TString.Free(ErrorMessage);
  inherited Free;
end;

procedure TError.Init;
begin
  inherited Init;
  ErrorCode := 0;
  ErrorMessage := nil;
end;

function TError.GetErrorMessage: string;
begin
  GetErrorMessage := TString.GetString(ErrorMessage);
end;

function ErrorCodeCompare(AItem1, AItem2: pointer): integer; far;
begin
  ErrorCodeCompare := PError(AItem1)^.ErrorCode - PError(AItem2)^.ErrorCode;
end;

constructor TErrorList.Create;
var
  index: integer;
  item: PError;
begin
  inherited CreateSorted(ErrorCodeCompare);
  AddError(ecImageVersionNotSupported, 'Image version not supported');
  AddError(ecFileNotFound, 'File not found');
  AddError(ecFileCreateError, 'File could not be created');
  AddError(ecFileOpenError, 'File could not be opened');
  AddError(ecFileReadError, 'Error writing file');
  AddError(ecFileWriteError, 'Error writing file');
  AddError(ecFileVersionError, 'File version mismatch');
  AddError(ecFileTypeError, 'File type not supported');
  AddError(ecFileInvalid, 'File is invalid');
  AddError(ecGraphicsNotSupported, 'Graphics type not supported');
  AddError(ecTextDriverNotSupported, 'Text type not supported');
  AddError(ecTextDriverError, 'Text driver error');
  AddError(ecTextModeNotFound, 'Text mode not found');
  AddError(ecMemoryReferenceNotFound, 'Memory reference not found');
  AddError(ecInvalidMemoryReference, 'Invalid memory reference');
  AddError(ecNotEnoughMemory, 'Not enough memory');
  AddError(ecInvalidAllocSize, 'Invalid allocation size');
  AddError(ecGraphicsDriverError, 'Graphics mode not supported');
  AddError(ecStreamSeekNotSupported, 'Stream does not support seeking');
  AddError(ecStreamWriteNotSupported, 'Stream does not support writing');
  AddError(ecStreamReadNotSupported, 'Stream does not support reading');
  AddError(ecSeekPastStreamEnd, 'Seek past end of stream');
  AddError(ecWritePastStreamEnd, 'Write past end of stream');
  AddError(ecReadPastStreamEnd, 'Read past end of stream');
  AddError(ecStreamNotOpen, 'Stream is not open');
  AddError(ecXmsNotInitialized, 'XMS memory could not be initialized');
  AddError(ecXmsNotSupported, 'XMS memory is not supported');
  AddError(ecStreamCloseError, 'Error closing stream');
  AddError(ecStreamOpenError, 'Error opening stream');
  AddError(ecStreamReadError, 'Error reading stream');
  AddError(ecStreamWriteError, 'Error writing stream');
  AddError(ecStreamSeekError, 'Stream seek error');
  AddError(ecGraphicsModeNotFound, 'Graphics mode not found');
  AddError(ecInvalidCompressionSource, 'Compression source is invalid');
  AddError(ecImageBppNotSupported, 'Image bit depth not supported');
  AddError(ecListCapacityOverflow, 'List capacity overflow');
  AddError(ecInvalidImage, 'Invalid image data');
  AddError(ecImageCompressionNotSupported, 'Image compression not supported');
  AddError(ecStreamFormatNotSupported, 'Stream format not supported');
  AddError(ecFontVersionNotSupported, 'Font version not supported');
  AddError(ecPathNotFound, 'Path not found');
  AddError(ecFileAccessDenied, 'File access denied');
  AddError(ecFileInvalidHandle, 'Invalid file handle');
  AddError(ecFileInvalidEnvironment, 'Invalid environment');
  AddError(ecFileInvalidFormat, 'Invalid file format');
  AddError(ecDirChangeError, 'Error changing directory');
  AddError(ecIndexOutOfBounds, 'List index out of bounds');
  AddError(ecFileInvalidVersion, 'Unsupported file version');
  AddError(ecNullParameter, 'Null parameter');
  AddError(ecInvalidOperation, 'Invalid operation');
  AddError(ecInvalidArgument, 'Invalid argument');
  AddError(ecUnsupportedPaletteFormat, 'Unsupported palette format');
  AddError(ecInvalidPalette, 'Invalid palette');
  AddError(ecCompressionBitSizeError, 'Compression bit size too large');
  AddError(ecCompressorNotSpecified, 'Compressor not specified');
  AddError(ecStreamBufferOverflow, 'Stream buffer overflow');
  AddError(ecKeyNotFound, 'Key not found');
  AddError(ecDuplicateKey, 'Duplicate key');
  AddError(ecImageTooLarge, 'Image too large');
  AddError(ecFileTooLarge, 'File too large');
  AddError(ecMouseError, 'Mouse error');
  AddError(ecCompressedDataTooLarge, 'Compressed data too large');
end;

procedure TErrorList.AddError(AErrorCode: word; AErrorMessage: string);
begin
  Add(New(PError, Create(AErrorCode, AErrorMessage)));
end;

procedure TErrorList.Init;
var
  error: PError;
begin
  inherited Init;
end;

function TErrorList.Add(AItem: PError): integer;
begin
  inherited Add(AItem);
end;

function TErrorList.GetItem(AIndex: integer): PError;
begin
  GetItem := PError(inherited GetItem(AIndex));
end;

function TErrorList.IndexOf(AItem: PError): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TErrorList.SetItem(AIndex: integer; AItem: PError);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TErrorList.Insert(AIndex: integer; AItem: PError);
begin
  inherited Insert(AIndex, AItem);
end;

procedure TErrorList.RemoveItem(AItem: PError);
begin
  inherited RemoveItem(AItem);
end;

function TErrorList.GetErrorByCode(AErrorCode: word): PError;
var
  index: integer;
  searchValue: TError;
begin
  GetErrorByCode := nil;
  searchValue.CreateCode(AErrorCode);
  index := BinarySearch(@searchValue);
  searchValue.Free;
  if index >= 0 then
    GetErrorByCode := GetItem(index);
end;

var
  PreviousExitProc: PProc;

procedure Finalize; far;
begin
  ExitProc := PreviousExitProc;
  FreeAndNil(ErrorList);
end;

begin
  PreviousExitProc := ExitProc;
  ExitProc := @Finalize;
  CustomErrorMessageProc := nil;
  ErrorList := New(PErrorList, Create);
end.