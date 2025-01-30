{$I COMPILER.INC}
unit UnitTemp;

interface

uses
  AplConst,
  AplObj,
  AplStr,
  AplTypes,
  Lists,
  Strings;

implementation

var
  PreviousExitProc: PProc;

procedure Finalize;
begin
  ExitProc := PreviousExitProc;
end;

begin
  PreviousExitProc := ExitProc;
  ExitProc := @Finalize;
end.
