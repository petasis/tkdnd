#
# tkdnd_macosx.tcl --
#
#    This file implements some utility procedures that are used by the TkDND
#    package.

#   This software is copyrighted by:
#   Georgios Petasis, Athens, Greece.
#   e-mail: petasisg@yahoo.gr, petasis@iit.demokritos.gr
#
#   Mac portions (c) 2009 Kevin Walzer/WordTech Communications LLC,
#   kw@codebykevin.com
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

#two commands at C level: ::tkdnd::macdnd::registerdragwidget, ::tkdnd::macdnd::unregisterdragwidget

#data retrieval mechanism: text or file paths are copied from drag clipboard to system clipboard and retrieved via [clipboard get]; array of file paths is converted to single tab-separated string, can be split into Tcl list

if {[tk windowingsystem] eq "aqua" && "AppKit" ni [winfo server .]} {
  error {TkAqua Cocoa required}
}

namespace eval macdnd {
  variable _dropped_data

  proc initialise {} {
    variable _tkdnd2platform
    variable _platform2tkdnd

    ## Initialize the tkdnd 2 platform & platform 2 tkdnd arrays for
    ## type conversion...
    array set _platform2tkdnd [list \
       NSPasteboardTypeString  DND_Text  \
       NSFilenamesPboardType   DND_Files \
    ]
    foreach type [array names _platform2tkdnd] {
      lappend _tkdnd2platform($_platform2tkdnd($type)) $type
    }
  };# initialise
};# namespace macdnd

# ----------------------------------------------------------------------------
#  Command macdnd::_HandleEnter
# ----------------------------------------------------------------------------
proc macdnd::_HandleEnter { path drag_source typelist } {
  ::tkdnd::xdnd::_HandleXdndEnter $path $drag_source $typelist
};# macdnd::_HandleEnter

# ----------------------------------------------------------------------------
#  Command macdnd::_HandlePosition
# ----------------------------------------------------------------------------
proc macdnd::_HandlePosition { drop_target rootX rootY } {
  ::tkdnd::xdnd::_HandleXdndPosition $drop_target $rootX $rootY
};# macdnd::_HandlePosition

# ----------------------------------------------------------------------------
#  Command macdnd::_HandleLeave
# ----------------------------------------------------------------------------
proc macdnd::_HandleLeave { args  } {
  ::tkdnd::xdnd::_HandleXdndLeave
};# macdnd::_HandleLeave

# ----------------------------------------------------------------------------
#  Command macdnd::_HandleDrop
# ----------------------------------------------------------------------------
proc macdnd::_HandleDrop { drop_target data args } {
  variable _dropped_data
  set _dropped_data $data
  ::tkdnd::xdnd::_HandleXdndDrop 0
};# macdnd::_HandleDrop

# ----------------------------------------------------------------------------
#  Command macdnd::_GetDroppedData
# ----------------------------------------------------------------------------
proc macdnd::_GetDroppedData { time } {
  variable _dropped_data
  return  $_dropped_data
};# macdnd::_GetDroppedData
proc xdnd::_GetDroppedData { time } {
  ::tkdnd::macdnd::_GetDroppedData $time
};# xdnd::_GetDroppedData

# ----------------------------------------------------------------------------
#  Command macdnd::_GetDragSource
# ----------------------------------------------------------------------------
proc macdnd::_GetDragSource {  } {
  ::tkdnd::xdnd::_GetDragSource
};# macdnd::_GetDragSource

# ----------------------------------------------------------------------------
#  Command macdnd::_GetDropTarget
# ----------------------------------------------------------------------------
proc macdnd::_GetDropTarget {  } {
  ::tkdnd::xdnd::_GetDropTarget
};# macdnd::_GetDropTarget

# ----------------------------------------------------------------------------
#  Command macdnd::_GetDragSourceCommonTypes
# ----------------------------------------------------------------------------
proc macdnd::_GetDragSourceCommonTypes {  } {
  ::tkdnd::xdnd::_GetDragSourceCommonTypes
};# macdnd::_GetDragSourceCommonTypes

# ----------------------------------------------------------------------------
#  Command macdnd::_GetDropTargetCommonTypes
# ----------------------------------------------------------------------------
proc macdnd::_GetDropTargetCommonTypes {  } {
  ::tkdnd::xdnd::_GetDropTargetCommonTypes
};# macdnd::_GetDropTargetCommonTypes

# ----------------------------------------------------------------------------
#  Command macdnd::_supported_types
# ----------------------------------------------------------------------------
proc macdnd::_supported_types { types } {
  ::tkdnd::xdnd::_supported_types $types
}; # macdnd::_supported_types

# ----------------------------------------------------------------------------
#  Command macdnd::_platform_specific_types
# ----------------------------------------------------------------------------
proc macdnd::_platform_specific_types { types } {
  ::tkdnd::xdnd::_platform_specific_types $types
}; # macdnd::_platform_specific_types

# ----------------------------------------------------------------------------
#  Command macdnd::_normalise_data
# ----------------------------------------------------------------------------
proc macdnd::_normalise_data { type data } {
  ::tkdnd::xdnd::_normalise_data $type $data
}; # macdnd::_normalise_data

# ----------------------------------------------------------------------------
#  Command macdnd::_platform_specific_type
# ----------------------------------------------------------------------------
proc macdnd::_platform_specific_type { type } {
  variable _tkdnd2platform
  if {[info exists _tkdnd2platform($type)]} {
    return $_tkdnd2platform($type)
  }
  list $type
}; # macdnd::_platform_specific_type
proc xdnd::_platform_specific_type { type } {
  ::tkdnd::macdnd::_platform_specific_type $type
}; # xdnd::_platform_specific_type

# ----------------------------------------------------------------------------
#  Command macdnd::_platform_independent_type
# ----------------------------------------------------------------------------
proc macdnd::_platform_independent_type { type } {
  variable _platform2tkdnd
  if {[info exists _platform2tkdnd($type)]} {
    return $_platform2tkdnd($type)
  }
  return $type
}; # macdnd::_platform_independent_type
proc xdnd::_platform_independent_type { type } {
  ::tkdnd::macdnd::_platform_independent_type $type
}; # xdnd::_platform_independent_type

# ----------------------------------------------------------------------------
#  Command macdnd::_supported_type
# ----------------------------------------------------------------------------
proc macdnd::_supported_type { type } {
  variable _platform2tkdnd
  if {[info exists _platform2tkdnd($type)]} {
    return 1
  }
  return 0
}; # macdnd::_supported_type
proc xdnd::_supported_type { type } {
  ::tkdnd::macdnd::_supported_type $type
}; # xdnd::_supported_type
