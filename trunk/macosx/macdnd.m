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

#define TkDND_TkWin(x)							\
  (Tk_NameToWindow(interp, Tcl_GetString(x), Tk_MainWindow(interp)))

#define TkDND_Eval(objc)						\
  for (i=0; i<objc; ++i) Tcl_IncrRefCount(objv[i]);			\
  if (Tcl_EvalObjv(interp, objc, objv, TCL_EVAL_GLOBAL) != TCL_OK)	\
    Tk_BackgroundError(interp);						\
  for (i=0; i<objc; ++i) Tcl_DecrRefCount(objv[i]);

#define TkDND_Status_Eval(objc)					\
  for (i=0; i<objc; ++i) Tcl_IncrRefCount(objv[i]);		\
  status = Tcl_EvalObjv(interp, objc, objv, TCL_EVAL_GLOBAL);	\
  if (status != TCL_OK) Tk_BackgroundError(interp);		\
  for (i=0; i<objc; ++i) Tcl_DecrRefCount(objv[i]);

#ifndef Tk_Interp
/*
 * Tk 8.5 has a new function to return the interpreter that is associated with a
 * window. Under 8.4 and earlier versions, simulate this function.
 */
#import "tkInt.h"
Tcl_Interp * TkDND_Interp(Tk_Window tkwin) {
  if (tkwin != NULL && ((TkWindow *)tkwin)->mainPtr != NULL) {
    return ((TkWindow *)tkwin)->mainPtr->interp;
  }
  return NULL;
}; /* Tk_Interp */
#define Tk_Interp TkDND_Interp
#endif /* Tk_Interp */


//Here we need to wrap Cocoa methods in Cocoa class: methods for initiating, tracking, and terminating drag from inside and outside the application.

@interface DNDView : NSView {
  NSDragOperation sourceDragMask;
  NSPasteboard   *sourcePasteBoard;
  NSMutableArray *draggedtypes;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender;
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


/*
 * We are only implementing dragging destination methods here:
 * widget is drop target. Making a Tk widget a drag source under
 * Cocoa is more complex because mouse events are defined at the
 * Objective-C level.
 */

/*
 * Standard Cocoa method for entering drop target;
 * Calls tkdnd::macdnd::_HandleEnter
 */
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
  static char *DropActions[] = {
    "copy", "move", "link", "ask",  "private", "refuse_drop", "default",
    (char *) NULL
  };
  enum dropactions {
    ActionCopy, ActionMove, ActionLink, ActionAsk, ActionPrivate,
    refuse_drop, ActionDefault
  };

  TkWindow *winPtr   = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin    = (Tk_Window) winPtr;
  Tcl_Interp *interp = Tk_Interp(tkwin);
  sourcePasteBoard   = [sender draggingPasteboard];
  
  Tcl_Obj* objv[4], *element, *result;
  int i, index, status;
  
  objv[0] = Tcl_NewStringObj("tkdnd::macdnd::_HandleEnter", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(tkwin), -1);
  objv[2] = Tcl_NewLongObj(0);
  objv[3] = Tcl_NewListObj(0, NULL);
  /*
   * Search for known types...
   */
  if ([[sourcePasteBoard types] containsObject:NSStringPboardType]) {
    element = Tcl_NewStringObj("NSStringPboardType", -1);
    Tcl_ListObjAppendElement(NULL, objv[3], element);
  }
  if ([[sourcePasteBoard types] containsObject:NSFilenamesPboardType]) {
    element = Tcl_NewStringObj("NSFilenamesPboardType", -1);
    Tcl_ListObjAppendElement(NULL, objv[3], element);
  }
  /* Evaluate the command and get the result...*/
  TkDND_Status_Eval(4);
  // printf("Status=%d (%d)\n", status, TCL_OK);fflush(0);
  if (status != TCL_OK) {
    /* An error has happened. Cancel the drop! */
    return NSDragOperationNone;
  }
  /* We have a result: the returned action... */
  result = Tcl_GetObjResult(interp); Tcl_IncrRefCount(result);
  status = Tcl_GetIndexFromObj(interp, result, (const char **) DropActions,
			       "dropactions", 0, &index);
  Tcl_DecrRefCount(result);
  if (status != TCL_OK) index = refuse_drop;
  switch ((enum dropactions) index) {
  case ActionDefault:
  case ActionCopy:
    return NSDragOperationCopy;
  case ActionMove:
    return NSDragOperationMove;
  case ActionAsk:
    return NSDragOperationGeneric;
  case ActionPrivate: 
    return NSDragOperationPrivate;
  case ActionLink:
    return NSDragOperationLink;
  case refuse_drop: {
    return NSDragOperationNone; /* Refuse drop. */
  }
  }
  return NSDragOperationNone;
}


- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender {
  sourcePasteBoard = [sender draggingPasteboard];

  //get the coordinates of the cursor
  NSPoint mouseLoc;
  mouseLoc = [NSEvent mouseLocation]; 
 
  TkWindow *winPtr = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin = (Tk_Window) winPtr;
  Tcl_Interp *interp = Tk_Interp(tkwin);
  Tk_Window mouse_tkwin;

  Tcl_Obj* objv[4], *element, *result;
  int i, index, status;

  //map the coordinates to the target window
  float rootX = mouseLoc.x;
  float rootY =  mouseLoc.y;
  mouse_tkwin = Tk_CoordsToWindow(rootX, rootY, tkwin);

  if (mouse_tkwin != NULL) {
    objv[0] = Tcl_NewStringObj("tkdnd::macdnd::_HandleXdndPosition", -1);
    objv[1] = Tcl_NewStringObj(Tk_PathName(mouse_tkwin), -1);
    objv[2] = Tcl_NewIntObj(rootX);
    objv[3] = Tcl_NewIntObj(rootY);

    /* Evaluate the command and get the result...*/
    TkDND_Status_Eval(4);

    //   printf("Status=%d (%d)\n", status, TCL_OK);fflush(0);
    if (status != TCL_OK) {
      /* An error has happened. Cancel the drop! */
      return NSDragOperationNone;
    }
 
  }
}

//prepare to perform drag operation
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
  sourcePasteBoard = [sender draggingPasteboard];
  return YES;
}

/*
 * Standard Cocoa method for handling drop operation
 * Calls tkdnd::macdnd::_HandleXdndDrop
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {

  sourcePasteBoard = [sender draggingPasteboard];

  TkWindow *winPtr = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin = (Tk_Window) winPtr;
  Tcl_Interp *interp = Tk_Interp(tkwin);

  //retrieve string data from clipboard
  NSArray *types = [sourcePasteBoard types];
  NSString *pasteboardvalue = nil;
  for (NSString *type in types) {
    //string type
    if ([type isEqualToString:NSStringPboardType]) {
      pasteboardvalue = [sourcePasteBoard stringForType:NSStringPboardType];
      //file array, convert to string
    } else if ([type isEqualToString:NSFilenamesPboardType]) { 
      NSArray *files = [sourcePasteBoard propertyListForType:NSFilenamesPboardType];
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

  Tcl_Obj* objv[4], *element, *result;
  int i, index, status;
  
  objv[0] = Tcl_NewStringObj("tkdnd::macdnd::_HandleXdndDrop", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(tkwin), -1);
  objv[2] = Tcl_NewLongObj(0);
  objv[3] = Tcl_NewListObj(0, NULL);

  /* Evaluate the command and get the result...*/
  TkDND_Status_Eval(4);
  //  printf("Status=%d (%d)\n", status, TCL_OK);fflush(0);
  if (status != TCL_OK) {
    /* An error has happened. Cancel the drop! */
    return NSDragOperationNone;
  }
 
  return YES;

}

/*
 * Standard Cocoa method for handling drop operation
 * Calls tkdnd::macdnd::_HandleXdndDrop
 */

- (void)draggingExited:(id < NSDraggingInfo >)sender {
  sourcePasteBoard = [sender draggingPasteboard];


  TkWindow *winPtr = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin = (Tk_Window) winPtr;
  Tcl_Interp *interp = Tk_Interp(tkwin);

  Tcl_Obj* objv[4], *element, *result;
  int i, index, status;
  
  objv[0] = Tcl_NewStringObj("tkdnd::macdnd::_HandleXdndLeave", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(tkwin), -1);
  objv[2] = Tcl_NewLongObj(0);
  objv[3] = Tcl_NewListObj(0, NULL);

  /* Evaluate the command and get the result...*/
  TkDND_Status_Eval(4);
  // printf("Status=%d (%d)\n", status, TCL_OK);fflush(0);
  if (status != TCL_OK) {
    /* An error has happened. Cancel the drop! */
    return NSDragOperationNone;
  }

}

@end

//Register add Cocoa subview to serve as drop target; register dragged data types
int RegisterDragWidget(ClientData clientData, Tcl_Interp *ip,
		       int objc, Tcl_Obj *CONST objv[]) {
  Tcl_Obj **type;
  int typec, i, len;
  char *str;
  bool added_string = false, added_filenames = false;

  if (objc != 3) {
    Tcl_WrongNumArgs(ip, 1, objv, "path types-list");
    return TCL_ERROR;
  }

  /*
   * Get the list of desired drop target types...
   */
  if (Tcl_ListObjGetElements(ip, objv[2], &typec, &type) != TCL_OK) {
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

  //hack to make sure subview is set to take up entire geometry of window
  frame = NSMakeRect(bounds.left, bounds.top, 100000, 100000);
  frame.origin.y = 0;

  if (!NSEqualRects(frame, [dropview frame])) {
    [dropview setFrame:frame];
  }

  //initialize array of drag types

  NSMutableArray *draggedtypes=[[NSMutableArray alloc] init];

  /*
   * Iterate over all requested types...
   */
  for (i = 0; i < typec; ++i) {
    str = Tcl_GetStringFromObj(type[i], &len);
    if (strncmp(str, "*", len) == 0) {
      /* A request for all available types... */
      if (!added_string) {
        [draggedtypes addObject: NSStringPboardType];
        added_string = true;
      }
      if (!added_filenames) {
        [draggedtypes addObject: NSFilenamesPboardType];
        added_filenames = true;
      }
    } else if (strncmp(str, "NSStringPboardType", len) == 0) {
      if (!added_string) {
        [draggedtypes addObject: NSStringPboardType];
        added_string = true;
      }
    } else if (strncmp(str, "NSFilenamesPboardType", len) == 0) {
      if (!added_filenames) {
        [draggedtypes addObject: NSFilenamesPboardType];
        added_filenames = true;
      }
    } else {
      /* Do what? Raise an error or silently ignore the unknown type? */
    }
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
