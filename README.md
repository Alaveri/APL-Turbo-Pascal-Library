# APL
Alaveri Pascal Library

The Alaveri Pascal Library contains a comprehensive set of Borland/Turbo Pascal 7 units including graphics utilties (CGA/VGA/EGA/SVGA), mouse support, objects, lists, streams, sorting and searching, large strings, memory management (including Extended Memory support for real mode), and more.

The APL is still under development, but already contains significant functionality.  Note: some unit names and identifier names may change in the future until it is finalized as version 1.0.

Supported features currently include:

1. The APL is fully object-oriented in design and has an object hierarchy.
2. Basic Objects (TObject, TIdentifiable) - Objects.pas. All APL objects are descended from TObject.  TIdentifiable is a basic TObject with an Id field (stored as a PChar), and contains functions for setting and getting the Id field using pascal short strings.
3. Dynamic lists (TCollection, TList, TObjectList, TLinkedList, TStack, TQueue, TStringList) - Lists.pas.  Dynamic lists are implemented as arrays of pointers in a buffer and can be accessed by index (only pointers are stored, not objects themselves).  TCollection and its descendents allocate buffer space as needed depending on the size of the collection.  TList and its descendents also provide sorting (Quicksort by default) based on arbitrary comparison functions.  TList also supports a Sorted mode that inserts and finds object using binary searches.  TObjectList can (by default) free objects when they are deleted or cleared, or on calling the destructor of the list.  Setting DisposeObjects of a TObjectList to false will disable this behavior, enabling the list to point to various objects without affecting them. Implementing descendents of TObjectList to support custom objects is fast and easy.
4. A common library of functions - Common.pas.  Min/Max functions for all integer types, filename manipulation, trimming, lower/upper casing, checking number ranges, getting and changing directories, etc.
5. Date/time manipulation - DateTime.pas.  TDateTime, TTimeSpan and TStopWatch provide date manipulation and store dates/times with 100th second precision.  Methods exist for retrieving month, day, year, hour minute, second and 100th second, as well as adding/subtracting by these different units.  The Ticks field stores the actual value as a double precision float, as can be added/subtracted with the Ticks field of TTimeSpan objects.
6. Error handling - Errors.pas.  Includes TExceptionObject that contains an Exception field which can store errors that occur (as well as InnerException to provide a trace of exceptions that caused the final exception).  Supports HasException boolean and ClearException, as well as the Raise method which adds new exceptions to the Exception field.  Most I/O, compression and other error-prone objects in the APL are derived from TExceptionObject.
7. Memory handling, including XMS support in real mode - Drivers/MemDrv.pas.  The memory driver supports allocation of TReference (pointers to data) of up to 64k and handles swapping references in and out of conventional and XMS memory if supported as needed.  EMS is not supported at this time.
8. Streams - Streams.pas.  Implementation for basic streams (TStream), TFileStream and TMemoryStream.  TMemoryStream handles streams of arbitrary size up to available XMS memory (including > 64k) using the MemDrv unit.  TMemoryStream maintains a list of TReference objects and swaps them in and out of XMS as needed during calls to .Read and .Write.  Swapping is seamless to the user of the stream and the stream may be read or written to at will from any position within the stream.
9. Large/null-terminated string handling - StrUtils.pas.  TStringUtil type provides functions that encapsulate the Strings.pas unit from Turbo Pascal 7.  The methods handle automatic allocation/deallocation of PChar variables as needed.  The TString variable (of type TStringUril) is created on startup and can be used to call string functions (for example, ```myString := TString.New('example text');``` will return a new null-terminated PChar containing the string passed as the paramater).  These functions check if PChar vairables are already assigned and frees them before doing new allocations or assignments.
10. Compression - Compress.pas and Lzw.pas.  Compressing of TStream objects to a destination stream is supported through the base TCompressor object.  TLzw is a currently implemented as a descendent of TCompressor and supports 12 and 13-bit Lzw compression.
11. Applications - Apps.pas, GraphApp.pas, TextApp.pas.  Basic application object containing a main loop and a ProcessEvents method called on each loop iteration.  TGraphApp and TTextApp implement basic text and graphics mode applications.  
12. Directory/File listing - Files.pas.  TDirectoryManager objects can create and return PDirectoryContents objects containing the contents of a directory matching a path and pattern. The variable TDirectory (of type TDirectoryManager) is created on startup, and can be used without creating it (for example ```dir := TDirectory.GetDirectory```.
13. Shape handling - Drawing.pas.  Basic drawing contaings, TRect, TPoint, TShape.  These provide storage of shapes, translation of shape location, growing/shrinking, intersection with other shapes, etc.
14. Mouse driver - MouseDrv.pas.  Provides mouse-handling functions including setting sensitivity and retrieving mouse/button state, and maintains a State Stack that contains mouse states (position, visible, etc).  PushState stores the state of the mouse and PopState restores the previous state.  This allows arbitrary number of push/pop operations and modifying the state without affecting containing calls.
15. Graphics drivers - GraphDrv.pas, Graph8Drv.pas, Vga8Drv.pas, SVga8Drv.pas (and others under development).  These handle detection of graphics modes and basic drawing functionality (lines, images, etc).  TGraphics8Driver supports 8-bit (256) color is descended from the base TGraphicsDriver object and TVga8Driver, TSVga8Driver are descended from TGraph8Driver.  The TGraph8Driver object supports mouse drawing functions (this will probably be moved to a different level in the future).  A TGrpahicsDriver object can be assigned with any descendent class and provides an interface to whichever graphics driver is in use.  The drivers support clipping ViewPorts and maintain a TStateStack that contains information such as current color and ViewPort.  PushState and PopState can be used to change these values and restore them to their original values after use.  The GraphIni (GraphIni.pas) unit provides a factory function for creating a graphics driver of a specific type and returning it as a PGraphicsDriver reference.
16. Actions - Actions.pas.  TAction and TActionList can be used to maintain a list of common Actions that can be associated with various commands, objects and events.  Actions contain a shortcut key, text value and help text.
17. Keyboard handling - KeyDrv.pas.  Handling of Keyboard operations inluding reading key presses and constants for common key combinations (kyCtrlX, kyAltT, kyShiftCtrlDown, kyEsc, etc.)
18. More to come!
