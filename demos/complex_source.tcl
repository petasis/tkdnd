package require tkdnd
catch {console show}

##
## Drag source
##
pack [ttk::button .drag_source -text " Drag Source "] \
      -fill x -padx 20 -pady 20

tkdnd::drag_source register .drag_source

## Event <<DragInitCmd>>
bind .drag_source <<DragInitCmd>> my_data

proc my_data {} {
  list copy [list \
    DND_HTML        {<html><p>Some nice HTML text!</p></html>} \
    DND_Text        {Some nice dropped text!} \
    DND_Files [list /tmp/some_nice_dropped_file] \
  ]
};# my_data

proc my_drop {w type data action} {
  puts "Data drop ($type): \"$data\""
  $w state !active
  return $action
};# my_drop

##
## Drop targets
##
foreach type {DND_HTML DND_Text DND_Files} {
  set w [ttk::button .drop_target$type -text " Drop Target ($type) "]
  pack $w -fill x -padx 20 -pady 20
  tkdnd::drop_target register $w $type
  bind $w <<DropEnter>> {%W state  active}
  bind $w <<DropLeave>> {%W state !active}
  bind $w <<Drop>> [list my_drop %W %CPT %D %A]
}
