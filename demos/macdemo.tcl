##this package demonstrates TkDND on the Mac. 

package require tkdnd

pack [text .t -bg white] -fill both -expand yes

tkdnd::drop_target register .t *

#Note that when you register a widget, you must apply bindings to its toplevel parent. The C impelmentation of tkdnd on the Mac does not work on child widgets, only the toplevel window. 

bind . <<Drop>> {.t insert end %D }

##Note these two bindings are no-op on the Mac; the C-level impelmentation takes care of the changing cursor. 
bind . <<DropEnter>> {.t configure -bg red}
bind . <<DropLeave>> {.t configure -bg white}



