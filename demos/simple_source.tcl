package require tkdnd
catch {console show}

pack [ttk::button .drag_source_text -text " Drag Source (Text) "] \
      -fill x -padx 20 -pady 20
pack [ttk::button .drag_source_files -text " Drag Source (Files) "] \
      -fill x -padx 20 -pady 20

tkdnd::drag_source register .drag_source_text  DND_Text
tkdnd::drag_source register .drag_source_files DND_Files

## Event <<DragInitCmd>>
set filename [info script]
bind .drag_source_text <<DragInitCmd>> \
  {list copy DND_Text {Some nice dropped text!}}
bind .drag_source_files <<DragInitCmd>> \
  {list {copy move} DND_Files [list $filename $filename]}

## Event <<DragEndCmd>>
bind .drag_source_files <<DragEndCmd>> {
  puts "Drop action: %A"
}
