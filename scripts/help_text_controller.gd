class_name HelpTextController extends Control
#doing class names at this point is like rearranging the dining room on the titanic

signal backed_out

var shown = false
var currently_hiding = false

var hidden_x := -1797.0
var shown_x := -307.0

@onready var help_text_image: TextureRect = $HelpText

func _input(event: InputEvent) -> void:
	if shown == false:
		return

	if event.is_action_pressed("back_exit_return") and currently_hiding == false:
		hide_help()

func show_help():
	if shown:
		return

	var tween := get_tree().create_tween()
	tween.tween_property(help_text_image,
		'position:x',
		shown_x,
		.75,
		)
	await tween.finished

	if tween != null:
		tween = null

	help_text_image.position.x = shown_x
	shown = true

func hide_help():
	if shown == false:
		return
		
	currently_hiding = true

	var tween := get_tree().create_tween()
	tween.tween_property(help_text_image,
		'position:x',
		hidden_x,
		.75,
		)
	await tween.finished

	if tween != null:
		tween = null

	help_text_image.position.x = hidden_x
	shown = false
	currently_hiding = false
	backed_out.emit()
