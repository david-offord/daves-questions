extends Control

var display_text = ''

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = display_text
	kill_self_after_seconds()
	
	
func kill_self_after_seconds():
	await get_tree().create_timer(2.5).timeout
	queue_free()
