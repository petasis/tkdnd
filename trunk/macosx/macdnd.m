#import <tcl.h>
#import <Cocoa/Cocoa.h>
#import <tk.h>
#import <tkInt.h>
#import <tkMacOSXInt.h>

//need to wrap Cocoa methods in Cocoa class: methods for initiating, tracking, and terminating drag from inside and outside the application

@interface DNDView : NSView {

}

@end

@implementation DNDView 


//mousedown event to trigger drag
- (void)mouseDown:(NSEvent*)event {

  //get the Pasteboard used for drag and drop operations
  NSPasteboard* dragPasteboard=[NSPasteboard pasteboardWithName:NSDragPboard];

  NSImage * dragImage = [[NSWorkspace sharedWorkspace] iconForFileType:@"dylib"];

  [dragImage lockFocus];
  [[self image] dissolveToPoint: NSZeroPoint fraction: .5];
  [dragImage unlockFocus];
  //   [dragImage setSize:[self bounds].size];
  [self dragImage: dragImage
		    at: [self bounds].origin
		offset: NSZeroSize
		 event:event
	    pasteboard:dragPasteboard
		source: self
	     slideBack: YES];
  [dragImage release];
}


- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag {

  return NSDragOperationEvery;
}


//DESTINATION OPERATIONS
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
  NSPasteboard *pboard;
  NSDragOperation sourceDragMask;
 
  sourceDragMask = [sender draggingSourceOperationMask];
  pboard = [sender draggingPasteboard];

  if ( [pboard types] != nil) {
    return NSDragOperationEvery;
  } else {

  return NSDragOperationNone;
}
}


- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
  return YES;
}

//perform drag operations
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
  NSPasteboard *pboard;
  NSDragOperation sourceDragMask;
  return YES;

}

@end


DNDView *dropview;

//Tk window methods
int RegisterDragTypes(ClientData clientData, Tcl_Interp *ip,
                              int objc, Tcl_Obj *CONST objv[]) {
  if (objc != 3) {
    Tcl_WrongNumArgs(ip, 1, objv, "path types-list");
    return TCL_ERROR;
  }

  Tk_Window path = Tk_NameToWindow(ip, Tcl_GetString(objv[1]), Tk_MainWindow(ip));
  Drawable d = Tk_WindowId(path);

  DNDView *dropview = [[DNDView alloc] init];

  dropview = TkMacOSXGetRootControl(d);
  [dropview registerForDraggedTypes:[NSArray arrayWithObjects: NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];

  return TCL_OK;

}

int UnregisterDragTypes(ClientData clientData, Tcl_Interp *ip,
                              int objc, Tcl_Obj *CONST objv[]) {
  if (objc != 2) {
    Tcl_WrongNumArgs(ip, 1, objv, "path");
    return TCL_ERROR;
  }

  Tk_Window path = Tk_NameToWindow(ip, Tcl_GetString(objv[1]), Tk_MainWindow(ip));
  Drawable d = Tk_WindowId(path);

  DNDView *dropview = [[DNDView alloc] init];

  dropview = TkMacOSXGetRootControl(d);
  [dropview unregisterDraggedTypes];

  return TCL_OK;

}


//initalize the package in the tcl interpreter, create tcl commands
int Macdnd_Init (Tcl_Interp *ip) {
	
  //set up an autorelease pool
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
  if (Tcl_InitStubs(ip, "8.5", 0) == NULL) {
    return TCL_ERROR;
  }

  Tcl_CreateObjCommand(ip, "::macdnd::registerdragtypes", RegisterDragTypes,(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
  Tcl_CreateObjCommand(ip, "::macdnd::unregisterdragtypes", UnregisterDragTypes,(ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
		

  if (Tcl_PkgProvide(ip, "MacDND", "1.0") != TCL_OK) {
    return TCL_ERROR;
  }

  //release memory
  [pool release];
	
  return TCL_OK;
	

}

int Macdnd_SafeInit(Tcl_Interp *ip) {
  return Macdnd_Init(ip);
}



