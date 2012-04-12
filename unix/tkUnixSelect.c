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

static TkSelRetrievalInfo *pendingRetrievals = NULL;
				/* List of all retrievals currently being
				 * waited for. */

/*
 * Forward declarations for functions defined in this file:
 */

static void		TkDND_SelTimeoutProc(ClientData clientData);

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
    TkSelRetrievalInfo retr;
    TkWindow *winPtr = (TkWindow *) tkwin;
    TkDisplay *dispPtr = winPtr->dispPtr;

    /*
     * The selection is owned by some other process. To retrieve it, first
     * record information about the retrieval in progress. Use an internal
     * window as the requestor.
     */

    retr.interp = interp;
    if (dispPtr->clipWindow == NULL) {
	int result;

	result = TkClipInit(interp, dispPtr);
	if (result != TCL_OK) {
printf("1\n");
	    return result;
	}
    }
    retr.winPtr = (TkWindow *) dispPtr->clipWindow;
    retr.selection = selection;
    retr.property = selection;
    retr.target = target;
    retr.proc = proc;
    retr.clientData = clientData;
    retr.result = -1;
    retr.idleTime = 0;
    retr.encFlags = TCL_ENCODING_START;
    retr.nextPtr = pendingRetrievals;
    Tcl_DStringInit(&retr.buf);
    pendingRetrievals = &retr;

    /*
     * Initiate the request for the selection. Note: can't use TkCurrentTime
     * for the time. If we do, and this application hasn't received any X
     * events in a long time, the current time will be way in the past and
     * could even predate the time when the selection was made; if this
     * happens, the request will be rejected.
     */

    XConvertSelection(winPtr->display, retr.selection, retr.target,
	              retr.property, retr.winPtr->window, time);

    /*
     * Enter a loop processing X events until the selection has been retrieved
     * and processed. If no response is received within a few seconds, then
     * timeout.
     */

    retr.timeout = Tcl_CreateTimerHandler(1000, TkDND_SelTimeoutProc,
	    &retr);
    while (retr.result == -1) {
	Tcl_DoOneEvent(0);
    }
    Tcl_DeleteTimerHandler(retr.timeout);

    /*
     * Unregister the information about the selection retrieval in progress.
     */

    if (pendingRetrievals == &retr) {
	pendingRetrievals = retr.nextPtr;
    } else {
	TkSelRetrievalInfo *retrPtr;

	for (retrPtr = pendingRetrievals; retrPtr != NULL;
		retrPtr = retrPtr->nextPtr) {
	    if (retrPtr->nextPtr == &retr) {
		retrPtr->nextPtr = retr.nextPtr;
		break;
	    }
	}
    }
    Tcl_DStringFree(&retr.buf);
    return retr.result;
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
    register TkSelRetrievalInfo *retrPtr = (TkSelRetrievalInfo *) clientData;

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

/*
 * The structure below is used to keep each thread's pending list separate.
 */

typedef struct ThreadSpecificData {
    TkSelInProgress *pendingPtr;
				/* Topmost search in progress, or NULL if
				 * none. */
} ThreadSpecificData;
static Tcl_ThreadDataKey dataKey;

int
TkSelDefaultSelection(
    TkSelectionInfo *infoPtr,	/* Info about selection being retrieved. */
    Atom target,		/* Desired form of selection. */
    char *buffer,		/* Place to put selection characters. */
    int maxBytes,		/* Maximum # of bytes to store at buffer. */
    Atom *typePtr)		/* Store here the type of the selection, for
				 * use in converting to proper X format. */
{
    register TkWindow *winPtr = (TkWindow *) infoPtr->owner;
    TkDisplay *dispPtr = winPtr->dispPtr;

    if (target == dispPtr->timestampAtom) {
	if (maxBytes < 20) {
	    return -1;
	}
	sprintf(buffer, "0x%x", (unsigned int) infoPtr->time);
	*typePtr = XA_INTEGER;
	return strlen(buffer);
    }

    if (target == dispPtr->targetsAtom) {
	register TkSelHandler *selPtr;
	int length;
	Tcl_DString ds;

	if (maxBytes < 50) {
	    return -1;
	}
	Tcl_DStringInit(&ds);
	Tcl_DStringAppend(&ds,
		"MULTIPLE TARGETS TIMESTAMP TK_APPLICATION TK_WINDOW", -1);
	for (selPtr = winPtr->selHandlerList; selPtr != NULL;
		selPtr = selPtr->nextPtr) {
	    if ((selPtr->selection == infoPtr->selection)
		    && (selPtr->target != dispPtr->applicationAtom)
		    && (selPtr->target != dispPtr->windowAtom)) {
		const char *atomString = Tk_GetAtomName((Tk_Window) winPtr,
			selPtr->target);
		Tcl_DStringAppendElement(&ds, atomString);
	    }
	}
	length = Tcl_DStringLength(&ds);
	if (length >= maxBytes) {
	    Tcl_DStringFree(&ds);
	    return -1;
	}
	memcpy(buffer, Tcl_DStringValue(&ds), (unsigned) (1+length));
	Tcl_DStringFree(&ds);
	*typePtr = XA_ATOM;
	return length;
    }

    if (target == dispPtr->applicationAtom) {
	int length;
	Tk_Uid name = winPtr->mainPtr->winPtr->nameUid;

	length = strlen(name);
	if (maxBytes <= length) {
	    return -1;
	}
	strcpy(buffer, name);
	*typePtr = XA_STRING;
	return length;
    }

    if (target == dispPtr->windowAtom) {
	int length;
	char *name = winPtr->pathName;

	length = strlen(name);
	if (maxBytes <= length) {
	    return -1;
	}
	strcpy(buffer, name);
	*typePtr = XA_STRING;
	return length;
    }

    return -1;
}

int TkDND_GetSelection(Tcl_Interp *interp, Tk_Window tkwin, Atom selection,
                       Atom target, Time time,
                       Tk_GetSelProc *proc, ClientData clientData) {
    TkWindow *winPtr = (TkWindow *) tkwin;
    TkDisplay *dispPtr = winPtr->dispPtr;
    TkSelectionInfo *infoPtr;
    ThreadSpecificData *tsdPtr =
	    Tcl_GetThreadData(&dataKey, sizeof(ThreadSpecificData));

    if (dispPtr->multipleAtom == None) {
	TkSelInit(tkwin);
    }

    /*
     * If the selection is owned by a window managed by this process, then
     * call the retrieval function directly, rather than going through the X
     * server (it's dangerous to go through the X server in this case because
     * it could result in deadlock if an INCR-style selection results).
     */

    for (infoPtr = dispPtr->selectionInfoPtr; infoPtr != NULL;
	    infoPtr = infoPtr->nextPtr) {
	if (infoPtr->selection == selection) {
	    break;
	}
    }
    if (infoPtr != NULL) {
	register TkSelHandler *selPtr;
	int offset, result, count;
	char buffer[TK_SEL_BYTES_AT_ONCE+1];
	TkSelInProgress ip;

	for (selPtr = ((TkWindow *) infoPtr->owner)->selHandlerList;
		selPtr != NULL; selPtr = selPtr->nextPtr) {
	    if (selPtr->target==target && selPtr->selection==selection) {
		break;
	    }
	}
	if (selPtr == NULL) {
	    Atom type;

	    count = TkSelDefaultSelection(infoPtr, target, buffer,
		    TK_SEL_BYTES_AT_ONCE, &type);
	    if (count > TK_SEL_BYTES_AT_ONCE) {
		Tcl_Panic("selection handler returned too many bytes");
	    }
	    if (count < 0) {
		goto cantget;
	    }
	    buffer[count] = 0;
	    result = proc(clientData, interp, buffer);
	} else {
	    offset = 0;
	    result = TCL_OK;
	    ip.selPtr = selPtr;
	    ip.nextPtr = tsdPtr->pendingPtr;
	    tsdPtr->pendingPtr = &ip;
	    while (1) {
		count = selPtr->proc(selPtr->clientData, offset, buffer,
			TK_SEL_BYTES_AT_ONCE);
		if ((count < 0) || (ip.selPtr == NULL)) {
		    tsdPtr->pendingPtr = ip.nextPtr;
		    goto cantget;
		}
		if (count > TK_SEL_BYTES_AT_ONCE) {
		    Tcl_Panic("selection handler returned too many bytes");
		}
		buffer[count] = '\0';
		result = proc(clientData, interp, buffer);
		if ((result != TCL_OK) || (count < TK_SEL_BYTES_AT_ONCE)
			|| (ip.selPtr == NULL)) {
		    break;
		}
		offset += count;
	    }
	    tsdPtr->pendingPtr = ip.nextPtr;
	}
	return result;
    }

    /*
     * The selection is owned by some other process.
     */

    return TkDNDSelGetSelection(interp, tkwin, selection, target, time,
                                proc, clientData);

  cantget:
    Tcl_AppendResult(interp, Tk_GetAtomName(tkwin, selection),
	    " selection doesn't exist or form \"",
	    Tk_GetAtomName(tkwin, target), "\" not defined", NULL);
    return TCL_ERROR;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
