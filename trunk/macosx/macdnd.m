/*
 * macdnd.m --
 *
 *	This module implements drag and drop for Mac OS X.
 *
 * Copyright (c) 2009 Kevin Walzer/WordTech Communications LLC.
 * Copyright (c) 2009 Daniel A. Steffen <das@users.sourceforge.net>
 * Copyright (c) 2009 Georgios P. Petasis <petasis@iit.demokritos.gr>
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


/*
 * Here we need to wrap Cocoa methods in Cocoa class: methods for initiating,
 * tracking, and terminating drag from inside and outside the application.
 */

@interface DNDView : NSView {
  NSDragOperation sourceDragMask;
  NSPasteboard   *sourcePasteBoard;
  NSMutableArray *draggedtypes;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender;
- (void)mouseDown:(NSEvent*)event;
- (int)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
TkWindow* TkMacOSXGetTkWindow( NSWindow *w);

@end

@implementation DNDView

/*
 * Ripped from Tk-Cocoa source code to map Tk window to Cocoa window
 */
TkWindow* TkMacOSXGetTkWindow(NSWindow *w)  {
  Window window = TkMacOSXGetXWindow(w);
  TkDisplay *dispPtr = TkGetDisplayList();

  return (window != None ? (TkWindow *)Tk_IdToWindow(dispPtr->display, window) :
                           NULL);
}; /* TkMacOSXGetTkWindow */


/*******************************************************************************
 *******************************************************************************
 ***** Drag Source Operations                                              *****
 *******************************************************************************
 *******************************************************************************/

//this is the correct way to specify a drag source in a Cocoa window, but this appears to completely override any script-level code. For instance, a Tk-level command to append text to the clipboard is ignored: this method grabs existing data from the clipboard. Also, there appears to be no way to turn this method on or off from the script level and this causes script-level collisions. Dragging to select text in the Tk text widget introduces the drag-and-drop motion, which isn't the right approach.


#if 0
- (void)mouseDown:(NSEvent*)event {

  TkWindow *winPtr   = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin    = (Tk_Window) winPtr;
  Tcl_Interp *interp = Tk_Interp(tkwin);


  NSPasteboard* dragPasteboard=[NSPasteboard pasteboardWithName:NSDragPboard];
  [dragPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
  [dragPasteboard addTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:self];


  //write the string from the general pasteboard to the drag pasteboard

  NSPasteboard *generalpasteboard = [NSPasteboard generalPasteboard];

  NSArray *types = [generalpasteboard types];
  NSString *pasteboardvalue = nil;
  for (NSString *type in types) {
    if ([type isEqualToString:NSStringPboardType]) {
      pasteboardvalue = [generalpasteboard stringForType:NSStringPboardType];
      //file array, convert to string
    } else if ([type isEqualToString:NSFilenamesPboardType]) {
      NSArray *files = [generalpasteboard propertyListForType:NSFilenamesPboardType];
      NSString *filename;
      filename =  [files componentsJoinedByString:@"\t"];
      pasteboardvalue = filename;
    }
    [dragPasteboard setString:pasteboardvalue forType:NSStringPboardType];
  }


  //simple drag icon taken from NSImage constants: four small grouped squares
NSImage *dragicon = [NSImage imageNamed:NSImageNameIconViewTemplate];


  NSPoint point;
  point = [event locationInWindow];
  [self dragImage:dragicon
	       at:point
	   offset:NSMakeSize(0, 0)
	    event:event
       pasteboard:dragPasteboard
	   source:self
	slideBack:YES];

}


//set flags for local drag operation: not sure if this is necessary or not
- (int)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
 if (isLocal) return NSDragOperationCopy;
return NSDragOperationCopy|NSDragOperationGeneric|NSDragOperationLink;
}
#endif

/*
 * 
 */
int TkDND_DoDragDropObjCmd(ClientData clientData, Tcl_Interp *interp,
                           int objc, Tcl_Obj *CONST objv[]) {
  Tcl_Obj         **elem;
  int               actions = 0;
  int               status, elem_nu, i, index, nDataLength;
  char             *ptr;
  Tcl_UniChar      *unicode, *ptr_u;
  static char *DropTypes[] = {
    "NSStringPboardType", "NSFilenamesPboardType",
    (char *) NULL
  };
  enum droptypes {
    TYPE_NSStringPboardType, TYPE_NSFilenamesPboardType
  };
  static char *DropActions[] = {
    "copy", "move", "link", "ask",  "private", "refuse_drop",
    "default",
    (char *) NULL
  };
  enum dropactions {
    ActionCopy, ActionMove, ActionLink, ActionAsk, ActionPrivate,
    refuse_drop, ActionDefault
  };

  if (objc != 5) {
    Tcl_WrongNumArgs(interp, 1, objv, "path actions types data");
    return TCL_ERROR;
  }
  Tcl_ResetResult(interp);
  //  Tcl_SetResult(interp, "refuse_drop", TCL_STATIC);

  /* Process drag actions. */
  status = Tcl_ListObjGetElements(interp, objv[2], &elem_nu, &elem);
  if (status != TCL_OK) return status;
  for (i = 0; i < elem_nu; i++) {
    status = Tcl_GetIndexFromObj(interp, elem[i], (const char **)DropActions,
                                 "dropactions", 0, &index);
    if (status != TCL_OK) return status;
    switch ((enum dropactions) index) {
      case ActionCopy:    actions |= NSDragOperationCopy;    break;
      case ActionMove:    actions |= NSDragOperationMove;    break;
      case ActionLink:    actions |= NSDragOperationLink;    break;
      case ActionAsk:     actions |= NSDragOperationGeneric; break;
      case ActionPrivate: actions |= NSDragOperationPrivate; break;
      case ActionDefault: /* not supported */;               break;
      case refuse_drop:   /* not supported */;               break;
    }
  }

  /* Get the object that holds this Tk Window... */
  // TODO: how to do this?

  //get pasteboard
 NSPasteboard *generalpasteboard = [NSPasteboard generalPasteboard];
 [generalpasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
  [generalpasteboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];

  /* Process drag types. */
  Tcl_Obj *data      = NULL;
  Tcl_Obj *indexptr = NULL;
  status = Tcl_ListObjGetElements(interp, objv[3], &elem_nu, &elem);
  if (status != TCL_OK) return status;
  for (i = 0; i < elem_nu; i++) {
    status = Tcl_GetIndexFromObj(interp, elem[i], (const char **) DropTypes,
                                 "dropactions", 0, &index);
    if (status == TCL_OK) {
      switch ((enum droptypes) index) {
        case TYPE_NSStringPboardType: {
          // Place the string in the clipboard
	  NSString *datastring = [NSString stringWithUTF8String:Tcl_GetString(objv[4])] ;
    	  [generalpasteboard setString:datastring forType:NSStringPboardType];  
          break;
        }
        case TYPE_NSFilenamesPboardType: {
	  NSMutableArray *filelist = nil;
   
          // Place the filenames in the clipboard
	  status = Tcl_ListObjGetElements(interp, objv[4], &elem_nu, &elem);
	  for (i = 0; i < elem_nu; i++) {
	     /* Get string value of file name from list */
	    status = Tcl_ListObjIndex(interp,  objv[4], elem[i], &indexptr);

    if (TCL_OK != Tcl_GetString(&indexptr)) {
      return TCL_ERROR ;
    }
 
    
    //convert file names to NSSString, add to NSMutableArray, set pasteboard type
    NSString *filestring = [NSString stringWithUTF8String:Tcl_GetString(indexptr)];
	    [filelist addObject: [NSString stringWithString:filestring]]; 
	    [generalpasteboard setPropertyList:filelist forType:NSFilenamesPboardType];
	  }
	  break;
	}

      }
    } else {
      /* An unknown (or user defined) type. Silently skip it... */
    }
  }

  /* Do drag & drop... */

  /* Get the drop action... */
  // Tcl_SetResult(interp, "refuse_drop", TCL_STATIC);
  return TCL_OK;
}; /* TkDND_DoDragDropObjCmd */

/*******************************************************************************
 *******************************************************************************
 ***** Drop Target Operations                                              *****
 *******************************************************************************
 *******************************************************************************/

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
}; /* draggingEntered */

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender {
  static char *DropActions[] = {
    "copy", "move", "link", "ask",  "private", "refuse_drop", "default",
    (char *) NULL
  };
  enum dropactions {
    ActionCopy, ActionMove, ActionLink, ActionAsk, ActionPrivate,
    refuse_drop, ActionDefault
  };
  Tk_Window mouse_tkwin;
  NSPoint mouseLoc;

  TkWindow *winPtr   = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin    = (Tk_Window) winPtr;
  Tcl_Interp *interp = Tk_Interp(tkwin);
  sourcePasteBoard   = [sender draggingPasteboard];
  /* Get the coordinates of the cursor... */
  mouseLoc = [NSEvent mouseLocation];

  Tcl_Obj* objv[4], *result;
  int i, index, status;

  /*
   * Map the coordinates to the target window: must substract mouseLocation
   * from screen height because Cocoa orients to bottom of screen, Tk to
   * top...
   */
  float rootX = mouseLoc.x;
  float rootY = mouseLoc.y;
  float screenheight = [[[NSScreen screens] objectAtIndex:0] frame].size.height;

  /* Convert Cocoa screen cordinates to Tk coordinates... */
  float tk_Y  = screenheight - rootY;
  mouse_tkwin = Tk_CoordsToWindow(rootX, tk_Y, tkwin);
  if (mouse_tkwin == NULL) return NSDragOperationNone;

  objv[0] = Tcl_NewStringObj("tkdnd::macdnd::_HandlePosition", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(mouse_tkwin), -1);
  objv[2] = Tcl_NewIntObj(rootX);
  objv[3] = Tcl_NewIntObj(rootY);

  /* Evaluate the command and get the result...*/
  TkDND_Status_Eval(4);

  //  printf("Status=%d (%d)\n", status, TCL_OK);fflush(0);
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
}; /* draggingUpdated */

//prepare to perform drag operation
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
  sourcePasteBoard = [sender draggingPasteboard];
  return YES;
}; /* prepareForDragOperation */

/*
 * Standard Cocoa method for handling drop operation
 * Calls tkdnd::macdnd::_HandleDrop
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
  static char *DropActions[] = {
    "copy", "move", "link", "ask",  "private", "refuse_drop", "default", "",
    (char *) NULL
  };
  enum dropactions {
    ActionCopy, ActionMove, ActionLink, ActionAsk, ActionPrivate,
    refuse_drop, ActionDefault, NoReturnedAction
  };
  TkWindow *winPtr   = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin    = (Tk_Window) winPtr;
  Tcl_Interp *interp = Tk_Interp(tkwin);
  sourcePasteBoard   = [sender draggingPasteboard];
  Tcl_Obj *data      = NULL;

  /* Retrieve string data from clipboard... */
  NSArray    *types           = [sourcePasteBoard types];
  NSString   *pasteboardvalue = nil;
  for (NSString *type in types) {
    if ([type isEqualToString:NSStringPboardType]) {
      /* String type... */
      pasteboardvalue = [sourcePasteBoard stringForType:NSStringPboardType];
      data = Tcl_NewStringObj([pasteboardvalue UTF8String], -1);
    } else if ([type isEqualToString:NSFilenamesPboardType]) {
      Tcl_Obj *element;
      data = Tcl_NewListObj(0, NULL);
      /* File array... */
      NSArray *files =
               [sourcePasteBoard propertyListForType:NSFilenamesPboardType];
      for (NSString *filename in files) {
        element = Tcl_NewStringObj([filename UTF8String], -1);
        if (element == NULL) continue;
        Tcl_IncrRefCount(element);
        Tcl_ListObjAppendElement(interp, data, element);
        Tcl_DecrRefCount(element);
      }
    }
  }
  if (data == NULL) data = Tcl_NewStringObj(NULL, 0);

  Tcl_Obj* objv[3], *result;
  int i, index, status;

  objv[0] = Tcl_NewStringObj("tkdnd::macdnd::_HandleDrop", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(tkwin), -1);
  objv[2] = data;

  /* Evaluate the command and get the result...*/
  TkDND_Status_Eval(3);
  //  printf("Status=%d (%d)\n", status, TCL_OK);fflush(0);
  if (status != TCL_OK) {
    /* An error has happened. Cancel the drop! */
    return NO;
  }
  /* We have a result: the returned action... */
  result = Tcl_GetObjResult(interp); Tcl_IncrRefCount(result);
  status = Tcl_GetIndexFromObj(interp, result, (const char **) DropActions,
                               "dropactions", 0, &index);
  Tcl_DecrRefCount(result);
  if (status != TCL_OK) index = NoReturnedAction;
  switch ((enum dropactions) index) {
    case NoReturnedAction:
    case ActionDefault:
    case ActionCopy:
    case ActionMove:
    case ActionAsk:
    case ActionPrivate:
    case ActionLink:
      return YES;
    case refuse_drop: {
      return NO; /* Refuse drop. */
    }
  }
  return YES;
}; /* performDragOperation */

/*
 * Standard Cocoa method for handling drop operation
 * Calls tkdnd::macdnd::_HandleXdndDrop
 */
- (void)draggingExited:(id < NSDraggingInfo >)sender {
  TkWindow *winPtr   = TkMacOSXGetTkWindow([self window]);
  Tk_Window tkwin    = (Tk_Window) winPtr;
  Tcl_Interp *interp = Tk_Interp(tkwin);
  sourcePasteBoard   = [sender draggingPasteboard];

  Tcl_Obj* objv[4];
  int i;

  objv[0] = Tcl_NewStringObj("tkdnd::macdnd::_HandleLeave", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(tkwin), -1);
  objv[2] = Tcl_NewLongObj(0);
  objv[3] = Tcl_NewListObj(0, NULL);

  /* Evaluate the command and get the result...*/
  TkDND_Eval(4);
}; /* draggingExited */

@end

//Register add Cocoa subview to serve as drop target; register dragged data types
int TkDND_RegisterDragWidgetObjCmd(ClientData clientData, Tcl_Interp *ip,
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
}; /* TkDND_RegisterDragWidgetObjCmd */

//unregister the drag widget
int TkDND_UnregisterDragWidgetObjCmd(ClientData clientData, Tcl_Interp *ip,
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
}; /* TkDND_UnregisterDragWidgetObjCmd */

//initalize the package in the tcl interpreter, create tcl commands
int Tkdnd_Init (Tcl_Interp *interp) {

  // set up an autorelease pool
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  if (Tcl_InitStubs(interp, "8.5", 0) == NULL) {
    return TCL_ERROR;
  }


  if (Tk_InitStubs(interp, "8.5", 0) == NULL) {
    return TCL_ERROR;
  }

  Tcl_CreateObjCommand(interp, "::macdnd::registerdragwidget",
      TkDND_RegisterDragWidgetObjCmd,
      (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
  Tcl_CreateObjCommand(interp, "::macdnd::unregisterdragwidget",
      TkDND_UnregisterDragWidgetObjCmd,
      (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
  Tcl_CreateObjCommand(interp, "::macdnd::dodragdrop",
      TkDND_DoDragDropObjCmd,
      (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);

  if (Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
    return TCL_ERROR;
  }

  //release memory
  [pool release];

  return TCL_OK;
}; /* Tkdnd_Init */

int Tkdnd_SafeInit(Tcl_Interp *ip) {
  return Tkdnd_Init(ip);
}; /* Tkdnd_SafeInit */
