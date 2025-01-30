{$I COMPILER.INC}
unit GraphApp;

interface

uses
  AplObj,
  AplTypes,
  Lists,
  AplApps,
  Graphics,
  Gr8Drv,
  Drawing,
  MouseDrv,
  GraphIni;

type
  PGraphApp = ^TGraphApp;
  PMouseCursor = ^TMouseCursor;
  PMouseCursorList = ^TMouseCursorList;

  TMouseCursorImage = array[0..14, 0..14] of byte;

  TMouseCursor = object(TIdentifiable)
  private
    FBackData: PByte;
  public
    Visible: boolean;
    X, Y: integer;
    OffsetX, OffsetY: integer;
    Image: PByte;
    Width, Height: word;
    constructor Create(AId: string; AWidth, AHeight: integer; AImage: PByte);
    destructor Free; virtual;
    function BackData: PByte;
    procedure GetBounds(var ARect: TRect);
    procedure Draw;
    procedure Paint;
    procedure Init; virtual;
    procedure StoreBackground(AX, AY: integer);
  end;

  TMouseCursorList = object(TIdentifiableList)
  private
  public
    function GetItem(AIndex: integer): PMouseCursor;
    function GetItemById(const AId: string): PMouseCursor;
    function Add(AItem: PMouseCursor): integer;
    function IndexOf(AItem: PMouseCursor): integer;
    procedure SetItem(AIndex: integer; AItem: PMouseCursor);
    procedure Insert(AIndex: integer; AItem: PMouseCursor);
    procedure Init; virtual;
  end;

  TGraphApp = object(TApplication)
  private
    FDriverId: TGraphDrivers;
  public
    MouseCursors: PMouseCursorList;
    MouseCursor: PMouseCursor;
    constructor Create(ADriverId: TGraphDrivers);
    destructor Free; virtual;
    function GetGraphicsModeId(AWidth, AHeight, ABpp: integer): integer;
    function SetMode(AModeId: integer): boolean; virtual;
    procedure Init; virtual;
    procedure InitMouseCursors;
    procedure Initialized ; virtual;
    procedure ShowMouseCursor; virtual;
    procedure HideMouseCursor; virtual;
    procedure EraseMouseCursor(const AMouseState: TMouseState); virtual;
    procedure DrawMouseCursor(const AMouseState: TMouseState); virtual;
    procedure MoveMouseCursor(const AMouseState, AOldMouseState: TMouseState;
      AWaitForVSync: boolean); virtual;
    procedure RedrawMouseCursor(var AViewPort: TRect; const AMouseState: TMouseState);
  end;

const
  DefaultMouseCursor: TMouseCursorImage =
  (
    ($0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $0F, $0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF)
  );

  DefaultBeamMouseCursor: TMouseCursorImage =
  (
    ($0F, $0F, $0F, $FF, $0F, $0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $0F, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $0F, $0F, $00, $0F, $0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $0F, $0F, $00, $0F, $0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $0F, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $0F, $0F, $FF, $0F, $0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF)
  );

  DefaultNWSECursor: TMouseCursorImage =
  (
    ($0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $0F, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $00, $0F, $FF, $0F, $0F, $FF, $FF, $FF, $FF),
    ($0F, $00, $0F, $00, $00, $00, $00, $00, $0F, $00, $0F, $FF, $FF, $FF, $FF),
    ($0F, $0F, $FF, $0F, $00, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF),
    ($0F, $FF, $FF, $FF, $0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $0F, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF)
  );

  DefaultNESWCursor: TMouseCursorImage =
  (
    ($FF, $FF, $FF, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $0F, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF),
    ($0F, $FF, $FF, $FF, $0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF),
    ($0F, $0F, $FF, $0F, $00, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF),
    ($0F, $00, $0F, $00, $00, $00, $00, $00, $0F, $00, $0F, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $00, $0F, $FF, $0F, $0F, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $0F, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF)
  );

  DefaultEWCursor: TMouseCursorImage =
  (
    ($FF, $FF, $FF, $FF, $FF, $0F, $FF, $FF, $FF, $0F, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $0F, $0F, $FF, $FF, $FF, $0F, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $0F, $00, $0F, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $00, $0F, $0F, $0F, $0F, $0F, $00, $00, $0F, $FF, $FF),
    ($FF, $0F, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $0F, $FF),
    ($0F, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $0F),
    ($FF, $0F, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $0F, $FF),
    ($FF, $FF, $0F, $00, $00, $0F, $0F, $0F, $0F, $0F, $00, $00, $0F, $FF, $FF),
    ($FF, $FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $0F, $00, $0F, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $0F, $0F, $FF, $FF, $FF, $0F, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $0F, $FF, $FF, $FF, $0F, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF)
  );

  DefaultNSCursor: TMouseCursorImage =
  (
    ($FF, $FF, $FF, $FF, $FF, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $0F, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $0F, $00, $00, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF),
    ($0F, $0F, $0F, $0F, $00, $00, $00, $0F, $0F, $0F, $0F, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $0F, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $0F, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $0F, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($0F, $0F, $0F, $0F, $00, $00, $00, $0F, $0F, $0F, $0F, $FF, $FF, $FF, $FF),
    ($FF, $0F, $00, $00, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $0F, $00, $00, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $0F, $00, $00, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $0F, $00, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
    ($FF, $FF, $FF, $FF, $FF, $0F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF)
  );


var
  Graph8: PGraphics8Driver;

implementation

uses
  AplConst;

constructor TGraphApp.Create(ADriverId: TGraphDrivers);
begin
  inherited Create;
  FDriverId := ADriverId;
  GraphIni.InitGraphicsDriver(ADriverId);
  Graph8 := PGraphics8Driver(Graph);
end;

function TGraphApp.GetGraphicsModeId(AWidth, AHeight, ABpp: integer): integer;
var
  mode: PGraphicsMode;
  index: integer;
begin
  GetGraphicsModeId := -1;
  if HasException then
    exit;
  for index := 0 to Graph^.Modes.Count - 1 do begin
    mode := Graph^.Modes.GetItem(index);
    if (mode^.Width = AWidth) and (mode^.Height = AHeight) and (mode^.Bpp = ABpp) then begin
      GetGraphicsModeId := mode^.ModeId;
      exit;
    end;
  end;
end;

function TGraphApp.SetMode(AModeId: integer): boolean;
var
  mode: PGraphicsMode;
begin
  SetMode := true;
  mode := Graph^.Modes.GetModeById(AModeId);
  if not Assigned(mode) then begin
    SetMode := false;
    exit;
  end;
  Graph^.SetMode(mode);
  CheckReRaise(Graph);
end;

procedure TGraphApp.Init;
begin
  inherited Init;
end;

procedure TGraphApp.InitMouseCursors;
var
  cursor: PMouseCursor;
  sens: integer;
begin
  MouseCursors := New(PMouseCursorList, Create);
  cursor := New(PMouseCursor, Create('Default', 15, 15, @DefaultMouseCursor));
  MouseCursors^.Add(cursor);
  cursor := New(PMouseCursor, Create('Beam', 15, 15, @DefaultBeamMouseCursor));
  cursor^.OffsetX := 4;
  cursor^.OffsetY := 7;
  MouseCursors^.Add(cursor);
  cursor := New(PMouseCursor, Create('NWSE', 15, 15, @DefaultNWSECursor));
  cursor^.OffsetX := 6;
  cursor^.OffsetY := 5;
  MouseCursors^.Add(cursor);
  cursor := New(PMouseCursor, Create('NESW', 15, 15, @DefaultNESWCursor));
  cursor^.OffsetX := 6;
  cursor^.OffsetY := 5;
  MouseCursors^.Add(cursor);
  cursor := New(PMouseCursor, Create('NS', 15, 15, @DefaultNSCursor));
  cursor^.OffsetX := 6;
  cursor^.OffsetY := 7;
  MouseCursors^.Add(cursor);
  cursor := New(PMouseCursor, Create('EW', 15, 15, @DefaultEWCursor));
  cursor^.OffsetX := 7;
  cursor^.OffsetY := 6;
  MouseCursors^.Add(cursor);
  MouseCursor := MouseCursors^.GetItemById('Default');
end;

destructor TGraphApp.Free;
begin
  inherited Free;
end;

procedure TGraphApp.Initialized;
begin
  InitMouseCursors;
end;

procedure TGraphApp.RedrawMouseCursor(var AViewPort: TRect;
  const AMouseState: TMouseState);
var
  oldViewPort: TRect;
  drawRect: TRect;
begin
  if not MouseCursor^.Visible then
    exit;
  drawRect.CreateDims(AMouseState.X, AMouseState.Y,
    MouseCursor^.Width, MouseCursor^.Height);
  drawRect.Translate(-MouseCursor^.OffsetX, MouseCursor^.OffsetY);
  drawRect.Intersect(AViewPort);
  if drawRect.IsEmpty then
    exit;
  MouseCursor^.Draw;
end;

procedure TGraphApp.MoveMouseCursor(const AMouseState, AOldMouseState: TMouseState;
  AWaitForVSync: boolean);
begin
  if not (MouseCursor^.Visible and AMouseState.Visible) then
    exit;
  if AWaitForVSync then
    Graph^.WaitForVSync;
  if Assigned(MouseCursor^.FBackData) then
    EraseMouseCursor(AOldMouseState);
  DrawMouseCursor(AMouseState);
end;

procedure TGraphApp.EraseMouseCursor(const AMouseState: TMouseState);
begin
  if (not MouseCursor^.Visible) or not (AMouseState.Visible) then
    exit;
  if Assigned(MouseCursor^.FBackData) then begin
    Graph^.DrawImageCoords(
      AMouseState.X - MouseCursor^.OffsetX,
      AMouseState.Y - MouseCursor^.OffsetY,
      MouseCursor^.Width,
      MouseCursor^.Height,
      MouseCursor^.FBackData,
      []
    );
  end;
end;

procedure TGraphApp.DrawMouseCursor(const AMouseState: TMouseState);
begin
  if (not MouseCursor^.Visible) or (not AMouseState.Visible) then
    exit;
  MouseCursor^.StoreBackground(AMouseState.X, AMouseState.Y);
  MouseCursor^.X := AMouseState.X;
  MouseCursor^.Y := AMouseState.Y;
  MouseCursor^.Draw;
end;

procedure TGraphApp.ShowMouseCursor;
begin
  Graph^.State^.ViewPort.SetDims(0, 0, Graph^.Mode^.Width, Graph^.Mode^.Height);
  Mouse.ShowMouse;
  Mouse.UpdateState;
  MouseCursor^.Visible := true;
  DrawMouseCursor(Mouse.State);
end;

procedure TGraphApp.HideMouseCursor;
begin
  if not MouseCursor^.Visible then
    exit;
  Graph^.State^.ViewPort.SetDims(0, 0, Graph^.Mode^.Width, Graph^.Mode^.Height);
  EraseMouseCursor(Mouse.State);
  MouseCursor^.Visible := false;
  Mouse.HideMouse;
end;

constructor TMouseCursor.Create(AId: string; AWidth, AHeight: integer; AImage: PByte);
begin
  inherited CreateId(AId);
  Width := AWidth;
  Height := AHeight;
  Image := AImage;
  GetMem(FBackData, Width * Height * Graph^.Mode^.Bpp div 8);
end;

procedure TMouseCursor.Init;
begin
  inherited Init;
  Width := 0;
  Height := 0;
  Visible := true;
  Y := 0;
  X := 0;
  OffsetX := 0;
  OffsetY := 0;
  FBackData := nil;
end;

procedure TMouseCursor.Paint;
begin
  Graph^.DrawImageCoords(X - OffsetX, Y - OffsetY, Width, Height, Image, [ifTransparent]);
end;

procedure TMouseCursor.Draw;
begin
  if not Visible then
    exit;
  Graph^.PushState;
  Graph^.State^.ViewPort.SetRect(Graph^.State^.Bounds);
  Paint;
  Graph^.PopState;
end;

procedure TMouseCursor.GetBounds(var ARect: TRect);
begin
  ARect.CreateDims(X - OffsetX, Y - OffsetY, Width, Height);
end;

procedure TMouseCursor.StoreBackground(AX, AY: integer);
var
  rect: TRect;
begin
  Dec(AX, OffsetX);
  Dec(AY, OffsetY);
  rect.CreateDims(AX, AY, Width, Height);
  Graph^.PushState;
  Graph^.State^.ViewPort.SetRect(Graph^.State^.Bounds);
  Graph^.GetImage(AX, AY, Width, Height, FBackData);
  Graph^.PopState;
end;

destructor TMouseCursor.Free;
begin
  if Assigned(FBackData) then
    FreeMem(FBackData, Width * Height);
  inherited Free;
end;

function TMouseCursor.BackData: PByte;
begin
  BackData := FBackData;
end;

function TMouseCursorList.GetItem(AIndex: integer): PMouseCursor;
begin
  GetItem := PMouseCursor(inherited GetItem(AIndex));
end;

procedure TMouseCursorList.Init;
begin
  inherited Init;
end;

function TMouseCursorList.GetItemById(const AId: string): PMouseCursor;
begin
  GetItemById := PMouseCursor(inherited GetItemById(AId));
end;

function TMouseCursorList.Add(AItem: PMouseCursor): integer;
begin
  Add := inherited Add(AItem);
end;

function TMouseCursorList.IndexOf(AItem: PMouseCursor): integer;
begin
  IndexOf := inherited IndexOf(AItem);
end;

procedure TMouseCursorList.SetItem(AIndex: integer; AItem: PMouseCursor);
begin
  inherited SetItem(AIndex, AItem);
end;

procedure TMouseCursorList.Insert(AIndex: integer; AItem: PMouseCursor);
begin
  inherited Insert(AIndex, AItem);
end;

end.