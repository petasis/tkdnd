/*
 * macdnd.m --
 *
 *	This module implements drag and drop for Mac OS X.
 *
 * Copyright (c) 2009 Kevin Walzer/WordTech Communications LLC.
 * Copyright (c) 2009 Daniel A. Steffen <das@users.sourceforge.net> 
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * 
 */

#import <tcl.h>
#import <tk.h>
#import <tkInt.h>
#import <tkMacOSXInt.h>
#import <Cocoa/Cocoa.h>

//Here we need to wrap Cocoa methods in Cocoa class: methods for initiating, tracking, and terminating drag from inside and outside the application.

@interface DNDView : NSView {

  NSPasteboard *dragpasteboard;
  NSMutableArray *draggedtypes;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
TkWindow* TkMacOSXGetTkWindow( NSWindow *w);

@end

@implementation DNDView 


//ripped from Tk-Cocoa source code to map Tk window to Cocoa window
TkWindow* TkMacOSXGetTkWindow(NSWindow *w)  {
  Window window = TkMacOSXGetXWindow(w);
  TkDisplay *dispPtr = TkGetDisplayList();

  return (window != None ?
	  (TkWindow *)Tk_IdToWindow(dispPtr->display, window) : NULL);
}


//We are only implementing dragging destination methods here: widget is drop target. Making a Tk widget a drag source under Cocoa is more complex because mouse events are defined at the Objective-C level. 

//standard Cocoa method for entering drop target; generate <<MacDragEnter>> event for Tk callback
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {

  dragpasteboard = [sender draggingPasteboard];

  //create Tk virtual event
  XVirtualEvent event;
  int x, y;

  TkWindow *winPtr = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin = (Tk_Window) winPtr;

  bzero(&event, sizeof(XVirtualEvent));
  event.type = VirtualEvent;
  event.serial = LastKnownRequestProcessed(Tk_Display(tkwin));
  event.send_event = false;
  event.display = Tk_Display(tkwin);
  event.event = Tk_WindowId(tkwin);
  event.root = XRootWindow(Tk_Display(tkwin), 0);
  event.subwindow = None;
  event.time = TkpGetMS();
  XQueryPointer(NULL, winPtr->window, NULL, NULL,
		&event.x_root, &event.y_root, &x, &y, &event.state);
  Tk_TopCoordsToWindow(tkwin, x, y, &event.x, &event.y);
  event.same_screen = true;
  event.name = Tk_GetUid("MacDragEnter");
  Tk_QueueWindowEvent((XEvent *) &event, TCL_QUEUE_TAIL);

  //return valid NSDragOperations
  return NSDragOperationEvery;
}

//prepare to perform drag operation
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
  dragpasteboard = [sender draggingPasteboard];
  return YES;
}

//perform drag operations: generate <<MacDropPerform>> event for Tk callback
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {

  //  NSArray types;
 
  dragpasteboard = [sender draggingPasteboard];

  //retrieve string data from clipboard
  NSArray *types = [dragpasteboard types];
  NSString *pasteboardvalue = nil;
  for (NSString *type in types) {
    //string type
    if ([type isEqualToString:NSStringPboardType]) {
      pasteboardvalue = [dragpasteboard stringForType:NSStringPboardType];
      //file array, convert to string
    } else if ([type isEqualToString:NSFilenamesPboardType]) { 
      NSArray *files = [dragpasteboard propertyListForType:NSFilenamesPboardType];
      NSString *filename;
      filename =  [files componentsJoinedByString:@"\t"];
      pasteboardvalue = filename;
    }
    //get the string from the drag pasteboard to the general pasteboard
    NSPasteboard *generalpasteboard = [NSPasteboard generalPasteboard];
    NSArray *pasteboardtypes = [NSArray arrayWithObjects:NSStringPboardType, nil];
    [generalpasteboard declareTypes:pasteboardtypes owner:self];
    [generalpasteboard setString:pasteboardvalue forType:NSStringPboardType];
  }


  //generate a virtual event
  XVirtualEvent event;
  int x, y;

  TkWindow *winPtr = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin = (Tk_Window) winPtr;

  bzero(&event, sizeof(XVirtualEvent));
  event.type = VirtualEvent;
  event.serial = LastKnownRequestProcessed(Tk_Display(tkwin));
  event.send_event = false;
  event.display = Tk_Display(tkwin);
  event.event = Tk_WindowId(tkwin);
  event.root = XRootWindow(Tk_Display(tkwin), 0);
  event.subwindow = None;
  event.time = TkpGetMS();
  XQueryPointer(NULL, winPtr->window, NULL, NULL,
		&event.x_root, &event.y_root, &x, &y, &event.state);
  Tk_TopCoordsToWindow(tkwin, x, y, &event.x, &event.y);
  event.same_screen = true;
  event.name = Tk_GetUid("MacDropPerform");
  Tk_QueueWindowEvent((XEvent *) &event, TCL_QUEUE_TAIL);
  return YES;

}

//drop target exited: generate <<MacDragExit>> virtual event
- (void)draggingExited:(id < NSDraggingInfo >)sender {
  dragpasteboard = [sender draggingPasteboard];

  XVirtualEvent event;
  int x, y;

  TkWindow *winPtr = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin = (Tk_Window) winPtr;

  bzero(&event, sizeof(XVirtualEvent));
  event.type = VirtualEvent;
  event.serial = LastKnownRequestProcessed(Tk_Display(tkwin));
  event.send_event = false;
  event.display = Tk_Display(tkwin);
  event.event = Tk_WindowId(tkwin);
  event.root = XRootWindow(Tk_Display(tkwin), 0);
  event.subwindow = None;
  event.time = TkpGetMS();
  XQueryPointer(NULL, winPtr->window, NULL, NULL,
		&event.x_root, &event.y_root, &x, &y, &event.state);
  Tk_TopCoordsToWindow(tkwin, x, y, &event.x, &event.y);
  event.same_screen = true;
  event.name = Tk_GetUid("MacDragExit");
  Tk_QueueWindowEvent((XEvent *) &event, TCL_QUEUE_TAIL);

}

@end

//Register add Cocoa subview to serve as drop target; register dragged data types
int RegisterDragWidget(ClientData clientData, Tcl_Interp *ip,
		       int objc, Tcl_Obj *CONST objv[]) {
  if (objc != 4) {
    Tcl_WrongNumArgs(ip, 1, objv, "path stringtype? filetype?");
    return TCL_ERROR;
  }


  //get window information for drop target
  Rect bounds;
  NSRect frame;
  Tk_Window path;
  path = Tk_NameToWindow(ip, Tcl_GetString(objv[1]), Tk_MainWindow(ip));
  if (path == NULL) {
    return TCL_ERROR;
  }

  Tk_MakeWindowExist(path);
  Tk_MapWindow(path);
  Drawable d = Tk_WindowId(path);

  //get NSView from Tk window and add subview to serve as drop target
  DNDView *dropview = [[DNDView alloc] init];
  NSView *view = TkMacOSXGetRootControl(d);
  if ([dropview superview] != view) {
    [view addSubview:dropview positioned:NSWindowBelow relativeTo:nil];
  }

  TkMacOSXWinBounds((TkWindow*)path, &bounds);
  frame = NSMakeRect(bounds.left, bounds.top, Tk_Width(path),
		     Tk_Height(path));
  frame.origin.y = [view bounds].size.height  -
    (frame.origin.y + frame.size.height);
  [dropview setFrame:frame];

  [dropview displayRectIgnoringOpacity:[dropview bounds]];

  //initialize array of drag types

  NSMutableArray *draggedtypes=[[NSMutableArray alloc] init];

  //this is probably ugly; hard-coding argument positions to specific drag types; checking string lengths to see if types should be registered; can't find a better way to pass drag arguments from Tcl to Objective-C

  int len;

  Tcl_GetStringFromObj(objv[2], &len);
  if (len == 0) {
    NSLog(@"string type not registered");
  } else {
    [draggedtypes addObject: NSStringPboardType];
  }

  Tcl_GetStringFromObj(objv[3], &len);
  if (len == 0) {
    NSLog(@"file type not registered");
  } else {
    [draggedtypes addObject: NSFilenamesPboardType];
  }


  //finally, register the drag types
  [dropview registerForDraggedTypes:draggedtypes];


  return TCL_OK;
}


//unregister the drag widget
int UnregisterDragWidget(ClientData clientData, Tcl_Interp *ip,
			 int objc, Tcl_Obj *CONST objv[]) {
  if (objc != 2) {
    Tcl_WrongNumArgs(ip, 1, objv, "path");
    return TCL_ERROR;
  }

  //get NSView from TK window
  Tk_Window path = Tk_NameToWindow(ip, Tcl_GetString(objv[1]), Tk_MainWindow(ip));

  if (path == NULL) {
    return TCL_ERROR;
  }

  Drawable d = Tk_WindowId(path);
  NSView *view = TkMacOSXGetRootControl(d);

  //get array of subviews and unregister the drag types for each subview
  NSArray *viewarray = [view subviews];
  int arrayCount = [viewarray count];
  int i;
  NSAutoreleasePool *pool =  [[NSAutoreleasePool alloc] init];
  for (i = 0; i < arrayCount; i++) {
    [[viewarray objectAtIndex:i] unregisterDraggedTypes];
  }
 
  [pool release];

  return TCL_OK;

}


//initalize the package in the tcl interpreter, create tcl commands
int Tkdnd_Init (Tcl_Interp *ip) {
	
  // set up an autorelease pool
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
  if (Tcl_InitStubs(ip, "8.5", 0) == NULL) {
    return TCL_ERROR;
  }


  if (Tk_InitStubs(ip, "8.5", 0) == NULL) {
    return TCL_ERROR;
  }

  Tcl_CreateObjCommand(ip, "::macdnd::registerdragwidget", RegisterDragWidget,(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(ip, "::macdnd::unregisterdragwidget", UnregisterDragWidget,(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
		

  if (Tcl_PkgProvide(ip, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
    return TCL_ERROR;
  }

  //release memory
  [pool release];
	
  return TCL_OK;
}

int Tkdnd_SafeInit(Tcl_Interp *ip) {
  return Tkdnd_Init(ip);
}
