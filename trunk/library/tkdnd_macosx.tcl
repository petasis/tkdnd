#
# tkdnd_macosx.tcl --
# 
#    This file implements some utility procedures that are used by the TkDND
#    package.
#
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

#basic API for Mac Drag and Drop

#two data types supported: strings and file paths

#two commands at C level: ::macdnd::registerdragwidget and ::macdnd::unregisterdragwidget

#data retrieval mechanism: text or file paths are copied from drag clipboard to system clipboard and retrieved via [clipboard get]; array of file paths is converted to single tab-separated string, can be split into Tcl list

if {[tk windowingsystem] eq "aqua" && "AppKit" ni [winfo server .]} {
    error {TkAqua Cocoa required}
}

namespace eval macdnd {
    variable _types {}
    variable _typelist {}
    variable _actionlist {}
    variable _pressedkeys {}
    variable _action {}
    variable _common_drag_source_types {}
    variable _common_drop_target_types {}
    variable _drag_source {}
    variable _drop_target {}
};# namespace macdnd

# ----------------------------------------------------------------------------
#  Command macdnd::_HandleEnter
# ----------------------------------------------------------------------------
proc macdnd::_HandleEnter { path drag_source typelist } {
    global _macpath
    variable _typelist;                 set _typelist    $typelist
    variable _pressedkeys;              set _pressedkeys 1
    variable _action;                   set _action      {}
    variable _common_drag_source_types; set _common_drag_source_types {}
    variable _common_drop_target_types; set _common_drop_target_types {}
    variable _actionlist
    variable _drag_source;              set _drag_source $drag_source
    variable _drop_target;            set _drop_target $_macpath ;# pass 
    variable _actionlist;               set _actionlist  \
	{copy move link ask private}
    #  puts "macdnd::_HandleEnter: path=$path, drag_source=$drag_source,\
	#       typelist=$typelist"

    puts "macdnd::_HandleXdndEnter  ($_drop_target)"
    bind $_drop_target <<DropEnter>>
    update
    return default
};# macdnd::_HandleEnter

# -----------------------------------------------------------------------------------------
#  Command macdnd::_HandleXdndPosition 
# -----------------------------------------------------------------------------------------
proc macdnd::_HandleXdndPosition { drop_target rootX rootY } {

    global _macpath
    variable _types
    variable _typelist
    variable _actionlist
    variable _pressedkeys
    variable _action
    variable _common_drag_source_types
    variable _common_drop_target_types
    variable _drag_source
    variable _drop_target


    #This command is  not implemented at the C level for OSX because it prevents drops.

    # puts "macdnd::_HandleXdndPosition: drop_target=$drop_target,\
	#       _drop_target=$_drop_target, rootX=$rootX, rootY=$rootY"

    if {![info exists _drag_source] && ![string length $_drag_source]} {
	return refuse_drop
    }
    #Does the new drop target support any of our new types? 
    set _types [bind $drop_target <<DropTargetTypes>>]
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
    
    puts "($_drop_target) -> ($drop_target)"
    if {$drop_target != $_drop_target} {
	puts "no drop target"
	if {[string length $_drop_target]} {
	    ## Call the <<DropLeave>> event.
	    set cmd [bind $_drop_target <<DropLeave>>]
	    if {[string length $cmd]} {
		set cmd [string map [list %W $_drop_target %X $rootX %Y $rootY \
					 %CST \{$_common_drag_source_types\} \
					 %CTT \{$_common_drop_target_types\} \
					 %ST  \{$_typelist\}    %TT \{$_types\} \
					 %A   \{$_action\}      %a \{$_actionlist\} \
					 %b   \{$_pressedkeys\} %m \{$_pressedkeys\} \
					 %D   \{\}              %e <<DropLeave>> \
					 %L   \{$_typelist\}    %% % \
					 %t   \{$_typelist\}    %T \{\}] $cmd]
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
		set cmd [string map [list %W $drop_target %X $rootX %Y $rootY \
					 %CST \{$_common_drag_source_types\} \
					 %CTT \{$_common_drop_target_types\} \
					 %ST  \{$_typelist\}    %TT \{$_types\} \
					 %A   $_action          %a  \{$_actionlist\} \
					 %b   \{$_pressedkeys\} %m  \{$_pressedkeys\} \
					 %D   \{\}              %e  <<DropEnter>> \
					 %L   \{$_typelist\}    %%  % \
					 %t   \{$_typelist\}    %T  \{\}] $cmd]
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
	    set cmd [string map [list %W $drop_target %X $rootX %Y $rootY \
				     %CST \{$_common_drag_source_types\} \
				     %CTT \{$_common_drop_target_types\} \
				     %ST  \{$_typelist\}    %TT \{$_types\} \
				     %A   $_action          %a  \{$_actionlist\} \
				     %b   \{$_pressedkeys\} %m  \{$_pressedkeys\} \
				     %D   \{\}              %e  <<DropPosition>> \
				     %L   \{$_typelist\}    %%  % \
				     %t   \{$_typelist\}    %T  \{\}] $cmd]
	    set _action [uplevel \#0 $cmd]
	}
    }
    # Return values: copy, move, link, ask, private, refuse_drop, default
    return $_action
};#macdnd::_HandleXdndPosition

# ----------------------------------------------------------------------------
#  Command macdnd::_HandleXdndLeave
# ----------------------------------------------------------------------------
proc macdnd::_HandleXdndLeave { args  } {
    variable _types
    variable _typelist
    variable _actionlist
    variable _pressedkeys
    variable _action
    variable _common_drag_source_types
    variable _common_drop_target_types
    variable _drag_source
    variable _drop_target
    global _macpath

    puts "macdnd::_HandleXdndLeave  ($_drop_target)"
    if {[info exists _drop_target] && [string length $_drop_target]} {
	set cmd [bind $_drop_target <<DropLeave>>]
	if {[string length $cmd]} {
	    set cmd [string map [list %W $_drop_target %X 0 %Y 0 \
				     %CST \{$_common_drag_source_types\} \
				     %CTT \{$_common_drop_target_types\} \
				     %ST  \{$_typelist\}    %TT \{$_types\} \
				     %A   \{$_action\}      %a  \{$_actionlist\} \
				     %b   \{$_pressedkeys\} %m  \{$_pressedkeys\} \
				     %D   \{\}              %e  <<DropLeave>> \
				     %L   \{$_typelist\}    %%  % \
				     %t   \{$_typelist\}    %T  \{\}] $cmd]
	    set _action [uplevel \#0 $cmd]
	}
    }
    foreach var {_types _typelist _actionlist _pressedkeys _action
	_common_drag_source_types _common_drop_target_types
	_drag_source _drop_target} {
	set $var {}
    }
};# macdnd::_HandleXdndLeave

# ----------------------------------------------------------------------------
#  Command macdnd::_HandleXdndDrop
# ----------------------------------------------------------------------------
proc macdnd::_HandleXdndDrop { args } {
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

    global _macpath

    #these lines interfere with the drop, so they are commented out

    # if {![info exists _drag_source] && ![string length $_drag_source]} {
    #   return refuse_drop
    # }
    # if {![info exists _drop_target] && ![string length $_drop_target]} {
    #   return refuse_drop
    # }
    # if {![llength $_common_drag_source_types]} {return refuse_drop}

    ## Get the drop target and dropped data.
    # set _drop_target [winfo toplevel $_macpath]
    set data [_GetDroppedData]

    ## Try to select the most specific <<Drop>> event.
    foreach type [concat $_common_drag_source_types $_common_drop_target_types] {
	set type [_platform_independent_type $type]
	set cmd [bind $_drop_target <<Drop:$type>>]
	if {[string length $cmd]} {
	    set cmd [string map [list %W $_drop_target %X $rootX %Y $rootY \
				     %CST \{$_common_drag_source_types\} \
				     %CTT \{$_common_drop_target_types\} \
				     %ST  \{$_typelist\}    %TT \{$_types\} \
				     %A   $_action          %a \{$_actionlist\} \
				     %b   \{$_pressedkeys\} %m \{$_pressedkeys\} \
				     %D   \{$data\}         %e <<Drop:$type>> \
				     %L   \{$_typelist\}    %% % \
				     %t   \{$_typelist\}    %T \{\}] $cmd]
	    return [uplevel \#0 $cmd]
	}
    }
    set cmd [bind $_drop_target <<Drop>>]
    if {[string length $cmd]} {
	set cmd [string map [list %W $_drop_target %X $rootX %Y $rootY \
				 %CST \{$_common_drag_source_types\} \
				 %CTT \{$_common_drop_target_types\} \
				 %ST  \{$_typelist\}    %TT \{$_types\} \
				 %A   $_action          %a \{$_actionlist\} \
				 %b   \{$_pressedkeys\} %m \{$_pressedkeys\} \
				 %D   \{$data\}         %e <<Drop>> \
				 %L   \{$_typelist\}    %% % \
				 %t   \{$_typelist\}    %T \{\}] $cmd]
	set _action [uplevel \#0 $cmd]
    }
    # Return values: XdndActionCopy, XdndActionMove,    XdndActionLink,
    #                XdndActionAsk,  XdndActionPrivate, refuse_drop
    return $_action
};# macdnd::_HandleXdndDrop

# ----------------------------------------------------------------------------
#  Command macdnd::_GetDroppedData
# ----------------------------------------------------------------------------
proc macdnd::_GetDroppedData {  } {
    variable _drop_target

    ##must use [clipboard get] because Xselection code returns error
    return [clipboard get]\n
};# macdnd::_GetDroppedData

# ----------------------------------------------------------------------------
#  Command macdnd::_GetDragSource
# ----------------------------------------------------------------------------
proc macdnd::_GetDragSource {  } {
    variable _drag_source
    return $_drag_source
};# macdnd::_GetDragSource

# ----------------------------------------------------------------------------
#  Command macdnd::_GetDropTarget
# ----------------------------------------------------------------------------
proc macdnd::_GetDropTarget {  } {
    variable _drop_target
    if {[string length $_drop_target]} {
	return [winfo id $_drop_target]
    }
    return 0
};# macdnd::_GetDropTarget

# ----------------------------------------------------------------------------
#  Command macdnd::_supported_types
# ----------------------------------------------------------------------------
proc macdnd::_supported_types { types } {
    set new_types {}
    foreach type $types {
	if {[_supported_type $type]} {lappend new_types $type}
    }
    return $new_types
}; # macdnd::_supported_types

# ----------------------------------------------------------------------------
#  Command macdnd::_platform_specific_types
# ----------------------------------------------------------------------------
proc macdnd::_platform_specific_types { types } {
    set new_types {}
    foreach type $types {
	set new_types [concat $new_types [_platform_specific_type $type]]
    }
    return $new_types
}; # macdnd::_platform_specific_types

# ----------------------------------------------------------------------------
#  Command macdnd::_normalise_data
# ----------------------------------------------------------------------------
proc macdnd::_normalise_data { type data } {
    switch $type {
	CF_HDROP   {return [encoding convertfrom $data]}
	default    {return $data}
    }
}; # macdnd::_normalise_data

# ----------------------------------------------------------------------------
#  Command macdnd::_platform_specific_type
# ----------------------------------------------------------------------------
proc macdnd::_platform_specific_type { type } {
    switch $type {
	DND_Text   {return [list NSStringPboardType]}
	DND_Files  {return [list NSFilenamesPboardType]}
	default    {return [list $type]}
    }
}; # macdnd::_platform_specific_type

# ----------------------------------------------------------------------------
#  Command macdnd::_platform_independent_type
# ----------------------------------------------------------------------------
proc macdnd::_platform_independent_type { type } {
    switch $type {
	NSStringPboardType      {return DND_Text}
	NSFilenamesPboardType   {return DND_Files}
	default                 {return [list $type]}
    }
}; # macdnd::_platform_independent_type

# ----------------------------------------------------------------------------
#  Command macdnd::_supported_type
# ----------------------------------------------------------------------------
proc macdnd::_supported_type { type } {
    return 1
    switch $type {
	{text/plain;charset=UTF-8} - text/plain -
	text/uri-list {return 1}
    }
    return 0
}; # macdnd::_supported_type
