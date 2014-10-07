/*
 * macdnd.m --
 *
 *        This module implements drag and drop for Mac OS X.
 *
 * Copyright (c) 2009-2010 Kevin Walzer/WordTech Communications LLC.
 * Copyright (c) 2009-2010 Daniel A. Steffen <das@users.sourceforge.net>
 * Copyright (c) 2009-2010 Georgios P. Petasis <petasis@iit.demokritos.gr>
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

#pragma clang diagnostic ignored "-Warc-bridge-casts-disallowed-in-nonarc"
#if 0
// not using clang LLVM compiler, or LLVM version is not 3.x
#if !defined(__clang__) || __clang_major__ < 3

#ifndef __bridge
#define __bridge
#endif
#ifndef __bridge_retained
#define __bridge_retained
#endif
#ifndef __bridge_transfer
#define __bridge_transfer
#endif
#ifndef __autoreleasing
#define __autoreleasing
#endif
#ifndef __strong
#define __strong
#endif
#ifndef __weak
#define __weak
#endif
#ifndef __unsafe_unretained
#define __unsafe_unretained
#endif

#endif

#endif // __clang_major__ < 3

#define TKDND_OSX_KEVIN_WORKARROUND

#define TkDND_Tag    1234

#define TkDND_TkWin(x)                                                  \
  (Tk_NameToWindow(interp, Tcl_GetString(x), Tk_MainWindow(interp)))

#define TkDND_Eval(objc)                                                \
  for (i=0; i<objc; ++i) Tcl_IncrRefCount(objv[i]);                     \
  if (Tcl_EvalObjv(interp, objc, objv, TCL_EVAL_GLOBAL) != TCL_OK)      \
    Tk_BackgroundError(interp);                                         \
  for (i=0; i<objc; ++i) Tcl_DecrRefCount(objv[i]);

#define TkDND_Status_Eval(objc)                                         \
  for (i=0; i<objc; ++i) Tcl_IncrRefCount(objv[i]);                     \
  status = Tcl_EvalObjv(interp, objc, objv, TCL_EVAL_GLOBAL);           \
  if (status != TCL_OK) Tk_BackgroundError(interp);                     \
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
//  NSDragOperation sourceDragMask;
//  NSPasteboard   *sourcePasteBoard;
//  NSMutableArray *draggedtypes;
  NSInteger       tag;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender;
- (int)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
- (void)setTag:(NSInteger) t;
- (NSInteger)tag;
Tk_Window TkMacOSXGetTkWindow(NSWindow *w);
DNDView*  TkDND_GetDNDSubview(NSView *view, Tk_Window tkwin);
@end

@implementation DNDView

- (void)setTag:(NSInteger) t {
  tag = t;
}; /* setTag */

- (NSInteger)tag {
  return tag;
}; /* tag */

/*
 * Ripped from Tk-Cocoa source code to map Tk window to Cocoa window
 */
Tk_Window TkMacOSXGetTkWindow(NSWindow *w) {
  Window window = TkMacOSXGetXWindow((__bridge void*)w);
  TkDisplay *dispPtr = TkGetDisplayList();

  return (window != None ? Tk_IdToWindow(dispPtr->display, window) : NULL);
}; /* TkMacOSXGetTkWindow */

/*
 * TkDND_GetDNDSubview: returns the subview of type DNDView.
 * If such a view does not exist in the provided view, a new one is
 * added, and returned.
 */
DNDView* TkDND_GetDNDSubview(NSView *view, Tk_Window tkwin) {
  NSRect frame, bounds;
  DNDView* dnd_view = [view viewWithTag:TkDND_Tag];
#ifdef TKDND_OSX_KEVIN_WORKARROUND
  Rect bnds;
#endif /* TKDND_OSX_KEVIN_WORKARROUND */

  if (dnd_view == nil) {
    dnd_view = [[DNDView alloc] init];
    [dnd_view setTag:TkDND_Tag];
    [dnd_view mouseDown:NULL];
    if ([dnd_view superview] != view) {
      [view addSubview:dnd_view positioned:NSWindowBelow relativeTo:nil];
    }
    [view setAutoresizesSubviews:true];
    /*
     * Bug fix by Kevin Walzer: On 23 Dec 2010, Kevin reported that he has
     * found cases where the code below is needed, in order for DnD to work
     * correctly under Snow Leopard 10.6. So, I am restoring it...
     */
#ifdef TKDND_OSX_KEVIN_WORKARROUND
    /* Hack to make sure subview is set to take up entire geometry of window. */
    TkMacOSXWinBounds((TkWindow*)tkwin, &bnds);
    frame = NSMakeRect(bnds.left, bnds.top, 100000, 100000);
    frame.origin.y = 0;
    if (!NSEqualRects(frame, [dnd_view frame])) {
      [dnd_view setFrame:frame];
    }
#endif /* TKDND_OSX_KEVIN_WORKARROUND */
  }

#ifndef TKDND_OSX_KEVIN_WORKARROUND
  if (dnd_view == nil) return dnd_view;

  /* Ensure that we have the correct geometry... */
  frame = [view frame];
  if (!NSEqualRects(frame, [dnd_view frame])) {
    [dnd_view setFrame:frame];
  }

  bounds = [view bounds];
  if (!NSEqualRects(bounds, [dnd_view bounds])) {
    [dnd_view setBounds:bounds];
  }
#endif /* TKDND_OSX_KEVIN_WORKARROUND */
  return dnd_view;
}; /* TkDND_GetDNDSubview */

/* Set flags for local DND operations, i.e. dragging within a single
   application window.*/
- (int)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
  if (isLocal) return NSDragOperationCopy;
  return NSDragOperationCopy|NSDragOperationMove|NSDragOperationLink;
}

/*
 * Convert from strings to OS X type NSString objects...
 */
const NSString *TKDND_Obj2NSString(Tcl_Interp *interp, Tcl_Obj *obj) {
  int index, status;
  NSString *str = NULL;
  static char *OSXTypes[] = {
    /* OS X v10.6 and later */
    "NSPasteboardTypeString",
    "NSPasteboardTypePDF",
    "NSPasteboardTypeTIFF",
    "NSPasteboardTypePNG",
    "NSPasteboardTypeRTF",
    "NSPasteboardTypeRTFD",
    "NSPasteboardTypeHTML",
    "NSPasteboardTypeTabularText",
    "NSPasteboardTypeFont",
    "NSPasteboardTypeRuler",
    "NSPasteboardTypeColor",
    "NSPasteboardTypeSound",
    "NSPasteboardTypeMultipleTextSelection",
    "NSPasteboardTypeFindPanelSearchOptions",
    /* OS X v10.5 and earlier */
    "NSStringPboardType",
    "NSFilenamesPboardType",
    "NSPostScriptPboardType",
    "NSTIFFPboardType",
    "NSRTFPboardType",
    "NSTabularTextPboardType",
    "NSFontPboardType",
    "NSRulerPboardType",
    "NSFileContentsPboardType",
    "NSColorPboardType",
    "NSRTFDPboardType",
    "NSHTMLPboardType",
    "NSURLPboardType",
    "NSPDFPboardType",
    "NSVCardPboardType",
    "NSFilesPromisePboardType",
    "NSMultipleTextSelectionPboardType",
    (char *) NULL
  };
  enum osxtypes {
    /* OS X v10.6 and later */
    TYPE_NSPasteboardTypeString,
    TYPE_NSPasteboardTypePDF,
    TYPE_NSPasteboardTypeTIFF,
    TYPE_NSPasteboardTypePNG,
    TYPE_NSPasteboardTypeRTF,
    TYPE_NSPasteboardTypeRTFD,
    TYPE_NSPasteboardTypeHTML,
    TYPE_NSPasteboardTypeTabularText,
    TYPE_NSPasteboardTypeFont,
    TYPE_NSPasteboardTypeRuler,
    TYPE_NSPasteboardTypeColor,
    TYPE_NSPasteboardTypeSound,
    TYPE_NSPasteboardTypeMultipleTextSelection,
    TYPE_NSPasteboardTypeFindPanelSearchOptions,
    /* OS X v10.5 and earlier */
    TYPE_NSStringPboardType,
    TYPE_NSFilenamesPboardType,
    TYPE_NSPostScriptPboardType,
    TYPE_NSTIFFPboardType,
    TYPE_NSRTFPboardType,
    TYPE_NSTabularTextPboardType,
    TYPE_NSFontPboardType,
    TYPE_NSRulerPboardType,
    TYPE_NSFileContentsPboardType,
    TYPE_NSColorPboardType,
    TYPE_NSRTFDPboardType,
    TYPE_NSHTMLPboardType,
    TYPE_NSURLPboardType,
    TYPE_NSPDFPboardType,
    TYPE_NSVCardPboardType,
    TYPE_NSFilesPromisePboardType,
    TYPE_NSMultipleTextSelectionPboardType,
  };
  status = Tcl_GetIndexFromObj(interp, obj, (const char **) OSXTypes,
                                 "osxtypes", 0, &index);
  if (status != TCL_OK) return NULL;
  switch ((enum osxtypes) index) {
    case TYPE_NSPasteboardTypeString:                 {str = NSPasteboardTypeString                ; break;}
    case TYPE_NSPasteboardTypePDF:                    {str = NSPasteboardTypePDF                   ; break;}
    case TYPE_NSPasteboardTypeTIFF:                   {str = NSPasteboardTypeTIFF                  ; break;}
    case TYPE_NSPasteboardTypePNG:                    {str = NSPasteboardTypePNG                   ; break;}
    case TYPE_NSPasteboardTypeRTF:                    {str = NSPasteboardTypeRTF                   ; break;}
    case TYPE_NSPasteboardTypeRTFD:                   {str = NSPasteboardTypeRTFD                  ; break;}
    case TYPE_NSPasteboardTypeHTML:                   {str = NSPasteboardTypeHTML                  ; break;}
    case TYPE_NSPasteboardTypeTabularText:            {str = NSPasteboardTypeTabularText           ; break;}
    case TYPE_NSPasteboardTypeFont:                   {str = NSPasteboardTypeFont                  ; break;}
    case TYPE_NSPasteboardTypeRuler:                  {str = NSPasteboardTypeRuler                 ; break;}
    case TYPE_NSPasteboardTypeColor:                  {str = NSPasteboardTypeColor                 ; break;}
    case TYPE_NSPasteboardTypeSound:                  {str = NSPasteboardTypeSound                 ; break;}
    case TYPE_NSPasteboardTypeMultipleTextSelection:  {str = NSPasteboardTypeMultipleTextSelection ; break;}
    case TYPE_NSPasteboardTypeFindPanelSearchOptions: {str = NSPasteboardTypeFindPanelSearchOptions; break;}
    case TYPE_NSStringPboardType:                     {str = NSStringPboardType                    ; break;}
    case TYPE_NSFilenamesPboardType:                  {str = NSFilenamesPboardType                 ; break;}
    case TYPE_NSPostScriptPboardType:                 {str = NSPostScriptPboardType                ; break;}
    case TYPE_NSTIFFPboardType:                       {str = NSTIFFPboardType                      ; break;}
    case TYPE_NSRTFPboardType:                        {str = NSRTFPboardType                       ; break;}
    case TYPE_NSTabularTextPboardType:                {str = NSTabularTextPboardType               ; break;}
    case TYPE_NSFontPboardType:                       {str = NSFontPboardType                      ; break;}
    case TYPE_NSRulerPboardType:                      {str = NSRulerPboardType                     ; break;}
    case TYPE_NSFileContentsPboardType:               {str = NSFileContentsPboardType              ; break;}
    case TYPE_NSColorPboardType:                      {str = NSColorPboardType                     ; break;}
    case TYPE_NSRTFDPboardType:                       {str = NSRTFDPboardType                      ; break;}
    case TYPE_NSHTMLPboardType:                       {str = NSHTMLPboardType                      ; break;}
    case TYPE_NSURLPboardType:                        {str = NSURLPboardType                       ; break;}
    case TYPE_NSPDFPboardType:                        {str = NSPDFPboardType                       ; break;}
    case TYPE_NSVCardPboardType:                      {str = NSVCardPboardType                     ; break;}
    case TYPE_NSFilesPromisePboardType:               {str = NSFilesPromisePboardType              ; break;}
    case TYPE_NSMultipleTextSelectionPboardType:      {str = NSMultipleTextSelectionPboardType     ; break;}
  }
  return str;
}; /* TKDND_Obj2NSString */

/*******************************************************************************
 *******************************************************************************
 ***** Drop Target Operations                                              *****
 *******************************************************************************
 *******************************************************************************/

/*
 * Standard Cocoa method for entering drop target;
 * Calls ::tkdnd::macdnd::HandleEnter
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

  Tk_Window     tkwin            = TkMacOSXGetTkWindow([self window]);
  Tcl_Interp   *interp           = Tk_Interp(tkwin);
  NSPasteboard *sourcePasteBoard = [sender draggingPasteboard];

  Tcl_Obj* objv[4], *element, *result;
  int i, index, status;

  objv[0] = Tcl_NewStringObj("::tkdnd::macdnd::HandleEnter", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(tkwin), -1);
  objv[2] = Tcl_NewLongObj(0);
  objv[3] = Tcl_NewListObj(0, NULL);
  /*
   * Search for known types...
   */
  if ([[sourcePasteBoard types] containsObject:NSPasteboardTypeString]) {
    element = Tcl_NewStringObj("NSPasteboardTypeString", -1);
    Tcl_ListObjAppendElement(NULL, objv[3], element);
  }
  if ([[sourcePasteBoard types] containsObject:NSPasteboardTypeHTML]) {
    element = Tcl_NewStringObj("NSPasteboardTypeHTML", -1);
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

  Tk_Window     tkwin            = TkMacOSXGetTkWindow([self window]);
  Tcl_Interp   *interp           = Tk_Interp(tkwin);
  NSPasteboard *sourcePasteBoard = [sender draggingPasteboard];
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

  objv[0] = Tcl_NewStringObj("::tkdnd::macdnd::HandlePosition", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(mouse_tkwin), -1);
  objv[2] = Tcl_NewIntObj(rootX);
  objv[3] = Tcl_NewIntObj(tk_Y);

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
  // sourcePasteBoard = [sender draggingPasteboard];
  return YES;
}; /* prepareForDragOperation */

/*
 * Standard Cocoa method for handling drop operation
 * Calls ::tkdnd::macdnd::HandleDrop
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
  Tk_Window     tkwin            = TkMacOSXGetTkWindow([self window]);
  Tcl_Interp   *interp           = Tk_Interp(tkwin);
  NSPasteboard *sourcePasteBoard = [sender draggingPasteboard];
  Tcl_Obj *data      = NULL;
  Tcl_Obj* objv[3], **elem, *result;
  int i, index, status, elem_nu;
  const NSString *type;

  /* Retrieve the common types, as prefered by the drag source... */
  objv[0] = Tcl_NewStringObj("::tkdnd::macdnd::GetDragSourceCommonTypes", -1);
  /* Evaluate the command and get the result...*/
  TkDND_Status_Eval(1);
  //  printf("Status=%d (%d)\n", status, TCL_OK);fflush(0);
  if (status != TCL_OK) {
    /* An error has happened. Cancel the drop! */
    return NO;
  }
  result = Tcl_GetObjResult(interp); Tcl_IncrRefCount(result);
  status = Tcl_ListObjGetElements(interp, result, &elem_nu, &elem);
  if (status != TCL_OK) {
    Tcl_DecrRefCount(result);
    return NO;
  }

#if 0
  /* Print what exists in the clipboard... */
  i = 0;
  for (NSPasteboardItem *item in [sourcePasteBoard pasteboardItems]) {
    for (NSString *type in [item types]) {
      printf("item %d: type: %s\n", i++, [type UTF8String]);
    }
  }
  /* Print what we can accept... */
  for (int j = 0; j < elem_nu; ++j) {
    printf("accept: %s\n", Tcl_GetString(elem[j]));
  }
#endif

  /* Retrieve data from clipboard, checking all items... */
  for (int j = 0; j < elem_nu; ++j) {
    type = TKDND_Obj2NSString(interp, elem[j]);
    if ([type isEqualToString:NSPasteboardTypeString]) {
      /* String type... */
      for (NSPasteboardItem *item in [sourcePasteBoard pasteboardItems]) {
        NSString *pasteboardvalue = [item stringForType:NSPasteboardTypeString];
        if (pasteboardvalue) {
          data = Tcl_NewStringObj([pasteboardvalue UTF8String], -1);
          break;
        }
      }
    } else if ([type isEqualToString:NSFilenamesPboardType]) {
      /* Filenames array... */
      NSArray *files = [sourcePasteBoard propertyListForType:NSFilenamesPboardType];
      if (files) {
        Tcl_Obj *element;
        data = Tcl_NewListObj(0, NULL);
        for (NSString *filename in files) {
          element = Tcl_NewStringObj([filename UTF8String], -1);
          if (element == NULL) continue;
          Tcl_ListObjAppendElement(interp, data, element);
        }
      }
    } else if ([type isEqualToString:NSPasteboardTypeHTML]) {
      /* HTML ... */
      for (NSPasteboardItem *item in [sourcePasteBoard pasteboardItems]) {
        NSString *pasteboardvalue = [item stringForType:NSPasteboardTypeHTML];
        if (pasteboardvalue) {
          data = Tcl_NewStringObj([pasteboardvalue UTF8String], -1);
          break;
        }
      }
    }

    if (data != NULL) break;
  }
  Tcl_DecrRefCount(result);
  if (data == NULL) data = Tcl_NewStringObj(NULL, 0);

  objv[0] = Tcl_NewStringObj("::tkdnd::macdnd::HandleDrop", -1);
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
 * Calls ::tkdnd::macdnd::HandleXdndDrop
 */
- (void)draggingExited:(id < NSDraggingInfo >)sender {
  Tk_Window tkwin    = TkMacOSXGetTkWindow([self window]);
  Tcl_Interp *interp = Tk_Interp(tkwin);

  Tcl_Obj* objv[4];
  int i;

  objv[0] = Tcl_NewStringObj("::tkdnd::macdnd::HandleLeave", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(tkwin), -1);
  objv[2] = Tcl_NewLongObj(0);
  objv[3] = Tcl_NewListObj(0, NULL);

  /* Evaluate the command and get the result...*/
  TkDND_Eval(4);
}; /* draggingExited */

@end

/*
 * End Cocoa class methods: now we begin Tcl functions calling the class methods
 */

/******************************************************************************
 ******************************************************************************
 ***** Drag Source Operations                                             *****
 ******************************************************************************
 ******************************************************************************/

/*
 * Implements drag source in Tk windows
 */
int TkDND_DoDragDropObjCmd(ClientData clientData, Tcl_Interp *interp,
                           int objc, Tcl_Obj *CONST objv[]) {
  Tcl_Obj         **elem, **data_elem, **files_elem;
  int               actions = 0;
  int               status, elem_nu, data_elem_nu, files_elem_nu, i, j, index;
  Tk_Window         path;
  Drawable          d;
  NSView           *view;
  DNDView          *dragview;
  NSImage          *dragicon = NULL;
  static char *DropTypes[] = {
    "NSPasteboardTypeString", "NSPasteboardTypeHTML", "NSFilenamesPboardType",
    (char *) NULL
  };
  enum droptypes {
    TYPE_NSPasteboardTypeString, TYPE_NSPasteboardTypeHTML, TYPE_NSFilenamesPboardType
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
  bool added_string = false, added_filenames = false, added_html = false,
       perform_drag = false;

  if (objc != 6) {
    Tcl_WrongNumArgs(interp, 1, objv, "path actions types data button");
    return TCL_ERROR;
  }
  Tcl_ResetResult(interp);

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
  path = Tk_NameToWindow(interp, Tcl_GetString(objv[1]), Tk_MainWindow(interp));
  if (path == NULL) return TCL_ERROR;
  d = Tk_WindowId(path);
  if (d == None) return TCL_ERROR;
  /* Get the NSView from Tk window and add subview to serve as drag source */
  view     = (__bridge NSView *) TkMacOSXGetRootControl(d);
  if (view == NULL) return TCL_ERROR;
  /* Get the DNDview for this view... */
  dragview = TkDND_GetDNDSubview(view, path);
  if (dragview == NULL) return TCL_ERROR;

  /* Process drag types. */
  status = Tcl_ListObjGetElements(interp, objv[3], &elem_nu, &elem);
  if (status != TCL_OK) return status;
  /* objv[4] contains a list, one element for each data drag type... */
  status = Tcl_ListObjGetElements(interp, objv[4], &data_elem_nu, &data_elem);
  if (status != TCL_OK) return status;
  if (elem_nu != data_elem_nu) {
    /* This can never happen... */
    return TCL_ERROR;
  }

  /* Initialize array of drag types... */
  NSMutableArray *draggedtypes=[[[NSMutableArray alloc] init] autorelease];
  /* Iterate over all data, to collect the types... */
  for (i = 0; i < elem_nu; i++) {
    status = Tcl_GetIndexFromObj(interp, elem[i], (const char **) DropTypes,
                                 "droptypes", 0, &index);
    if (status != TCL_OK) continue;
    switch ((enum droptypes) index) {
      case TYPE_NSPasteboardTypeHTML: {
        if (!added_html) {
          // [draggedtypes addObject: NSPasteboardTypeString];
          added_html   = true;
          perform_drag = true;
        }
        break;
      }
      case TYPE_NSPasteboardTypeString: {
        if (!added_string) {
          // [draggedtypes addObject: NSPasteboardTypeString];
          added_string = true;
          perform_drag = true;
        }
        break;
      }
      case TYPE_NSFilenamesPboardType: {
        if (!added_filenames) {
          [draggedtypes addObject: NSFilenamesPboardType];
          added_filenames = true;
          perform_drag    = true;
        }
        break;
      }
    }
  }

  if (!perform_drag) {
    /* No need to start a drag, the clipboard will be empty... */
    Tcl_SetResult(interp, "refuse_drop", TCL_STATIC);
    return TCL_OK;
  }

  /*
   * Get pasteboard. Make sure it is NSDragPboard; this will make data available
   * to drop targets via [sender draggingPasteboard]
   */
  NSPasteboard *dragpasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSMutableArray *dataitems    = [[[NSMutableArray alloc] init] autorelease];
  NSMutableArray *filelist     = [[[NSMutableArray alloc] init] autorelease];
  [dragpasteboard clearContents];

  if (added_filenames) {
    /* There is a request about deprecated NSFilenamesPboardType. The only way to
       use it, is through setPropertyList:forType, which operates only on the first
       item. So, call declareTypes, to create this first item... */
    //[dragpasteboard declareTypes:draggedtypes owner:dragview];
    NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
    [dataitems addObject: item];
  }

  /*
   * We need an icon for the drag:
   * Interate over data types to process dragged data and display
   * the correct drag icon.
   */
  for (i = 0; i < elem_nu; i++) {
    status = Tcl_GetIndexFromObj(interp, elem[i], (const char **) DropTypes,
                                 "droptypes", 0, &index);
    if (status == TCL_OK) {
      switch ((enum droptypes) index) {
        case TYPE_NSPasteboardTypeString: {
          /* Place the string into the clipboard. */
          NSString *datastring =
             [NSString stringWithUTF8String:Tcl_GetString(data_elem[i])];
          NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
          [item setString:datastring forType:NSPasteboardTypeString];
          [dataitems addObject: item];
          //[dragpasteboard writeObjects:[NSArray arrayWithObject:item]];
          //[dragpasteboard setString:datastring forType:NSPasteboardTypeString];

          /* Create a custom icon: draw dragged string into drag icon,
           * make sure icon is large enough to contain several lines of text */
          if (dragicon == NULL) {
            dragicon = [[NSImage alloc]
              initWithSize:NSMakeSize(Tk_Width(path), Tk_Height(path))];
            [dragicon lockFocus];
            [[NSColor clearColor] set];
            NSRectFill(NSMakeRect(0, 0, 1000,1000));
            [datastring drawAtPoint: NSZeroPoint withAttributes: nil];
            [dragicon unlockFocus];
          }
          break;
        }
        case TYPE_NSPasteboardTypeHTML: {
          /* Place HTML into the clipboard. */
          NSString *datastring =
             [NSString stringWithUTF8String:Tcl_GetString(data_elem[i])];
          NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
          [item setString:datastring forType:NSPasteboardTypeHTML];
          [dataitems addObject: item];

          /* Create a custom icon: draw dragged string into drag icon,
           * make sure icon is large enough to contain several lines of text */
          if (dragicon == NULL) {
            dragicon = [[NSImage alloc]
              initWithSize:NSMakeSize(Tk_Width(path), Tk_Height(path))];
            [dragicon lockFocus];
            [[NSColor clearColor] set];
            NSRectFill(NSMakeRect(0, 0, 1000,1000));
            [datastring drawAtPoint: NSZeroPoint withAttributes: nil];
            [dragicon unlockFocus];
          }
          break;
        }
        case TYPE_NSFilenamesPboardType: {

          /* Place the filenames into the clipboard. */
          status = Tcl_ListObjGetElements(interp, data_elem[i],
                                          &files_elem_nu, &files_elem);
          if ( status == TCL_OK) {
            for (j = 0; j < files_elem_nu; j++) {
              /* Get string value of file name from list */
              char* filename = Tcl_GetString(files_elem[j]);
              /* Convert file names to NSSString, add to NSMutableArray,
               * and set pasteboard type */
              NSString *filestring = [NSString stringWithUTF8String:filename];
              [filelist addObject: /*[NSURL fileURLWithPath:*/ filestring] /*]*/;
            }
          }
          /* This successfully writes the file path data to the clipboard,
           * and it is available to other non-Tk applications... */
          // [dragpasteboard writeObjects: filelist];
          // [dragpasteboard setPropertyList:filelist forType:NSFilenamesPboardType];

          /* Set the correct icon depending on whether a single file
           * [iconForFileType] or multiple files [NSImageNameMultipleDocuments]
           * have been placed into the clipboard... */
          if (dragicon == NULL) {
            if ([filelist count] == 1) {
              NSString *pathtype = [[filelist objectAtIndex:0] pathExtension];
              dragicon = [[NSWorkspace sharedWorkspace]
                                       iconForFileType:pathtype];
            } else {
              dragicon = [NSImage imageNamed:NSImageNameMultipleDocuments];
            }
          }
          break;
        }
      }
    } else {
      /* An unknown (or user defined) type. Silently skip it... */
    }
  }
  [dragpasteboard writeObjects: dataitems];
  if (added_filenames) {
    [dragpasteboard setPropertyList:filelist forType:NSFilenamesPboardType];
  }

  /* Do drag & drop... */

  /* Ensure that we always have a drag icon. If not, use a default one... */
  if (dragicon == NULL) {
    dragicon = [NSImage imageNamed:NSImageNameIconViewTemplate];
  }

  NSSize dragOffset = NSMakeSize(0.0, 0.0);

  /* Get the mouse coordinates, so as the icon can slide back at the correct
   * location, if the drag is cancelled. */
  NSPoint global         = [NSEvent mouseLocation];
  NSPoint imageLocation  = [[dragview window] convertScreenToBase:global];
  NSEvent *event = [NSEvent mouseEventWithType:NSLeftMouseDragged
                                      location:imageLocation
                                 modifierFlags:NSLeftMouseDownMask
                                     timestamp:0
                                  windowNumber:[[dragview window] windowNumber]
                                       context:NULL
                                   eventNumber:0
                                    clickCount:0
                                      pressure:0];

  /* Initiate the drag operation... */
  [dragview dragImage:dragicon
                   at:imageLocation
               offset:dragOffset
                event:event
           pasteboard:dragpasteboard
               source:dragview
            slideBack:YES];

  /* Get the drop action... */

  /* There is no way we can know the drag action! */
  Tcl_SetResult(interp, "copy", TCL_STATIC);
  return TCL_OK;
}; /* TkDND_DoDragDropObjCmd */

/*
 * Register: add a Cocoa subview to serve as drop target;
 *           register dragged data types
 */
int TkDND_RegisterDragWidgetObjCmd(ClientData clientData, Tcl_Interp *ip,
                                   int objc, Tcl_Obj *CONST objv[]) {
  Tcl_Obj **type;
  int typec, i, len;
  char *str;
  bool added_string = false, added_filenames = false, added_html = false;

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

  /* Get window information for drop target... */
  Tk_Window path;
  path = Tk_NameToWindow(ip, Tcl_GetString(objv[1]), Tk_MainWindow(ip));
  if (path == NULL) return TCL_ERROR;

  Tk_MakeWindowExist(path);
  Tk_MapWindow(path);
  Drawable d = Tk_WindowId(path);

  /* Get NSView from Tk window and add subview to serve as drop target */
  NSView  *view = (__bridge NSView *) TkMacOSXGetRootControl(d);
  DNDView *dropview  = TkDND_GetDNDSubview(view, path);
  if (dropview == NULL) return TCL_ERROR;

  /* Initialize array of drag types */
  NSMutableArray *draggedtypes=[[NSMutableArray alloc] init];

  /*
   * Iterate over all requested types...
   */
  for (i = 0; i < typec; ++i) {
    str = Tcl_GetStringFromObj(type[i], &len);
    if (strncmp(str, "*", len) == 0) {
      /* A request for all available types... */
      if (!added_string) {
        [draggedtypes addObject: NSPasteboardTypeString];
        added_string = true;
      }
      if (!added_filenames) {
        [draggedtypes addObject: NSFilenamesPboardType];
        added_filenames = true;
      }
      if (!added_html) {
        [draggedtypes addObject: NSPasteboardTypeHTML];
        added_html = true;
      }
    } else if (strncmp(str, "NSPasteboardTypeString", len) == 0) {
      if (!added_string) {
        [draggedtypes addObject: NSPasteboardTypeString];
        added_string = true;
      }
    } else if (strncmp(str, "NSPasteboardTypeHTML", len) == 0) {
      if (!added_html) {
        [draggedtypes addObject: NSPasteboardTypeHTML];
        added_html = true;
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

  /* Finally, register the drag types... */
  [dropview registerForDraggedTypes:draggedtypes];

  return TCL_OK;
}; /* TkDND_RegisterDragWidgetObjCmd */

/* Unregister the drag widget */
int TkDND_UnregisterDragWidgetObjCmd(ClientData clientData, Tcl_Interp *ip,
                                     int objc, Tcl_Obj *CONST objv[]) {
  if (objc != 2) {
    Tcl_WrongNumArgs(ip, 1, objv, "path");
    return TCL_ERROR;
  }

  /* Get NSView from TK window... */
  Tk_Window path = Tk_NameToWindow(ip, Tcl_GetString(objv[1]),
                                       Tk_MainWindow(ip));

  if (path == NULL) return TCL_ERROR;

  Drawable d         = Tk_WindowId(path);
  NSView  *view      = (__bridge NSView *) TkMacOSXGetRootControl(d);
  DNDView *dropview  = TkDND_GetDNDSubview(view, path);
  if (dropview == NULL) return TCL_ERROR;
  [dropview unregisterDraggedTypes];

  return TCL_OK;
}; /* TkDND_UnregisterDragWidgetObjCmd */

/* Convert OS X types to strings... */
int TkDND_Type2StringObjCmd(ClientData clientData, Tcl_Interp *interp,
                             int objc, Tcl_Obj *CONST objv[]) {
  const NSString *str;
  if (objc != 2) {
    Tcl_WrongNumArgs(interp, 1, objv, "type");
    return TCL_ERROR;
  }
  str = TKDND_Obj2NSString(interp, objv[1]);
  if (str == NULL) return TCL_ERROR;
  Tcl_SetObjResult(interp, Tcl_NewStringObj([str UTF8String], -1));
  return TCL_OK;
}; /* TkDND_Type2StringObjCmd */

/*
 * Initalize the package in the tcl interpreter, create tcl commands...
 */
int Tkdnd_Init (Tcl_Interp *interp) {

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
  Tcl_CreateObjCommand(interp, "::macdnd::osxtype2string",
                       TkDND_Type2StringObjCmd,
                       (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);

  if (Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
    return TCL_ERROR;
  }

  return TCL_OK;
}; /* Tkdnd_Init */

int Tkdnd_SafeInit(Tcl_Interp *ip) {
  return Tkdnd_Init(ip);
}; /* Tkdnd_SafeInit */
