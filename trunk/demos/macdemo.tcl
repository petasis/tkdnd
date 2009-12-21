##this package demonstrates TkDND on the Mac. 

package require tkdnd


pack [text .t -bg white ] -fill both -expand no -side top

tkdnd::drop_target register .t *

bind .t <<Drop>> {%W insert end %D}

#Note these two bindings are no-op on the Mac; the C-level impelmentation takes care of the changing cursor. 
bind .t <<DropEnter>> { %W configure -bg red}
bind .t <<DropLeave>> {list copy; %W configure -bg white}

pack [text .f -bg blue] -fill both -expand no -side top
tkdnd::drop_target register .f *

bind .f <<Drop>> {%W insert end %D}
