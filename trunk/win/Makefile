###############################################################################
##
## Makefile.vc - Microsoft Visual C++ makefile
##
###############################################################################

##
## Please, update the following parameters to reflect your system.
##

## Location of the Tcl installation:
TCL                   = C:\Program Files\Tcl
TCL_VERSION           = 8.4
TCL_VERSION_NO_DOTS   = 84
TKDND_VERSION         = 2.2
TKDND_VERSION_NO_DOTS = 22

##
## Usage:
## nmake -f Makefile.vc
##

##
## No need to modify bellow this point...
##

!if !exist("makefile.vc") && !exist("makefile")
MSG = ^
You must run this makefile only from the directory it is in.^
Please `cd` to its location first.
!error $(MSG)
!endif

## Include directories:
INCDIR = -I"$(TCL)\include" \
	 -I"$(TCL)\include$(TCL_VERSION)"

## library directories:
LIBDIR = -libpath:"$(TCL)\lib"

## Declarations common to all compiler options:
cflags = -nologo -c -W3 -MT -EHsc -YX -FD -O2 -Op -Gs -LD \
	 -D "WIN32" -D "NDEBUG" -D "_WINDOWS" -D "_MBCS" \
	 -D "_USRDLL" -D "USE_TCL_STUBS" -D "USE_TK_STUBS"

## Declarations common to all linker options
lflags	= -nologo -machine:I386 -subsystem:windows -release \
          -opt:ref -opt:icf,3 -dll \
	  -incremental:no -nodefaultlib:"MSVCRT.LIB"

LIBS    = kernel32.lib user32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib

cc32            = $(CC)   # built-in default.
link32          = link
lib32           = lib
MKDIR           = mkdir
MV              = move
CP              = copy
RM              = del
RMDIR           = rmdir /S /Q

all:
	$(cc32) $(cflags) $(INCDIR) TkDND_OleDND.cpp \
	  -D PACKAGE_NAME="\"tkdnd\"" -D PACKAGE_VERSION="\"$(TKDND_VERSION)\"" 
	$(link32) $(lflags) $(LIBDIR) tclstub$(TCL_VERSION_NO_DOTS).lib \
          tkstub$(TCL_VERSION_NO_DOTS).lib $(LIBS)\
	  TkDND_OleDND.obj -out:"..\libtkdnd$(TKDND_VERSION_NO_DOTS).dll"
	$(RM) ..\*.exp ..\*.lib *.idb *.pch *.obj
