/*
 * TkDND_XDND.h -- Tk XDND Drag'n'Drop Protocol Implementation
 * 
 *    This file implements the unix portion of the drag&drop mechanism
 *    for the tk toolkit. The protocol in use under unix is the
 *    XDND protocol.
 *
 * This software is copyrighted by:
 * Georgios Petasis, Athens, Greece.
 * e-mail: petasisg@yahoo.gr, petasis@iit.demokritos.gr
 *
 * The following terms apply to all files associated
 * with the software unless explicitly disclaimed in individual files.
 *
 * The authors hereby grant permission to use, copy, modify, distribute,
 * and license this software and its documentation for any purpose, provided
 * that existing copyright notices are retained in all copies and that this
 * notice is included verbatim in any distributions. No written agreement,
 * license, or royalty fee is required for any of the authorized uses.
 * Modifications to this software may be copyrighted by their authors
 * and need not follow the licensing terms described here, provided that
 * the new terms are clearly indicated on the first page of each file where
 * they apply.
 * 
 * IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
 * FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
 * ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
 * DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
 * IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
 * NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
 * MODIFICATIONS.
 */
#include "tcl.h"
#include "tk.h"
#include <string.h>
#include <X11/Xlib.h>
#include <X11/X.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>

#ifdef HAVE_LIMITS_H
#include "limits.h"
#else
#define LONG_MAX 0x7FFFFFFFL
#endif

/*
#define TKDND_SET_XDND_PROPERTY_ON_TARGET
#define TKDND_SET_XDND_PROPERTY_ON_WRAPPER
#define DEBUG_CLIENTMESSAGE_HANDLER
 */
#define TKDND_SET_XDND_PROPERTY_ON_TOPLEVEL

#define TkDND_TkWindowChildren(tkwin) \
    ((Tk_Window) (((Tk_FakeWin *) (tkwin))->dummy2))

#define TkDND_TkWindowLastChild(tkwin) \
    ((Tk_Window) (((Tk_FakeWin *) (tkwin))->dummy3))

#define TkDND_TkWin(x) \
  (Tk_NameToWindow(interp, Tcl_GetString(x), Tk_MainWindow(interp)))

#define TkDND_Eval(objc) \
  for (i=0; i<objc; ++i) Tcl_IncrRefCount(objv[i]);\
  if (Tcl_EvalObjv(interp, objc, objv, TCL_EVAL_GLOBAL) != TCL_OK) \
      Tk_BackgroundError(interp); \
  for (i=0; i<objc; ++i) Tcl_DecrRefCount(objv[i]);

#define TkDND_Status_Eval(objc) \
  for (i=0; i<objc; ++i) Tcl_IncrRefCount(objv[i]);\
  status = Tcl_EvalObjv(interp, objc, objv, TCL_EVAL_GLOBAL);\
  if (status != TCL_OK) Tk_BackgroundError(interp); \
  for (i=0; i<objc; ++i) Tcl_DecrRefCount(objv[i]);

#ifndef Tk_Interp
/*
 * Tk 8.5 has a new function to return the interpreter that is associated with a
 * window. Under 8.4 and earlier versions, simulate this function.
 */
#include "tkInt.h"
Tcl_Interp * TkDND_Interp(Tk_Window tkwin) {
  if (tkwin != NULL && ((TkWindow *)tkwin)->mainPtr != NULL) {
    return ((TkWindow *)tkwin)->mainPtr->interp;
  }
  return NULL;
} /* Tk_Interp */
#define Tk_Interp TkDND_Interp
#endif /* Tk_Interp */

/*
 * XDND Section
 */
#define XDND_VERSION 5

/* XdndEnter */
#define XDND_THREE 3
#define XDND_ENTER_SOURCE_WIN(e)        ((e)->xclient.data.l[0])
#define XDND_ENTER_THREE_TYPES(e)       (((e)->xclient.data.l[1] & 0x1UL) == 0)
#define XDND_ENTER_THREE_TYPES_SET(e,b) (e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~0x1UL) | (((b) == 0) ? 0 : 0x1UL)
#define XDND_ENTER_VERSION(e)           ((e)->xclient.data.l[1] >> 24)
#define XDND_ENTER_VERSION_SET(e,v)     (e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~(0xFF << 24)) | ((v) << 24)
#define XDND_ENTER_TYPE(e,i)            ((e)->xclient.data.l[2 + i])    /* i => (0, 1, 2) */

/* XdndPosition */
#define XDND_POSITION_SOURCE_WIN(e)     ((e)->xclient.data.l[0])
#define XDND_POSITION_ROOT_X(e)         ((e)->xclient.data.l[2] >> 16)
#define XDND_POSITION_ROOT_Y(e)         ((e)->xclient.data.l[2] & 0xFFFFUL)
#define XDND_POSITION_ROOT_SET(e,x,y)   (e)->xclient.data.l[2]  = ((x) << 16) | ((y) & 0xFFFFUL)
#define XDND_POSITION_TIME(e)           ((e)->xclient.data.l[3])
#define XDND_POSITION_ACTION(e)         ((e)->xclient.data.l[4])

/* XdndStatus */
#define XDND_STATUS_TARGET_WIN(e)       ((e)->xclient.data.l[0])
#define XDND_STATUS_WILL_ACCEPT(e)      ((e)->xclient.data.l[1] & 0x1L)
#define XDND_STATUS_WILL_ACCEPT_SET(e,b) (e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~0x1UL) | (((b) == 0) ? 0 : 0x1UL)
#define XDND_STATUS_WANT_POSITION(e)    ((e)->xclient.data.l[1] & 0x2UL)
#define XDND_STATUS_WANT_POSITION_SET(e,b) (e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~0x2UL) | (((b) == 0) ? 0 : 0x2UL)
#define XDND_STATUS_RECT_X(e)           ((e)->xclient.data.l[2] >> 16)
#define XDND_STATUS_RECT_Y(e)           ((e)->xclient.data.l[2] & 0xFFFFL)
#define XDND_STATUS_RECT_WIDTH(e)       ((e)->xclient.data.l[3] >> 16)
#define XDND_STATUS_RECT_HEIGHT(e)      ((e)->xclient.data.l[3] & 0xFFFFL)
#define XDND_STATUS_RECT_SET(e,x,y,w,h) {(e)->xclient.data.l[2] = ((x) << 16) | ((y) & 0xFFFFUL); (e)->xclient.data.l[3] = ((w) << 16) | ((h) & 0xFFFFUL); }
#define XDND_STATUS_ACTION(e)           ((e)->xclient.data.l[4])

/* XdndLeave */
#define XDND_LEAVE_SOURCE_WIN(e)        ((e)->xclient.data.l[0])

/* XdndDrop */
#define XDND_DROP_SOURCE_WIN(e)         ((e)->xclient.data.l[0])
#define XDND_DROP_TIME(e)               ((e)->xclient.data.l[2])

/* XdndFinished */
#define XDND_FINISHED_TARGET_WIN(e)     ((e)->xclient.data.l[0])
#define XDND_FINISHED_ACCEPTED(e)       ((e)->xclient.data.l[1] & 0x1L)
#define XDND_FINISHED_ACCEPTED_SET(e,b)  (e)->xclient.data.l[1] = ((e)->xclient.data.l[1] & ~0x1UL) | (((b) == 0) ? 0 : 0x1UL)
#define XDND_FINISHED_ACTION(e)           ((e)->xclient.data.l[2])


/*
 * Support for getting the wrapper window for our top-level...
 */

int TkDND_RegisterTypesObjCmd(ClientData clientData, Tcl_Interp *interp,
                              int objc, Tcl_Obj *CONST objv[]) {

  Atom version       = XDND_VERSION;
  Tk_Window path     = NULL;
  Tk_Window toplevel = NULL;

  if (objc != 4) {
    Tcl_WrongNumArgs(interp, 1, objv, "path toplevel types-list");
    return TCL_ERROR;
  }

  path     = TkDND_TkWin(objv[1]);
  Tk_MakeWindowExist(path);

#if defined(TKDND_SET_XDND_PROPERTY_ON_WRAPPER) || \
    defined(TKDND_SET_XDND_PROPERTY_ON_TOPLEVEL)
  toplevel = TkDND_TkWin(objv[2]);
  if (!Tk_IsTopLevel(toplevel)) {
    Tcl_ResetResult(interp);
    Tcl_AppendResult(interp, "path \"", Tcl_GetString(objv[2]),
                             "\" is not a toplevel window!", (char *) NULL);
    return TCL_ERROR;
  }
  Tk_MakeWindowExist(toplevel);
  Tk_MapWindow(toplevel);
#endif

  /*
   * We must make the toplevel that holds this widget XDND aware. This means
   * that we have to set the XdndAware property on our toplevel.
   */
#ifdef TKDND_SET_XDND_PROPERTY_ON_TARGET
  XChangeProperty(Tk_Display(path), Tk_WindowId(path),
                  Tk_InternAtom(path, "XdndAware"),
                  XA_ATOM, 32, PropModeReplace,
                  (unsigned char *) &version, 1);
#endif /* TKDND_SET_XDND_PROPERTY_ON_TARGET */

#ifdef TKDND_SET_XDND_PROPERTY_ON_WRAPPER
  if (Tk_HasWrapper(toplevel)) {
  }
#endif /* TKDND_SET_XDND_PROPERTY_ON_WRAPPER */

#ifdef TKDND_SET_XDND_PROPERTY_ON_TOPLEVEL
  Window root_return, parent, *children_return = 0;
  unsigned int nchildren_return;
  XQueryTree(Tk_Display(toplevel), Tk_WindowId(toplevel),
             &root_return, &parent,
             &children_return, &nchildren_return);
  if (children_return) XFree(children_return);
  XChangeProperty(Tk_Display(toplevel), parent,
                  Tk_InternAtom(toplevel, "XdndAware"),
                  XA_ATOM, 32, PropModeReplace,
                  (unsigned char *) &version, 1);
#endif /* TKDND_SET_XDND_PROPERTY_ON_TOPLEVEL */
  return TCL_OK;
} /* TkDND_RegisterTypesObjCmd */

int TkDND_HandleXdndEnter(Tk_Window tkwin, XEvent *xevent) {
  Tcl_Interp *interp = Tk_Interp(tkwin);
  Atom *typelist = NULL;
  int i, version = (int) XDND_ENTER_VERSION(xevent);
  Window drag_source;
  // Window drop_toplevel, drop_window;
  Tcl_Obj* objv[4], *element;

  if (interp == NULL) return False;
  if (version > XDND_VERSION) return False;
#if XDND_VERSION >= 3
  if (version < 3) return False;
#endif

//#if XDND_VERSION >= 3
//  /* XdndEnter is delivered to the toplevel window, which is the wrapper
//   *  window for the Tk toplevel. We don't yet know the sub-window the mouse
//   *  is in... */
//  drop_toplevel = xevent->xany.window;
//  drop_window   = 0;
//#else
//  drop_toplevel = 0
//  drop_window   = xevent->xany.window;
//#endif
  drag_source = XDND_ENTER_SOURCE_WIN(xevent);

  if (XDND_ENTER_THREE_TYPES(xevent)) {
    typelist = (Atom *) Tcl_Alloc(sizeof(Atom)*4);
    if (typelist == NULL) return False;
    typelist[0] = xevent->xclient.data.l[2];
    typelist[1] = xevent->xclient.data.l[3];
    typelist[2] = xevent->xclient.data.l[4];
    typelist[3] = None;
  } else {
    /* Get the types from XdndTypeList property. */
    Atom actualType = None;
    int actualFormat;
    unsigned long itemCount, remainingBytes;
    Atom *data;
    XGetWindowProperty(xevent->xclient.display, drag_source,
                       Tk_InternAtom(tkwin, "XdndTypeList"), 0,
                       LONG_MAX, False, XA_ATOM, &actualType, &actualFormat,
                       &itemCount, &remainingBytes, (unsigned char **) &data);
    typelist = (Atom *) Tcl_Alloc(sizeof(Atom)*(itemCount+1));
    if (typelist == NULL) return False;
    for (i=0; i<itemCount; i++) { typelist[i] = data[i]; }
    typelist[itemCount] = None;
    if (data) XFree((unsigned char*)data);
  }
  /* We have all the information we need. Its time to pass it at the Tcl
   * level.*/
  objv[0] = Tcl_NewStringObj("tkdnd::xdnd::_HandleXdndEnter", -1);
  objv[1] = Tcl_NewStringObj(Tk_PathName(tkwin), -1);
  objv[2] = Tcl_NewLongObj(drag_source);
  objv[3] = Tcl_NewListObj(0, NULL);
  for (i=0; typelist[i] != None; ++i) {
    element = Tcl_NewStringObj(Tk_GetAtomName(tkwin, typelist[i]), -1);
    Tcl_ListObjAppendElement(NULL, objv[3], element);
  }
  TkDND_Eval(4);
  Tcl_Free((char *) typelist);
  return True;
} /* TkDND_HandleXdndEnter */

int TkDND_HandleXdndPosition(Tk_Window tkwin, XEvent *xevent) {
  Tcl_Interp *interp = Tk_Interp(tkwin);
  Tk_Window mouse_tkwin;
  Tcl_Obj* result;
  Tcl_Obj* objv[4];
  int rootX, rootY, dx, dy, i, index, status;
  XEvent response;
  int width = 1, height = 1;
  static char *DropActions[] = {
    "copy", "move", "link", "ask",  "private", "refuse_drop", "default",
    (char *) NULL
  };
  enum dropactions {
    ActionCopy, ActionMove, ActionLink, ActionAsk, ActionPrivate,
    refuse_drop, ActionDefault
  };
  Time time;
  Atom action;

  if (interp == NULL) return False;

  /* Get the coordinates from the event... */
  rootX  = XDND_POSITION_ROOT_X(xevent);
  rootY  = XDND_POSITION_ROOT_Y(xevent);
  /* Get the time from the event... */
  time   = XDND_POSITION_TIME(xevent);
  /* Get the user action from the event... */
  action = XDND_POSITION_ACTION(xevent);

  /* Find the Tk widget under the mouse... */
  Tk_GetRootCoords(tkwin, &dx, &dy);
  mouse_tkwin = Tk_CoordsToWindow(rootX, rootY, tkwin);
  if (mouse_tkwin == NULL) {
    mouse_tkwin = Tk_CoordsToWindow(rootX + dx, rootY + dy, tkwin);
  }
#if 0
  printf("mouse_win: %p (%s) (%d, %d %p %s) i=%p\n", mouse_tkwin,
          mouse_tkwin?Tk_PathName(mouse_tkwin):"",
          rootX, rootY, tkwin, Tk_PathName(tkwin), interp);
#endif
  /* Ask the Tk widget whether it will accept the drop... */
  index = refuse_drop;
  if (mouse_tkwin != NULL) {
    objv[0] = Tcl_NewStringObj("tkdnd::xdnd::_HandleXdndPosition", -1);
    objv[1] = Tcl_NewStringObj(Tk_PathName(mouse_tkwin), -1);
    objv[2] = Tcl_NewIntObj(rootX);
    objv[3] = Tcl_NewIntObj(rootY);
    TkDND_Status_Eval(4);
    if (status == TCL_OK) {
      /* Get the returned action... */
      result = Tcl_GetObjResult(interp); Tcl_IncrRefCount(result);
      status = Tcl_GetIndexFromObj(interp, result, (const char **) DropActions,
                              "dropactions", 0, &index);
      Tcl_DecrRefCount(result);
      if (status != TCL_OK) index = refuse_drop;
    }
  }
  /* Sent a XdndStatus event, to notify the drag source */
  memset (&response, 0, sizeof(xevent));
  response.xany.type    = ClientMessage;
  response.xany.display = xevent->xclient.display;
  response.xclient.window = XDND_POSITION_SOURCE_WIN(xevent);
  response.xclient.message_type = Tk_InternAtom(tkwin, "XdndStatus");
  response.xclient.format = 32;
  XDND_STATUS_WILL_ACCEPT_SET(&response, 1);
  XDND_STATUS_WANT_POSITION_SET(&response, 1);
  XDND_STATUS_RECT_SET(&response, rootX, rootY, width, height);
#if XDND_VERSION >= 3
  XDND_STATUS_TARGET_WIN(&response) = Tk_WindowId(tkwin);
#else
  XDND_STATUS_TARGET_WIN(&response) = xevent->xany.window;
#endif
  switch ((enum dropactions) index) {
    case ActionDefault:
    case ActionCopy:
      XDND_STATUS_ACTION(&response) = Tk_InternAtom(tkwin, "XdndActionCopy");
      break;
    case ActionMove:
      XDND_STATUS_ACTION(&response) = Tk_InternAtom(tkwin, "XdndActionMove");
      break;
    case ActionLink:
      XDND_STATUS_ACTION(&response) = Tk_InternAtom(tkwin, "XdndActionLink");
      break;
    case ActionAsk:
      XDND_STATUS_ACTION(&response) = Tk_InternAtom(tkwin, "XdndActionAsk");
      break;
    case ActionPrivate: 
      XDND_STATUS_ACTION(&response) = Tk_InternAtom(tkwin, "XdndActionPrivate");
      break;
    case refuse_drop: {
      XDND_STATUS_WILL_ACCEPT_SET(&response, 0); /* Refuse drop. */
    }
  }
  XSendEvent(response.xany.display, response.xclient.window,
             False, NoEventMask, (XEvent*)&response);
  return True;
} /* TkDND_HandleXdndPosition */

int TkDND_HandleXdndLeave(Tk_Window tkwin, XEvent *xevent) {
  Tcl_Interp *interp = Tk_Interp(tkwin);
  Tcl_Obj* objv[1];
  int i;
  if (interp == NULL) return False; 
  objv[0] = Tcl_NewStringObj("tkdnd::xdnd::_HandleXdndLeave", -1);
  TkDND_Eval(1);
  return True;
} /* TkDND_HandleXdndLeave */

int TkDND_HandleXdndDrop(Tk_Window tkwin, XEvent *xevent) {
  XEvent finished;
  Tcl_Interp *interp = Tk_Interp(tkwin);
  Tcl_Obj* objv[2], *result;
  int status, i, index;
  Time time = XDND_DROP_TIME(xevent);
  static char *DropActions[] = {
    "copy", "move", "link", "ask",  "private", "refuse_drop", "default",
    (char *) NULL
  };
  enum dropactions {
    ActionCopy, ActionMove, ActionLink, ActionAsk, ActionPrivate,
    refuse_drop, ActionDefault
  };
    
  if (interp == NULL) return False;

  memset(&finished, 0, sizeof(XEvent));
  finished.xany.type            = ClientMessage;
  finished.xany.display         = xevent->xclient.display;
  finished.xclient.window       = XDND_DROP_SOURCE_WIN(xevent);
  finished.xclient.message_type = Tk_InternAtom(tkwin, "XdndFinished");
  finished.xclient.format = 32;
#if XDND_VERSION >= 3
  XDND_FINISHED_TARGET_WIN(&finished) = Tk_WindowId(tkwin);
#else
  XDND_FINISHED_TARGET_WIN(&finished) = xevent->xany.window;
#endif
  XDND_FINISHED_ACCEPTED_SET(&finished, 1);

  /* Call out Tcl callback. */
  objv[0] = Tcl_NewStringObj("tkdnd::xdnd::_HandleXdndDrop", -1);
  objv[1] = Tcl_NewLongObj(time);
  TkDND_Status_Eval(2);
  if (status == TCL_OK) {
    /* Get the returned action... */
    result = Tcl_GetObjResult(interp); Tcl_IncrRefCount(result);
    status = Tcl_GetIndexFromObj(interp, result, (const char **) DropActions,
                            "dropactions", 0, &index);
    Tcl_DecrRefCount(result);
    if (status != TCL_OK) index = refuse_drop;
    switch ((enum dropactions) index) {
      case ActionDefault:
      case ActionCopy:
        XDND_FINISHED_ACTION(&finished) =
             Tk_InternAtom(tkwin, "XdndActionCopy");    break;
      case ActionMove:
        XDND_FINISHED_ACTION(&finished) =
            Tk_InternAtom(tkwin, "XdndActionMove");    break;
      case ActionLink:
        XDND_FINISHED_ACTION(&finished) =
            Tk_InternAtom(tkwin, "XdndActionLink");    break;
      case ActionAsk:
        XDND_FINISHED_ACTION(&finished) =
            Tk_InternAtom(tkwin, "XdndActionAsk");     break;
      case ActionPrivate: 
        XDND_FINISHED_ACTION(&finished) =
            Tk_InternAtom(tkwin, "XdndActionPrivate"); break;
      case refuse_drop: {
        XDND_FINISHED_ACCEPTED_SET(&finished, 0); /* Drop canceled. */
      }
    }
  } else {
    XDND_FINISHED_ACCEPTED_SET(&finished, 0);
  }
  /* Send XdndFinished. */
  XSendEvent(finished.xany.display, finished.xclient.window,
             False, NoEventMask, (XEvent*)&finished);
  return True;
} /* TkDND_HandleXdndDrop */

int TkDND_HandleXdndStatus(Tk_Window tkwin, XEvent *xevent) {
  return False;
} /* TkDND_HandleXdndStatus */

int TkDND_HandleXdndFinished(Tk_Window tkwin, XEvent *xevent) {
  return False;
} /* TkDND_HandleXdndFinished */

static int TkDND_XDNDHandler(Tk_Window tkwin, XEvent *xevent) {
  if (xevent->type != ClientMessage) return False;

  if (xevent->xclient.message_type == Tk_InternAtom(tkwin, "XdndPosition")) {
#ifdef DEBUG_CLIENTMESSAGE_HANDLER
    printf("XDND_HandleClientMessage: Received XdndPosition\n");
#endif /* DEBUG_CLIENTMESSAGE_HANDLER */
    return TkDND_HandleXdndPosition(tkwin, xevent);
  } else if (xevent->xclient.message_type== Tk_InternAtom(tkwin, "XdndEnter")) {
#ifdef DEBUG_CLIENTMESSAGE_HANDLER
    printf("XDND_HandleClientMessage: Received XdndEnter\n");
#endif /* DEBUG_CLIENTMESSAGE_HANDLER */
    return TkDND_HandleXdndEnter(tkwin, xevent);
  } else if (xevent->xclient.message_type==Tk_InternAtom(tkwin, "XdndStatus")) {
#ifdef DEBUG_CLIENTMESSAGE_HANDLER
    printf("XDND_HandleClientMessage: Received XdndStatus\n");
#endif /* DEBUG_CLIENTMESSAGE_HANDLER */
    return TkDND_HandleXdndStatus(tkwin, xevent);
  } else if (xevent->xclient.message_type== Tk_InternAtom(tkwin, "XdndLeave")) {
#ifdef DEBUG_CLIENTMESSAGE_HANDLER
    printf("XDND_HandleClientMessage: Received XdndLeave\n");
#endif /* DEBUG_CLIENTMESSAGE_HANDLER */
    return TkDND_HandleXdndLeave(tkwin, xevent);
  } else if (xevent->xclient.message_type == Tk_InternAtom(tkwin, "XdndDrop")) {
#ifdef DEBUG_CLIENTMESSAGE_HANDLER
    printf("XDND_HandleClientMessage: Received XdndDrop\n");
#endif /* DEBUG_CLIENTMESSAGE_HANDLER */
    return TkDND_HandleXdndDrop(tkwin, xevent);
  } else if (xevent->xclient.message_type == 
                                         Tk_InternAtom(tkwin, "XdndFinished")) {
#ifdef DEBUG_CLIENTMESSAGE_HANDLER
    printf("XDND_HandleClientMessage: Received XdndFinished\n");
#endif /* DEBUG_CLIENTMESSAGE_HANDLER */
    return TkDND_HandleXdndFinished(tkwin, xevent);
  } else {
#ifdef TKDND_ENABLE_MOTIF_DROPS
    if (MotifDND_HandleClientMessage(dnd, xevent)) return True;
#endif /* TKDND_ENABLE_MOTIF_DROPS */
  }
  return False;
} /* TkDND_XDNDHandler */

/*
 * The following two functions were copied from tkSelect.c
 * If TIP 370 gets implemented, they will not be required.
 */
static int TkDND_SelGetProc(ClientData clientData,
                            Tcl_Interp *interp, const char *portion) {
  Tcl_DStringAppend(clientData, portion, -1);
  return TCL_OK;
}; /* TkDND_SelGetProc */

int TkDND_GetSelectionObjCmd(ClientData clientData, Tcl_Interp *interp,
                             int objc, Tcl_Obj *CONST objv[]) {
  Tk_Window tkwin = Tk_MainWindow(interp);
  Atom target;
  Atom selection;
  Time time = CurrentTime;
  const char *targetName = NULL;
  Tcl_DString selBytes;
  int result;
  static const char *const getOptionStrings[] = {
      "-displayof", "-selection", "-time", "-type", NULL
  };
  enum getOptions { GET_DISPLAYOF, GET_SELECTION, GET_TIME, GET_TYPE };
  int getIndex;
  int count;
  Tcl_Obj **objs;
  const char *string;
  const char *path = NULL;
  const char *selName = NULL;

  for (count = objc-1, objs = ((Tcl_Obj **)objv)+1; count>0;
                count-=2, objs+=2) {
    string = Tcl_GetString(objs[0]);
    if (string[0] != '-') {
        break;
    }
    if (count < 2) {
        Tcl_AppendResult(interp, "value for \"", string,
                                 "\" missing", NULL);
        return TCL_ERROR;
    }
    
    if (Tcl_GetIndexFromObj(interp, objs[0], getOptionStrings,
            "option", 0, &getIndex) != TCL_OK) {
        return TCL_ERROR;
    }
    
    switch ((enum getOptions) getIndex) {
    case GET_DISPLAYOF:
        path = Tcl_GetString(objs[1]);
        break;
    case GET_SELECTION:
        selName = Tcl_GetString(objs[1]);
        break;
    case GET_TYPE:
        targetName = Tcl_GetString(objs[1]);
        break;
    case GET_TIME:
        if (Tcl_GetLongFromObj(interp, objs[1], (long *) &time) != TCL_OK) {
          return TCL_ERROR;
        }
        break;
    }
  }
  if (path != NULL) {
      tkwin = Tk_NameToWindow(interp, path, tkwin);
  }
  if (tkwin == NULL) {
      return TCL_ERROR;
  }
  if (selName != NULL) {
      selection = Tk_InternAtom(tkwin, selName);
  } else {
      selection = XA_PRIMARY;
  }
  if (count > 1) {
      Tcl_WrongNumArgs(interp, 1, objv, "?-option value ...?");
      return TCL_ERROR;
  } else if (count == 1) {
      target = Tk_InternAtom(tkwin, Tcl_GetString(objs[0]));
  } else if (targetName != NULL) {
      target = Tk_InternAtom(tkwin, targetName);
  } else {
      target = XA_STRING;
  }
  Tcl_DStringInit(&selBytes);
  result = TkDND_GetSelection(interp, tkwin, selection, target, time,
                              TkDND_SelGetProc, &selBytes);
  if (1 ||result == TCL_OK) {
      Tcl_DStringResult(interp, &selBytes);
  }
  Tcl_DStringFree(&selBytes);
  return result;
} /* TkDND_GetSelectionObjCmd */

/*
 * For C++ compilers, use extern "C"
 */
#ifdef __cplusplus
extern "C" {
#endif
DLLEXPORT int Tkdnd_Init(Tcl_Interp *interp);
DLLEXPORT int Tkdnd_SafeInit(Tcl_Interp *interp);
#ifdef __cplusplus
}
#endif

int DLLEXPORT Tkdnd_Init(Tcl_Interp *interp) {
  int major, minor, patchlevel;
  Tcl_CmdInfo info;

  if (
#ifdef USE_TCL_STUBS 
      Tcl_InitStubs(interp, "8.3", 0)
#else
      Tcl_PkgRequire(interp, "Tcl", "8.3", 0)
#endif /* USE_TCL_STUBS */
            == NULL) {
            return TCL_ERROR;
  }
  if (
#ifdef USE_TK_STUBS
       Tk_InitStubs(interp, "8.3", 0)
#else
       Tcl_PkgRequire(interp, "Tk", "8.3", 0)
#endif /* USE_TK_STUBS */
            == NULL) {
            return TCL_ERROR;
  }

  /*
   * Get the version, because we really need 8.3.3+.
   */
  Tcl_GetVersion(&major, &minor, &patchlevel, NULL);
  if ((major == 8) && (minor == 3) && (patchlevel < 3)) {
    Tcl_SetResult(interp, "tkdnd requires Tk 8.3.3 or greater", TCL_STATIC);
    return TCL_ERROR;
  }

  if (Tcl_GetCommandInfo(interp, "selection", &info) == 0) {
    Tcl_SetResult(interp, "selection Tk command not found", TCL_STATIC);
    return TCL_ERROR;
  }

  /* Register the various commands */
  if (Tcl_CreateObjCommand(interp, "_register_types",
           (Tcl_ObjCmdProc*) TkDND_RegisterTypesObjCmd,
           (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL) == NULL) {
    return TCL_ERROR;
  }

  if (Tcl_CreateObjCommand(interp, "_selection_get",
           (Tcl_ObjCmdProc*) TkDND_GetSelectionObjCmd,
           (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL) == NULL) {
    return TCL_ERROR;
  }

  /* Finally, register the XDND Handler... */
  Tk_CreateClientMessageHandler(&TkDND_XDNDHandler);

  Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION);
  return TCL_OK;
} /* Tkdnd_Init */

int DLLEXPORT Tkdnd_SafeInit(Tcl_Interp *interp) {
  return Tkdnd_Init(interp);
} /* Tkdnd_SafeInit */
