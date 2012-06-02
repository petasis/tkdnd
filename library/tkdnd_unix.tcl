#
# tkdnd_unix.tcl --
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

namespace eval xdnd {
  variable _types {}
  variable _typelist {}
  variable _codelist {}
  variable _actionlist {}
  variable _pressedkeys {}
  variable _action {}
  variable _common_drag_source_types {}
  variable _common_drop_target_types {}
  variable _drag_source {}
  variable _drop_target {}

  proc debug {msg} {
    puts $msg
  };# debug
};# namespace xdnd

# ----------------------------------------------------------------------------
#  Command xdnd::_HandleXdndEnter
# ----------------------------------------------------------------------------
proc xdnd::_HandleXdndEnter { path drag_source typelist } {
  variable _typelist;                 set _typelist    $typelist
  variable _pressedkeys;              set _pressedkeys 1
  variable _action;                   set _action      {}
  variable _common_drag_source_types; set _common_drag_source_types {}
  variable _common_drop_target_types; set _common_drop_target_types {}
  variable _actionlist
  variable _drag_source;              set _drag_source $drag_source
  variable _drop_target;              set _drop_target {}
  variable _actionlist;               set _actionlist  \
                                           {copy move link ask private}
  # debug "\n==============================================================="
  # debug "xdnd::_HandleXdndEnter: path=$path, drag_source=$drag_source,\
  #        typelist=$typelist"
  # debug "xdnd::_HandleXdndEnter: ACTION: default"
  return default
};# xdnd::_HandleXdndEnter

# ----------------------------------------------------------------------------
#  Command xdnd::_HandleXdndPosition
# ----------------------------------------------------------------------------
proc xdnd::_HandleXdndPosition { drop_target rootX rootY {drag_source {}} } {
  variable _types
  variable _typelist
  variable _actionlist
  variable _pressedkeys
  variable _action
  variable _common_drag_source_types
  variable _common_drop_target_types
  variable _drag_source
  variable _drop_target
  # debug "xdnd::_HandleXdndPosition: drop_target=$drop_target,\
  #            _drop_target=$_drop_target, rootX=$rootX, rootY=$rootY"

  if {![info exists _drag_source] && ![string length $_drag_source]} {
    # debug "xdnd::_HandleXdndPosition: no or empty _drag_source:\
    #               return refuse_drop"
    return refuse_drop
  }

  if {$drag_source ne "" && $drag_source ne $_drag_source} {
    debug "XDND position event from unexpected source: $_drag_source\
           != $drag_source"
    return refuse_drop
  }

  ## Does the new drop target support any of our new types? 
  set _types [bind $drop_target <<DropTargetTypes>>]
  # debug ">> Accepted types: $drop_target $_types"
  if {[llength $_types]} {
    ## Examine the drop target types, to find at least one match with the drag
    ## source types...
    set supported_types [_supported_types $_typelist]
    foreach type $_types {
      foreach matched [lsearch -glob -all -inline $supported_types $type] {
        ## Drop target supports this type.
        lappend common_drag_source_types $matched
        lappend common_drop_target_types $type
      }
    }
  }
  
  # debug "\t($_drop_target) -> ($drop_target)"
  if {$drop_target != $_drop_target} {
    if {[string length $_drop_target]} {
      ## Call the <<DropLeave>> event.
      # debug "\t<<DropLeave>> on $_drop_target"
      set cmd [bind $_drop_target <<DropLeave>>]
      if {[string length $cmd]} {
        set _codelist $_typelist
        set cmd [string map [list %W $_drop_target %X $rootX %Y $rootY \
          %CST \{$_common_drag_source_types\} \
          %CTT \{$_common_drop_target_types\} \
          %ST  \{$_typelist\}    %TT \{$_types\} \
          %A   \{$_action\}      %a \{$_actionlist\} \
          %b   \{$_pressedkeys\} %m \{$_pressedkeys\} \
          %D   \{\}              %e <<DropLeave>> \
          %L   \{$_typelist\}    %% % \
          %t   \{$_typelist\}    %T  \{[lindex $_common_drag_source_types 0]\} \
          %c   \{$_codelist\}    %C  \{[lindex $_codelist 0]\} \
          ] $cmd]
        uplevel \#0 $cmd
      }
    }
    set _drop_target {}

    if {[info exists common_drag_source_types]} {
      set _action copy
      set _common_drag_source_types $common_drag_source_types
      set _common_drop_target_types $common_drop_target_types
      set _drop_target $drop_target
      ## Drop target supports at least one type. Send a <<DropEnter>>.
      # puts "<<DropEnter>> -> $drop_target"
      set cmd [bind $drop_target <<DropEnter>>]
      if {[string length $cmd]} {
        focus $drop_target
        set _codelist $_typelist
        set cmd [string map [list %W $drop_target %X $rootX %Y $rootY \
          %CST \{$_common_drag_source_types\} \
          %CTT \{$_common_drop_target_types\} \
          %ST  \{$_typelist\}    %TT \{$_types\} \
          %A   $_action          %a  \{$_actionlist\} \
          %b   \{$_pressedkeys\} %m  \{$_pressedkeys\} \
          %D   \{\}              %e  <<DropEnter>> \
          %L   \{$_typelist\}    %%  % \
          %t   \{$_typelist\}    %T  \{[lindex $_common_drag_source_types 0]\} \
          %c   \{$_codelist\}    %C  \{[lindex $_codelist 0]\} \
          ] $cmd]
        set _action [uplevel \#0 $cmd]
      }
    }
    set _drop_target $drop_target
  }
  
  set _action refuse_drop
  set _drop_target {}
  if {[info exists common_drag_source_types]} {
    set _action copy
    set _common_drag_source_types $common_drag_source_types
    set _common_drop_target_types $common_drop_target_types
    set _drop_target $drop_target
    ## Drop target supports at least one type. Send a <<DropPosition>>.
    set cmd [bind $drop_target <<DropPosition>>]
    if {[string length $cmd]} {
      set _codelist $_typelist
      set cmd [string map [list %W $drop_target %X $rootX %Y $rootY \
        %CST \{$_common_drag_source_types\} \
        %CTT \{$_common_drop_target_types\} \
        %ST  \{$_typelist\}    %TT \{$_types\} \
        %A   $_action          %a  \{$_actionlist\} \
        %b   \{$_pressedkeys\} %m  \{$_pressedkeys\} \
        %D   \{\}              %e  <<DropPosition>> \
        %L   \{$_typelist\}    %%  % \
        %t   \{$_typelist\}    %T  \{[lindex $_common_drag_source_types 0]\} \
        %c   \{$_codelist\}    %C  \{[lindex $_codelist 0]\} \
        ] $cmd]
      set _action [uplevel \#0 $cmd]
    }
  }
  # Return values: copy, move, link, ask, private, refuse_drop, default
  # debug "xdnd::_HandleXdndPosition: ACTION: $_action"
  return $_action
};# xdnd::_HandleXdndPosition

# ----------------------------------------------------------------------------
#  Command xdnd::_HandleXdndLeave
# ----------------------------------------------------------------------------
proc xdnd::_HandleXdndLeave {  } {
  variable _types
  variable _typelist
  variable _actionlist
  variable _pressedkeys
  variable _action
  variable _common_drag_source_types
  variable _common_drop_target_types
  variable _drag_source
  variable _drop_target
  if {![info exists _drop_target]} {set _drop_target {}}
  # debug "xdnd::_HandleXdndLeave: _drop_target=$_drop_target"
  if {[info exists _drop_target] && [string length $_drop_target]} {
    set cmd [bind $_drop_target <<DropLeave>>]
    if {[string length $cmd]} {
      set _codelist $_typelist
      set cmd [string map [list %W $_drop_target %X 0 %Y 0 \
        %CST \{$_common_drag_source_types\} \
        %CTT \{$_common_drop_target_types\} \
        %ST  \{$_typelist\}    %TT \{$_types\} \
        %A   \{$_action\}      %a  \{$_actionlist\} \
        %b   \{$_pressedkeys\} %m  \{$_pressedkeys\} \
        %D   \{\}              %e  <<DropLeave>> \
        %L   \{$_typelist\}    %%  % \
        %t   \{$_typelist\}    %T  \{[lindex $_common_drag_source_types 0]\} \
        %c   \{$_codelist\}    %C  \{[lindex $_codelist 0]\} \
        ] $cmd]
      set _action [uplevel \#0 $cmd]
    }
  }
  foreach var {_types _typelist _actionlist _pressedkeys _action
               _common_drag_source_types _common_drop_target_types
               _drag_source _drop_target} {
    set $var {}
  }
};# xdnd::_HandleXdndLeave

# ----------------------------------------------------------------------------
#  Command xdnd::_HandleXdndDrop
# ----------------------------------------------------------------------------
proc xdnd::_HandleXdndDrop { time } {
  variable _types
  variable _typelist
  variable _actionlist
  variable _pressedkeys
  variable _action
  variable _common_drag_source_types
  variable _common_drop_target_types
  variable _drag_source
  variable _drop_target
  set rootX 0
  set rootY 0

  # puts "xdnd::_HandleXdndDrop: $time"

  if {![info exists _drag_source] && ![string length $_drag_source]} {
    return refuse_drop
  }
  if {![info exists _drop_target] && ![string length $_drop_target]} {
    return refuse_drop
  }
  if {![llength $_common_drag_source_types]} {return refuse_drop}
  ## Get the dropped data.
  set data [_GetDroppedData $time]
  ## Try to select the most specific <<Drop>> event.
  foreach type [concat $_common_drag_source_types $_common_drop_target_types] {
    set type [_platform_independent_type $type]
    set cmd [bind $_drop_target <<Drop:$type>>]
    if {[string length $cmd]} {
      set _codelist $_typelist
      set cmd [string map [list %W $_drop_target %X $rootX %Y $rootY \
        %CST \{$_common_drag_source_types\} \
        %CTT \{$_common_drop_target_types\} \
        %ST  \{$_typelist\}    %TT \{$_types\} \
        %A   $_action          %a \{$_actionlist\} \
        %b   \{$_pressedkeys\} %m \{$_pressedkeys\} \
        %D   [list $data]      %e <<Drop:$type>> \
        %L   \{$_typelist\}    %% % \
        %t   \{$_typelist\}    %T  \{[lindex $_common_drag_source_types 0]\} \
        %c   \{$_codelist\}    %C  \{[lindex $_codelist 0]\} \
        ] $cmd]
      return [uplevel \#0 $cmd]
    }
  }
  set cmd [bind $_drop_target <<Drop>>]
  if {[string length $cmd]} {
    set _codelist $_typelist
    set cmd [string map [list %W $_drop_target %X $rootX %Y $rootY \
      %CST \{$_common_drag_source_types\} \
      %CTT \{$_common_drop_target_types\} \
      %ST  \{$_typelist\}    %TT \{$_types\} \
      %A   $_action          %a \{$_actionlist\} \
      %b   \{$_pressedkeys\} %m \{$_pressedkeys\} \
      %D   [list $data]      %e <<Drop>> \
      %L   \{$_typelist\}    %% % \
      %t   \{$_typelist\}    %T  \{[lindex $_common_drag_source_types 0]\} \
      %c   \{$_codelist\}    %C  \{[lindex $_codelist 0]\} \
      ] $cmd]
    set _action [uplevel \#0 $cmd]
  }
  # Return values: XdndActionCopy, XdndActionMove,    XdndActionLink,
  #                XdndActionAsk,  XdndActionPrivate, refuse_drop
  return $_action
};# xdnd::_HandleXdndDrop

# ----------------------------------------------------------------------------
#  Command xdnd::_GetDroppedData
# ----------------------------------------------------------------------------
proc xdnd::_GetDroppedData { time } {
  variable _drag_source
  variable _drop_target
  variable _common_drag_source_types
  variable _use_tk_selection
  if {![llength $_common_drag_source_types]} {
    error "no common data types between the drag source and drop target widgets"
  }
  ## Is drag source in this application?
  if {[catch {winfo pathname -displayof $_drop_target $_drag_source} p]} {
    set _use_tk_selection 0
  } else {
    set _use_tk_selection 1
  }
  foreach type $_common_drag_source_types {
    # puts "TYPE: $type ($_drop_target)"
    # _get_selection $_drop_target $time $type
    if {$_use_tk_selection} {
      if {![catch {
        selection get -displayof $_drop_target -selection XdndSelection \
                      -type $type
                                              } result options]} {
        return [_normalise_data $type $result]
      }
    } else {
      # puts "_selection_get -displayof $_drop_target -selection XdndSelection \
      #                 -type $type -time $time"
      if {![catch {
        _selection_get -displayof $_drop_target -selection XdndSelection \
                      -type $type -time $time
                                              } result options]} {
        return [_normalise_data $type $result]
      }
    }
  }
  return -options $options $result
};# xdnd::_GetDroppedData

# ----------------------------------------------------------------------------
#  Command xdnd::_GetDragSource
# ----------------------------------------------------------------------------
proc xdnd::_GetDragSource {  } {
  variable _drag_source
  return $_drag_source
};# xdnd::_GetDragSource

# ----------------------------------------------------------------------------
#  Command xdnd::_GetDropTarget
# ----------------------------------------------------------------------------
proc xdnd::_GetDropTarget {  } {
  variable _drop_target
  if {[string length $_drop_target]} {
    return [winfo id $_drop_target]
  }
  return 0
};# xdnd::_GetDropTarget

# ----------------------------------------------------------------------------
#  Command xdnd::_supported_types
# ----------------------------------------------------------------------------
proc xdnd::_supported_types { types } {
  set new_types {}
  foreach type $types {
    if {[_supported_type $type]} {lappend new_types $type}
  }
  return $new_types
}; # xdnd::_supported_types

# ----------------------------------------------------------------------------
#  Command xdnd::_platform_specific_types
# ----------------------------------------------------------------------------
proc xdnd::_platform_specific_types { types } {
  set new_types {}
  foreach type $types {
    set new_types [concat $new_types [_platform_specific_type $type]]
  }
  return $new_types
}; # xdnd::_platform_specific_types

# ----------------------------------------------------------------------------
#  Command xdnd::_normalise_data
# ----------------------------------------------------------------------------
proc xdnd::_normalise_data { type data } {
  # Tk knows how to interpret the following types:
  #    STRING, TEXT, COMPOUND_TEXT
  #    UTF8_STRING
  # Else, it returns a list of 8 or 32 bit numbers... 
  switch $type {
    STRING - UTF8_STRING - TEXT - COMPOUND_TEXT {return $data}
    text/html     -
    text/plain    {
      return [string map {\r\n \n} \
        [encoding convertfrom utf-8 [tkdnd::bytes_to_string $data]]]
    }
    text/uri-list {
      if {[catch {tkdnd::bytes_to_string $data} string]} {
        set string $data
      }
      ## Get rid of \r\n
      set string [string trim [string map {\r\n \n} $string]]
      set files {}
      foreach quoted_file [split $string] {
        set file [encoding convertfrom utf-8 [tkdnd::urn_unquote $quoted_file]]
        switch -glob $file {
          file://*  {lappend files [string range $file 7 end]}
          ftp://*   -
          https://* -
          http://*  {lappend files $quoted_file}
          default   {lappend files $file}
        }
      }
      return $files
    }
    text/x-moz-url - 
    application/q-iconlist -
    default    {return $data}
  }
}; # xdnd::_normalise_data

# ----------------------------------------------------------------------------
#  Command xdnd::_platform_specific_type
# ----------------------------------------------------------------------------
proc xdnd::_platform_specific_type { type } {
  switch $type {
    DND_Text   {return [list text/plain UTF8_STRING STRING]}
    DND_Files  {return [list text/uri-list]}
    default    {return [list $type]}
  }
}; # xdnd::_platform_specific_type

# ----------------------------------------------------------------------------
#  Command xdnd::_platform_independent_type
# ----------------------------------------------------------------------------
proc xdnd::_platform_independent_type { type } {
  switch $type {
    UTF8_STRING   -
    STRING        -
    text/plain    {return DND_Text}
    text/uri-list {return DND_Files}
    default       {return [list $type]}
  }
}; # xdnd::_platform_independent_type

# ----------------------------------------------------------------------------
#  Command xdnd::_supported_type
# ----------------------------------------------------------------------------
proc xdnd::_supported_type { type } {
  switch $type {
    {text/plain;charset=UTF-8} - text/plain -
    text/uri-list {return 1}
  }
  return 0
}; # xdnd::_supported_type
