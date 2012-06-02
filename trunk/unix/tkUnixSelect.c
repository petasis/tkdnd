/*
 * tkUnixSelect.c --
 *
 *	This file contains X specific routines for manipulating selections.
 *
 * Copyright (c) 1995-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tk.h"
#include "tkInt.h"
#include "tkSelect.h"

/*
 * Forward declarations for functions defined in this file:
 */
typedef struct {
  Tcl_Interp     *interp;
  Tk_GetSelProc  *proc;
  ClientData      clientData;
  Tcl_TimerToken  timeout;
  Tk_Window       tkwin;
  Atom            property;
  int             result;
  int             idleTime;
} TkDND_ProcDetail;

static void TkDND_SelTimeoutProc(ClientData clientData);

static inline int maxSelectionIncr(Display *dpy) {
  return XMaxRequestSize(dpy) > 65536 ? 65536*4 :
                               XMaxRequestSize(dpy)*4 - 100;
}; /* maxSelectionIncr */

int TkDND_ClipboardReadProperty(Tk_Window tkwin,
                                Atom property, int deleteProperty,
                                TkDND_ProcDetail *detail,
                                int *size, Atom *type, int *format) {
    Display *display = Tk_Display(tkwin);
    Window   win     = Tk_WindowId(tkwin);
    int      maxsize = maxSelectionIncr(display);
    unsigned long    bytes_left; // bytes_after
    unsigned long    length;     // nitems
    unsigned char   *data;
    Atom     dummy_type;
    int      dummy_format;
    int      r;
    Tcl_DString *buffer = (Tcl_DString *) detail->clientData;

    if (!type)                                // allow null args
        type = &dummy_type;
    if (!format)
        format = &dummy_format;

    // Don't read anything, just get the size of the property data
    r = XGetWindowProperty(display, win, property, 0, 0, False,
                            AnyPropertyType, type, format,
                            &length, &bytes_left, &data);
    if (r != Success || (type && *type == None)) {
        return 0;
    }
    XFree((char*)data);

    int offset = 0, format_inc = 1;

    switch (*format) {
    case 8:
    default:
        format_inc = sizeof(char) / 1;
        break;

    case 16:
        format_inc = sizeof(short) / 2;
        break;

    case 32:
        format_inc = sizeof(long) / 4;
        break;
    }

    while (bytes_left) {
      r = XGetWindowProperty(display, win, property, offset, maxsize/4,
                             False, AnyPropertyType, type, format,
                             &length, &bytes_left, &data);
      if (r != Success || (type && *type == None))
          break;

      offset += length / (32 / *format);
      length *= format_inc * (*format) / 8;
      Tcl_DStringAppend(buffer, (char *) data, length);

      XFree((char*)data);
    }

    if (*format == 8 && *type == Tk_InternAtom(tkwin, "COMPOUND_TEXT")) {
      // convert COMPOUND_TEXT to a multibyte string
      XTextProperty textprop;
      textprop.encoding = *type;
      textprop.format = *format;
      textprop.nitems = Tcl_DStringLength(buffer);
      textprop.value = (unsigned char *) Tcl_DStringValue(buffer);

      char **list_ret = 0;
      int count;
      if (XmbTextPropertyToTextList(display, &textprop, &list_ret,
                   &count) == Success && count && list_ret) {
        Tcl_DStringFree(buffer);
        Tcl_DStringInit(buffer);
        Tcl_DStringAppend(buffer, list_ret[0], -1);
      }
      if (list_ret) XFreeStringList(list_ret);
    }

    // correct size, not 0-term.
    if (size) *size = Tcl_DStringLength(buffer);
    if (deleteProperty) XDeleteProperty(display, win, property);
    XFlush(display);
    return 1;
}; /* TkDND_ClipboardReadProperty */

void TkDND_EventProc(ClientData clientData, XEvent *eventPtr) {
  TkDND_ProcDetail *detail = (TkDND_ProcDetail *) clientData;
  int status, size, format;
  Atom type;

  status = TkDND_ClipboardReadProperty(detail->tkwin, detail->property, 1,
                                       detail, &size, &type, &format);
  if (status) detail->result = TCL_OK;
}; /* TkDND_EventProc */


/*
 *----------------------------------------------------------------------
 *
 * TkDNDSelGetSelection --
 *
 *	Retrieve the specified selection from another process.
 *
 * Results:
 *	The return value is a standard Tcl return value. If an error occurs
 *	(such as no selection exists) then an error message is left in the
 *	interp's result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TkDNDSelGetSelection(
    Tcl_Interp *interp,		/* Interpreter to use for reporting errors. */
    Tk_Window tkwin,		/* Window on whose behalf to retrieve the
				 * selection (determines display from which to
				 * retrieve). */
    Atom selection,		/* Selection to retrieve. */
    Atom target,		/* Desired form in which selection is to be
				 * returned. */
    Time time,
    Tk_GetSelProc *proc,	/* Function to call to process the selection,
				 * once it has been retrieved. */
    ClientData clientData)	/* Arbitrary value to pass to proc. */
{
    TkDND_ProcDetail detail;
    Tk_Window sel_tkwin = Tk_MainWindow(interp);
    Display *display    = Tk_Display(tkwin);
    detail.interp       = interp;
    detail.tkwin        = sel_tkwin;
    detail.property     = selection;
    detail.proc         = proc;
    detail.clientData   = clientData;
    detail.result       = -1;
    detail.idleTime     = 0;

    if (XGetSelectionOwner(display, selection) == None) {
      Tcl_SetResult(interp, "no owner for selection", TCL_STATIC);
      return TCL_ERROR;
    }
    /*
     * Initiate the request for the selection. Note: can't use TkCurrentTime
     * for the time. If we do, and this application hasn't received any X
     * events in a long time, the current time will be way in the past and
     * could even predate the time when the selection was made; if this
     * happens, the request will be rejected.
     */

    /* Register an event handler for tkwin... */
    Tk_CreateEventHandler(sel_tkwin, SelectionNotify, TkDND_EventProc, &detail);
    XConvertSelection(display, selection, target,
	              selection, Tk_WindowId(sel_tkwin), time);
    XFlush(display);

    /*
     * Enter a loop processing X events until the selection has been retrieved
     * and processed. If no response is received within a few seconds, then
     * timeout.
     */

    detail.timeout = Tcl_CreateTimerHandler(1000, TkDND_SelTimeoutProc,
	                                    &detail);
    while (detail.result == -1) {
	Tcl_DoOneEvent(0);
    }
    Tk_DeleteEventHandler(sel_tkwin, SelectionNotify, TkDND_EventProc, &detail);
    Tcl_DeleteTimerHandler(detail.timeout);

    return detail.result;
}

/*
 *----------------------------------------------------------------------
 *
 * TkDND_SelTimeoutProc --
 *
 *	This function is invoked once every second while waiting for the
 *	selection to be returned. After a while it gives up and aborts the
 *	selection retrieval.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	A new timer callback is created to call us again in another second,
 *	unless time has expired, in which case an error is recorded for the
 *	retrieval.
 *
 *----------------------------------------------------------------------
 */

static void
TkDND_SelTimeoutProc(
    ClientData clientData)	/* Information about retrieval in progress. */
{
    register TkDND_ProcDetail *retrPtr = (TkDND_ProcDetail *) clientData;

    /*
     * Make sure that the retrieval is still in progress. Then see how long
     * it's been since any sort of response was received from the other side.
     */

    if (retrPtr->result != -1) {
	return;
    }
    retrPtr->idleTime++;
    if (retrPtr->idleTime >= 5) {
	/*
	 * Use a careful function to store the error message, because the
	 * result could already be partially filled in with a partial
	 * selection return.
	 */

	Tcl_SetResult(retrPtr->interp, "selection owner didn't respond",
		TCL_STATIC);
	retrPtr->result = TCL_ERROR;
    } else {
	retrPtr->timeout = Tcl_CreateTimerHandler(1000, TkDND_SelTimeoutProc,
		(ClientData) retrPtr);
    }
}

int TkDND_GetSelection(Tcl_Interp *interp, Tk_Window tkwin, Atom selection,
                       Atom target, Time time,
                       Tk_GetSelProc *proc, ClientData clientData) {
  /*
   * The selection is owned by some other process.
   */
  return TkDNDSelGetSelection(interp, tkwin, selection, target, time,
                              proc, clientData);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
