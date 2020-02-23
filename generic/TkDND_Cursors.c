/*
 * TkDND_Cursors.c -- Tk XDND Cursor support.
 *
 *    This file implements utilities for using custom cursors in TkDND.
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

Tk_Cursor TkDND_noDropCursor  = NULL,
          TkDND_moveCursor    = NULL,
          TkDND_copyCursor    = NULL,
          TkDND_linkCursor    = NULL,
          TkDND_askCursor     = NULL,
          TkDND_privateCursor = NULL;


Tk_Cursor TkDND_GetCursor(Tcl_Interp *interp, Tcl_Obj *name) {
  static char *DropActions[] = {
    "copy", "move", "link", "ask",  "private", "refuse_drop", "default",
    (char *) NULL
  };
  enum dropactions {
    ActionCopy, ActionMove, ActionLink, ActionAsk, ActionPrivate,
    refuse_drop, ActionDefault
  };
  int status, index;
  Tk_Cursor cursor;

  status = Tcl_GetIndexFromObj(interp, name, (const char **) DropActions,
                              "dropactions", 0, &index);
  if (status == TCL_OK) {
    switch ((enum dropactions) index) {
      case ActionDefault:
      case ActionCopy:    return (Tk_Cursor) TkDND_copyCursor;
      case ActionMove:    return (Tk_Cursor) TkDND_moveCursor;
      case ActionLink:    return (Tk_Cursor) TkDND_linkCursor;
      case ActionAsk:     return (Tk_Cursor) TkDND_askCursor;
      case ActionPrivate: return (Tk_Cursor) TkDND_privateCursor;
      case refuse_drop:   return (Tk_Cursor) TkDND_noDropCursor;
    }
  }
  /* The name is not an action. Try Tk cursors... */
  cursor = Tk_AllocCursorFromObj(interp, Tk_MainWindow(interp), name);
  if (cursor == None) {
    Tcl_SetResult(interp, "invalid cursor name", TCL_STATIC);
    return (Tk_Cursor) None;
  }
  return cursor;
}; /* TkDND_GetCursor */
