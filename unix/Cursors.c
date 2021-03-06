/*
 * Cursors.c -- Tk XDND Cursor support.
 *
 *    This file implements utilities for using unix cursors in TkDND.
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

#include "TkDND_Cursors.h"

/* https://www.x.org/releases/X11R7.7/doc/man/man3/Xcursor.3.xhtml */
#ifdef HAVE_X11_XCURSOR_XCURSOR_H
#include <X11/Xcursor/Xcursor.h>
#endif /* HAVE_X11_XCURSOR_XCURSOR_H */

/*
 * Define DND Cursors...
 */

/* No Drop Cursor... */
#define noDropCursorWidth  20
#define noDropCursorHeight 20
#define noDropCursorX      10
#define noDropCursorY      10
static /*unsigned*/ char noDropCurBits[] = {
 0x00,0x00,0x00,0x80,0x1f,0x00,0xe0,0x7f,0x00,0xf0,0xf0,0x00,0x38,0xc0,0x01,
 0x7c,0x80,0x03,0xec,0x00,0x03,0xce,0x01,0x07,0x86,0x03,0x06,0x06,0x07,0x06,
 0x06,0x0e,0x06,0x06,0x1c,0x06,0x0e,0x38,0x07,0x0c,0x70,0x03,0x1c,0xe0,0x03,
 0x38,0xc0,0x01,0xf0,0xe0,0x00,0xe0,0x7f,0x00,0x80,0x1f,0x00,0x00,0x00,0x00};

static /*unsigned*/ char noDropCurMask[] = {
 0x80,0x1f,0x00,0xe0,0x7f,0x00,0xf0,0xff,0x00,0xf8,0xff,0x01,0xfc,0xf0,0x03,
 0xfe,0xc0,0x07,0xfe,0x81,0x07,0xff,0x83,0x0f,0xcf,0x07,0x0f,0x8f,0x0f,0x0f,
 0x0f,0x1f,0x0f,0x0f,0x3e,0x0f,0x1f,0xfc,0x0f,0x1e,0xf8,0x07,0x3e,0xf0,0x07,
 0xfc,0xe0,0x03,0xf8,0xff,0x01,0xf0,0xff,0x00,0xe0,0x7f,0x00,0x80,0x1f,0x00};

/* Copy Cursor... */
#define CopyCursorWidth  29
#define CopyCursorHeight 25
#define CopyCursorX      10
#define CopyCursorY      10
static /*unsigned*/ char CopyCurBits[] =
{
  0x00, 0x00, 0x00, 0x00, 0xfe, 0xff, 0x0f, 0x00, 0x02, 0x00, 0x08, 0x01,
  0x02, 0x00, 0x08, 0x01, 0x02, 0x00, 0x08, 0x01, 0x02, 0x00, 0xe8, 0x0f,
  0x02, 0x00, 0x08, 0x01, 0x02, 0x00, 0x08, 0x01, 0x02, 0x00, 0x08, 0x01,
  0x02, 0x00, 0x08, 0x00, 0x02, 0x04, 0x08, 0x00, 0x02, 0x0c, 0x08, 0x00,
  0x02, 0x1c, 0x08, 0x00, 0x02, 0x3c, 0x08, 0x00, 0x02, 0x7c, 0x08, 0x00,
  0x02, 0xfc, 0x08, 0x00, 0x02, 0xfc, 0x09, 0x00, 0x02, 0xfc, 0x0b, 0x00,
  0x02, 0x7c, 0x08, 0x00, 0xfe, 0x6d, 0x0f, 0x00, 0x00, 0xc4, 0x00, 0x00,
  0x00, 0xc0, 0x00, 0x00, 0x00, 0x80, 0x01, 0x00, 0x00, 0x80, 0x01, 0x00,
  0x00, 0x00, 0x00, 0x00};

static /*unsigned*/ char CopyCurMask[] =
{
  0xff, 0xff, 0x1f, 0x00, 0xff, 0xff, 0xff, 0x1f, 0xff, 0xff, 0xff, 0x1f,
  0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f,
  0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f,
  0x07, 0x06, 0xfc, 0x1f, 0x07, 0x0e, 0xfc, 0x1f, 0x07, 0x1e, 0x1c, 0x00,
  0x07, 0x3e, 0x1c, 0x00, 0x07, 0x7e, 0x1c, 0x00, 0x07, 0xfe, 0x1c, 0x00,
  0x07, 0xfe, 0x1d, 0x00, 0x07, 0xfe, 0x1f, 0x00, 0x07, 0xfe, 0x1f, 0x00,
  0xff, 0xff, 0x1f, 0x00, 0xff, 0xff, 0x1e, 0x00, 0xff, 0xef, 0x1f, 0x00,
  0x00, 0xe6, 0x01, 0x00, 0x00, 0xc0, 0x03, 0x00, 0x00, 0xc0, 0x03, 0x00,
  0x00, 0x80, 0x01, 0x00};

/* Move Cursor... */
#define MoveCursorWidth  21
#define MoveCursorHeight 25
#define MoveCursorX      10
#define MoveCursorY      10
static /*unsigned*/ char MoveCurBits[] =
{
  0x00, 0x00, 0x00, 0xfe, 0xff, 0x0f, 0x02, 0x00, 0x08, 0x02, 0x00, 0x08,
  0x02, 0x00, 0x08, 0x02, 0x00, 0x08, 0x02, 0x00, 0x08, 0x02, 0x00, 0x08,
  0x02, 0x00, 0x08, 0x02, 0x00, 0x08, 0x02, 0x04, 0x08, 0x02, 0x0c, 0x08,
  0x02, 0x1c, 0x08, 0x02, 0x3c, 0x08, 0x02, 0x7c, 0x08, 0x02, 0xfc, 0x08,
  0x02, 0xfc, 0x09, 0x02, 0xfc, 0x0b, 0x02, 0x7c, 0x08, 0xfe, 0x6d, 0x0f,
  0x00, 0xc4, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x80, 0x01, 0x00, 0x80, 0x01,
  0x00, 0x00, 0x00};

static /*unsigned*/ char MoveCurMask[] =
{
  0xff, 0xff, 0x1f, 0xff, 0xff, 0x1f, 0xff, 0xff, 0x1f, 0x07, 0x00, 0x1c,
  0x07, 0x00, 0x1c, 0x07, 0x00, 0x1c, 0x07, 0x00, 0x1c, 0x07, 0x00, 0x1c,
  0x07, 0x00, 0x1c, 0x07, 0x06, 0x1c, 0x07, 0x0e, 0x1c, 0x07, 0x1e, 0x1c,
  0x07, 0x3e, 0x1c, 0x07, 0x7e, 0x1c, 0x07, 0xfe, 0x1c, 0x07, 0xfe, 0x1d,
  0x07, 0xfe, 0x1f, 0x07, 0xfe, 0x1f, 0xff, 0xff, 0x1f, 0xff, 0xff, 0x1e,
  0xff, 0xef, 0x1f, 0x00, 0xe6, 0x01, 0x00, 0xc0, 0x03, 0x00, 0xc0, 0x03,
  0x00, 0x80, 0x01};

/* Link Cursor... */
#define LinkCursorWidth  29
#define LinkCursorHeight 25
#define LinkCursorX      10
#define LinkCursorY      10
static /*unsigned*/ char LinkCurBits[] =
{
  0x00, 0x00, 0x00, 0x00, 0xfe, 0xff, 0x0f, 0x00, 0x02, 0x00, 0x08, 0x01,
  0x02, 0x00, 0x88, 0x00, 0x02, 0x00, 0x48, 0x00, 0x02, 0x00, 0xe8, 0x0f,
  0x02, 0x00, 0x48, 0x00, 0x02, 0x00, 0x88, 0x00, 0x02, 0x00, 0x08, 0x01,
  0x02, 0x00, 0x08, 0x00, 0x02, 0x04, 0x08, 0x00, 0x02, 0x0c, 0x08, 0x00,
  0x02, 0x1c, 0x08, 0x00, 0x02, 0x3c, 0x08, 0x00, 0x02, 0x7c, 0x08, 0x00,
  0x02, 0xfc, 0x08, 0x00, 0x02, 0xfc, 0x09, 0x00, 0x02, 0xfc, 0x0b, 0x00,
  0x02, 0x7c, 0x08, 0x00, 0xfe, 0x6d, 0x0f, 0x00, 0x00, 0xc4, 0x00, 0x00,
  0x00, 0xc0, 0x00, 0x00, 0x00, 0x80, 0x01, 0x00, 0x00, 0x80, 0x01, 0x00,
  0x00, 0x00, 0x00, 0x00};

static /*unsigned*/ char LinkCurMask[] =
{
  0xff, 0xff, 0x1f, 0x00, 0xff, 0xff, 0xff, 0x1f, 0xff, 0xff, 0xff, 0x1f,
  0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f,
  0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f,
  0x07, 0x06, 0xfc, 0x1f, 0x07, 0x0e, 0xfc, 0x1f, 0x07, 0x1e, 0x1c, 0x00,
  0x07, 0x3e, 0x1c, 0x00, 0x07, 0x7e, 0x1c, 0x00, 0x07, 0xfe, 0x1c, 0x00,
  0x07, 0xfe, 0x1d, 0x00, 0x07, 0xfe, 0x1f, 0x00, 0x07, 0xfe, 0x1f, 0x00,
  0xff, 0xff, 0x1f, 0x00, 0xff, 0xff, 0x1e, 0x00, 0xff, 0xef, 0x1f, 0x00,
  0x00, 0xe6, 0x01, 0x00, 0x00, 0xc0, 0x03, 0x00, 0x00, 0xc0, 0x03, 0x00,
  0x00, 0x80, 0x01, 0x00};

/* Ask Cursor... */
#define AskCursorWidth  29
#define AskCursorHeight 25
#define AskCursorX      10
#define AskCursorY      10
static /*unsigned*/ char AskCurBits[] =
{
  0x00, 0x00, 0x00, 0x00, 0xfe, 0xff, 0x0f, 0x00, 0x02, 0x00, 0x88, 0x03,
  0x02, 0x00, 0x48, 0x04, 0x02, 0x00, 0x08, 0x04, 0x02, 0x00, 0x08, 0x02,
  0x02, 0x00, 0x08, 0x01, 0x02, 0x00, 0x08, 0x01, 0x02, 0x00, 0x08, 0x00,
  0x02, 0x00, 0x08, 0x01, 0x02, 0x04, 0x08, 0x00, 0x02, 0x0c, 0x08, 0x00,
  0x02, 0x1c, 0x08, 0x00, 0x02, 0x3c, 0x08, 0x00, 0x02, 0x7c, 0x08, 0x00,
  0x02, 0xfc, 0x08, 0x00, 0x02, 0xfc, 0x09, 0x00, 0x02, 0xfc, 0x0b, 0x00,
  0x02, 0x7c, 0x08, 0x00, 0xfe, 0x6d, 0x0f, 0x00, 0x00, 0xc4, 0x00, 0x00,
  0x00, 0xc0, 0x00, 0x00, 0x00, 0x80, 0x01, 0x00, 0x00, 0x80, 0x01, 0x00,
  0x00, 0x00, 0x00, 0x00};

static /*unsigned*/ char AskCurMask[] =
{
  0xff, 0xff, 0x1f, 0x00, 0xff, 0xff, 0xff, 0x1f, 0xff, 0xff, 0xff, 0x1f,
  0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f,
  0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f, 0x07, 0x00, 0xfc, 0x1f,
  0x07, 0x06, 0xfc, 0x1f, 0x07, 0x0e, 0xfc, 0x1f, 0x07, 0x1e, 0x1c, 0x00,
  0x07, 0x3e, 0x1c, 0x00, 0x07, 0x7e, 0x1c, 0x00, 0x07, 0xfe, 0x1c, 0x00,
  0x07, 0xfe, 0x1d, 0x00, 0x07, 0xfe, 0x1f, 0x00, 0x07, 0xfe, 0x1f, 0x00,
  0xff, 0xff, 0x1f, 0x00, 0xff, 0xff, 0x1e, 0x00, 0xff, 0xef, 0x1f, 0x00,
  0x00, 0xe6, 0x01, 0x00, 0x00, 0xc0, 0x03, 0x00, 0x00, 0xc0, 0x03, 0x00,
  0x00, 0x80, 0x01, 0x00};


void TkDND_InitialiseCursors(Tcl_Interp *interp) {
  Tk_Window main_window;
  Display *display;

  if (!interp) return;
  main_window   = Tk_MainWindow(interp);
  Tk_MakeWindowExist(main_window);
  Tk_Uid cbgcol = Tk_GetUid("black"), cfgcol = Tk_GetUid("white");
  display = Tk_Display(main_window);

  /* No Drop Cursor */
  if (TkDND_noDropCursor == NULL) {
#ifdef HAVE_X11_XCURSOR_XCURSOR_H
    TkDND_noDropCursor = (Tk_Cursor)
          XcursorLibraryLoadCursor(display, "dnd-no-drop");
#else
    TkDND_noDropCursor = None;
#endif /* HAVE_X11_XCURSOR_XCURSOR_H */
    if (TkDND_noDropCursor == None) {
      TkDND_noDropCursor = Tk_GetCursorFromData(interp, main_window,
        noDropCurBits, noDropCurMask, noDropCursorWidth, noDropCursorHeight,
        noDropCursorX, noDropCursorY, cbgcol, cfgcol);
    }
  }
  /* Copy Cursor */
  if (TkDND_copyCursor == NULL) {
#ifdef HAVE_X11_XCURSOR_XCURSOR_H
    TkDND_copyCursor = (Tk_Cursor)
          XcursorLibraryLoadCursor(display, "dnd-copy");
#else
    TkDND_copyCursor = None;
#endif /* HAVE_X11_XCURSOR_XCURSOR_H */
    if (TkDND_copyCursor == None) {
      TkDND_copyCursor = Tk_GetCursorFromData(interp, main_window,
        CopyCurBits, CopyCurMask, CopyCursorWidth, CopyCursorHeight,
        CopyCursorX, CopyCursorY, cbgcol, cfgcol);
    }
  }
  /* Move Cursor */
  if (TkDND_moveCursor == NULL) {
#ifdef HAVE_X11_XCURSOR_XCURSOR_H
    TkDND_moveCursor = (Tk_Cursor)
          XcursorLibraryLoadCursor(display, "dnd-move");
#else
    TkDND_moveCursor = None;
#endif /* HAVE_X11_XCURSOR_XCURSOR_H */
    if (TkDND_moveCursor == None) {
      TkDND_moveCursor = Tk_GetCursorFromData(interp, main_window,
        MoveCurBits, MoveCurMask, MoveCursorWidth, MoveCursorHeight,
        MoveCursorX, MoveCursorY, cbgcol, cfgcol);
    }
  }
  /* Link Cursor */
  if (TkDND_linkCursor == NULL) {
#ifdef HAVE_X11_XCURSOR_XCURSOR_H
    TkDND_linkCursor = (Tk_Cursor)
          XcursorLibraryLoadCursor(display, "dnd-link");
#else
    TkDND_linkCursor = None;
#endif /* HAVE_X11_XCURSOR_XCURSOR_H */
    if (TkDND_linkCursor == None) {
      TkDND_linkCursor = Tk_GetCursorFromData(interp, main_window,
        LinkCurBits, LinkCurMask, LinkCursorWidth, LinkCursorHeight,
        LinkCursorX, LinkCursorY, cbgcol, cfgcol);
    }
  }
  /* Ask Cursor */
  if (TkDND_askCursor == NULL) {
#ifdef HAVE_X11_XCURSOR_XCURSOR_H
    TkDND_askCursor = (Tk_Cursor)
          XcursorLibraryLoadCursor(display, "dnd-ask");
#else
    TkDND_askCursor = None;
#endif /* HAVE_X11_XCURSOR_XCURSOR_H */
    if (TkDND_askCursor == None) {
      TkDND_askCursor = Tk_GetCursorFromData(interp, main_window,
        AskCurBits, AskCurMask, AskCursorWidth, AskCursorHeight,
        AskCursorX, AskCursorY, cbgcol, cfgcol);
    }
  }
  /* Private Cursor (same as Ask) */
  if (TkDND_privateCursor == NULL) {
#ifdef HAVE_X11_XCURSOR_XCURSOR_H
    TkDND_privateCursor = (Tk_Cursor)
          XcursorLibraryLoadCursor(display, "dnd-ask");
#else
    TkDND_privateCursor = None;
#endif /* HAVE_X11_XCURSOR_XCURSOR_H */
    if (TkDND_privateCursor == None) {
      TkDND_privateCursor = Tk_GetCursorFromData(interp, main_window,
        AskCurBits, AskCurMask, AskCursorWidth, AskCursorHeight,
        AskCursorX, AskCursorY, cbgcol, cfgcol);
    }
  }

  /* Wait Cursor */
  if (TkDND_waitCursor == NULL) {
#ifdef HAVE_X11_XCURSOR_XCURSOR_H
    TkDND_waitCursor = (Tk_Cursor)
          XcursorLibraryLoadCursor(display, "wait");
#else
    TkDND_waitCursor = None;
#endif /* HAVE_X11_XCURSOR_XCURSOR_H */
    if (TkDND_waitCursor == None) {
      TkDND_waitCursor = Tk_GetCursor(interp, main_window, "clock");
    }
  }
}; /* TkDND_InitialiseCursors */
