#
# tkdnd.tcl --
# 
#    This file implements some utility procedures that are used by the TkDND
#    package.
#
# This software is copyrighted by:
# George Petasis, National Centre for Scientific Research "Demokritos",
# Aghia Paraskevi, Athens, Greece.
# e-mail: petasis@iit.demokritos.gr
#
# The following terms apply to all files associated
# with the software unless explicitly disclaimed in individual files.
#
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors
# and need not follow the licensing terms described here, provided that
# the new terms are clearly indicated on the first page of each file where
# they apply.
# 
# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
# DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# 
# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
#

package require Tk

namespace eval tkdnd {
  variable _topw ".drag"
  variable _tabops
  variable _state
  variable _x0
  variable _y0
  variable _platform_namespace
  variable _drop_file_temp_dir
  variable _auto_update 1

  variable _windowingsystem

  bind TkDND_Drag1 <ButtonPress-1> {tkdnd::_begin_drag press  %W %s %X %Y}
  bind TkDND_Drag1 <B1-Motion>     {tkdnd::_begin_drag motion %W %s %X %Y}
  bind TkDND_Drag2 <ButtonPress-2> {tkdnd::_begin_drag press  %W %s %X %Y}
  bind TkDND_Drag2 <B2-Motion>     {tkdnd::_begin_drag motion %W %s %X %Y}
  bind TkDND_Drag3 <ButtonPress-3> {tkdnd::_begin_drag press  %W %s %X %Y}
  bind TkDND_Drag3 <B3-Motion>     {tkdnd::_begin_drag motion %W %s %X %Y}
  
  # ----------------------------------------------------------------------------
  #  Command tkdnd::initialise: Initialise the TkDND package.
  # ----------------------------------------------------------------------------
  proc initialise { dir PKG_LIB_FILE PACKAGE_NAME} {
    variable _platform_namespace
    variable _drop_file_temp_dir
    variable _windowingsystem
    global env

    switch [tk windowingsystem] {
      x11 {
        set _windowingsystem x11
      }
      win32 -
      windows {
        set _windowingsystem windows
      }
      aqua  {
        set _windowingsystem aqua
      }
      default {
        error "unknown Tk windowing system"
      }
    }

    ## Get User's home directory: We try to locate the proper path from a set of
    ## environmental variables...
    foreach var {HOME HOMEPATH USERPROFILE ALLUSERSPROFILE APPDATA} {
      if {[info exists env($var)]} {
        if {[file isdirectory $env($var)]} {
          set UserHomeDir $env($var)
          break
        }
      }
    }

    ## Should use [tk windowingsystem] instead of tcl platform array:
    ## OS X returns "unix," but that's not useful because it has its own
    ## windowing system, aqua
    ## Under windows we have to also combine HOMEDRIVE & HOMEPATH...
    if {![info exists UserHomeDir] && 
        [string equal $_windowingsystem windows] &&
        [info exists env(HOMEDRIVE)] && [info exists env(HOMEPATH)]} {
      if {[file isdirectory $env(HOMEDRIVE)$env(HOMEPATH)]} {
        set UserHomeDir $env(HOMEDRIVE)$env(HOMEPATH)
      }
    }
    ## Have we located the needed path?
    if {![info exists UserHomeDir]} {
      set UserHomeDir [pwd]
    }
    set UserHomeDir [file normalize $UserHomeDir]
    
    ## Try to locate a temporary directory...
    foreach var {TKDND_TEMP_DIR TEMP TMP} {
      if {[info exists env($var)]} {
        if {[file isdirectory $env($var)] && [file writable $env($var)]} {
          set _drop_file_temp_dir $env($var)
          break
        }
      }
    }
    if {![info exists _drop_file_temp_dir]} {
      foreach _dir [list "$UserHomeDir/Local Settings/Temp" \
                         "$UserHomeDir/AppData/Local/Temp" \
                         /tmp \
                         C:/WINDOWS/Temp C:/Temp C:/tmp \
                         D:/WINDOWS/Temp D:/Temp D:/tmp] {
        if {[file isdirectory $_dir] && [file writable $_dir]} {
          set _drop_file_temp_dir $_dir
          break
        }
      }
    }
    if {![info exists _drop_file_temp_dir]} {
      set _drop_file_temp_dir $UserHomeDir
    }
    set _drop_file_temp_dir [file native $_drop_file_temp_dir]
    
    switch $_windowingsystem {
      x11 {
        source $dir/tkdnd_unix.tcl
        set _platform_namespace xdnd
      }
      win32 -
      windows {
        source $dir/tkdnd_windows.tcl
        set _platform_namespace olednd
      }
      aqua  {
        source $dir/tkdnd_unix.tcl
        source $dir/tkdnd_macosx.tcl
        set _platform_namespace macdnd
      }
      default {
        error "unknown Tk windowing system"
      }
    }
    load $dir/$PKG_LIB_FILE $PACKAGE_NAME
    source $dir/tkdnd_compat.tcl
  };# initialise

  proc GetDropFileTempDirectory { } {
    variable _drop_file_temp_dir
    return $_drop_file_temp_dir
  }
  proc SetDropFileTempDirectory { dir } {
    variable _drop_file_temp_dir
    set _drop_file_temp_dir $dir
  }
  
};# namespace tkdnd

# ----------------------------------------------------------------------------
#  Command tkdnd::drag_source
# ----------------------------------------------------------------------------
proc tkdnd::drag_source { mode path { types {} } { event 1 } } {
  set tags [bindtags $path]
  set idx  [lsearch $tags "TkDND_Drag*"]
  switch -- $mode {
    register {
      if { $idx != -1 } {
        bindtags $path [lreplace $tags $idx $idx TkDND_Drag$event]
      } else {
        bindtags $path [concat $tags TkDND_Drag$event]
      }
      set types [platform_specific_types $types]
      set old_types [bind $path <<DragSourceTypes>>]
      foreach type $types {
        if {[lsearch $old_types $type] < 0} {lappend old_types $type}
      }
      bind $path <<DragSourceTypes>> $old_types
    }
    unregister {
      if { $idx != -1 } {
        bindtags $path [lreplace $tags $idx $idx]
      }
    }
  }
};# tkdnd::drag_source

# ----------------------------------------------------------------------------
#  Command tkdnd::drop_target
# ----------------------------------------------------------------------------
proc tkdnd::drop_target { mode path { types {} } } {
  variable _windowingsystem
  set types [platform_specific_types $types]
  switch -- $mode {
    register {
      switch $_windowingsystem {
        x11 {
          _register_types $path [winfo toplevel $path] $types
        }
        win32 -
        windows {
          _RegisterDragDrop $path
          bind <Destroy> $path {+ tkdnd::_RevokeDragDrop %W}
        }
        aqua {
          macdnd::registerdragwidget [winfo toplevel $path] $types
        }
        default {
          error "unknown Tk windowing system"
        }
      }
      set old_types [bind $path <<DropTargetTypes>>]
      set new_types {}
      foreach type $types {
        if {[lsearch -exact $old_types $type] < 0} {lappend new_types $type}
      }
      if {[llength $new_types]} {
        bind $path <<DropTargetTypes>> [concat $old_types $new_types]
      }
    }
    unregister {
      switch $_windowingsystem {
        x11 {
        }
        win32 -
        windows {
          _RevokeDragDrop $path
        }
        aqua {
          error todo
        }
        default {
          error "unknown Tk windowing system"
        }
      }
      bind $path <<DropTargetTypes>> {}
    }
  }
};# tkdnd::drop_target

# ----------------------------------------------------------------------------
#  Command tkdnd::_begin_drag
# ----------------------------------------------------------------------------
proc tkdnd::_begin_drag { event source state X Y } {
  variable _x0
  variable _y0
  variable _state

  switch -- $event {
    press {
      set _x0    $X
      set _y0    $Y
      set _state "press"
    }
    motion {
      if { ![info exists _state] } {
        # This is just extra protection. There seem to be
        # rare cases where the motion comes before the press.
        return
      }
      if { [string equal $_state "press"] } {
        if { abs($_x0-$X) > 3 || abs($_y0-$Y) > 3 } {
          set _state "done"
          _init_drag $source $state $X $Y
        }
      }
    }
  }
};# tkdnd::_begin_drag

# ----------------------------------------------------------------------------
#  Command tkdnd::_init_drag
# ----------------------------------------------------------------------------
proc tkdnd::_init_drag { source state rootX rootY } {
  # Call the <<DragInitCmd>> binding.
  set cmd [bind $source <<DragInitCmd>>]
  if {[string length $cmd]} {
    set cmd [string map [list %W $source %X $rootX %Y $rootY \
                              %S $state  %e <<DragInitCmd>> %A \{\} \
                              %t [bind $source <<DragSourceTypes>>]] $cmd]
    set info [uplevel \#0 $cmd]
    if { $info != "" } {
      variable _windowingsystem
      foreach { actions types data } $info { break }
      set types [platform_specific_types $types]
      set action refuse_drop
      switch $_windowingsystem {
        x11 {
          error "dragging from Tk widgets not yet supported"
        }
        win32 -
        windows {
          set action [_DoDragDrop $source $actions $types $data]
        }
        aqua {
          set action [macdnd::dodragdrop $source $actions $types $data]
        }
        default {
          error "unknown Tk windowing system"
        }
      }
      ## Call _end_drag to notify the widget of the result of the drag
      ## operation...
      _end_drag $source {} $action {} $data {} $state $rootX $rootY
    }
  }
};# tkdnd::_init_drag

# ----------------------------------------------------------------------------
#  Command tkdnd::_end_drag
# ----------------------------------------------------------------------------
proc tkdnd::_end_drag { source target action type data result
                        state rootX rootY } {
  set rootX 0
  set rootY 0
  # Call the <<DragEndCmd>> binding.
  set cmd [bind $source <<DragEndCmd>>]
  if {[string length $cmd]} {
    set cmd [string map [list %W $source %X $rootX %Y $rootY \
                              %S $state %e <<DragEndCmd>> %A \{$action\}] $cmd]
    set info [uplevel \#0 $cmd]
    if { $info != "" } {
      variable _windowingsystem
      foreach { actions types data } $info { break }
      set types [platform_specific_types $types]
      switch $_windowingsystem {
        x11 {
          error "dragging from Tk widgets not yet supported"
        }
        win32 -
        windows {
          set action [_DoDragDrop $source $actions $types $data]
        }
        aqua {
          macdnd::dodragdrop $source $actions $types $data
        }
        default {
          error "unknown Tk windowing system"
        }
      }
      ## Call _end_drag to notify the widget of the result of the drag
      ## operation...
      _end_drag $source {} $action {} $data {} $state $rootX $rootY
    }
  }
};# tkdnd::_end_drag

# ----------------------------------------------------------------------------
#  Command tkdnd::platform_specific_types
# ----------------------------------------------------------------------------
proc tkdnd::platform_specific_types { types } {
  variable _platform_namespace
  return [${_platform_namespace}::_platform_specific_types $types]
}; # tkdnd::platform_specific_types

# ----------------------------------------------------------------------------
#  Command tkdnd::platform_independent_types
# ----------------------------------------------------------------------------
proc tkdnd::platform_independent_types { types } {
  variable _platform_namespace
  return [${_platform_namespace}::_platform_independent_types $types]
}; # tkdnd::platform_independent_types

# ----------------------------------------------------------------------------
#  Command tkdnd::platform_specific_type
# ----------------------------------------------------------------------------
proc tkdnd::platform_specific_type { type } {
  variable _platform_namespace
  return [${_platform_namespace}::_platform_specific_type $type]
}; # tkdnd::platform_specific_type

# ----------------------------------------------------------------------------
#  Command tkdnd::platform_independent_type
# ----------------------------------------------------------------------------
proc tkdnd::platform_independent_type { type } {
  variable _platform_namespace
  return [${_platform_namespace}::_platform_independent_type $type]
}; # tkdnd::platform_independent_type
