class_name AutoFontSizeLabel extends Label
## A label that will scale the font size to fit its size, betweem the min and max sizes.

## Smallest possible font size text can be in the label.
@export var minimum_size := 36

## Largest possible font size text can be in the label, also default font size when there is not much text.
@export var maximum_size := 96


func _ready():
	# Clip text must be true otherwise label just resizes rather than hiding lines,
	# which the update_font_size function relies on to resize font.
	clip_text = true


func _set(property, value):
	if property == "text" and text != value:
		text = value
		add_theme_font_size_override("font_size", maximum_size)
		update_font_size()
		return true
	
	return false


func update_font_size():
	var font_size = get_theme_font_size("font_size")
	
	while get_visible_line_count() < get_line_count():
		font_size -= 1
		
		add_theme_font_size_override("font_size", font_size)
