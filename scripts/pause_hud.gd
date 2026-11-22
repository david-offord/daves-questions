class_name PauseHud extends Control

signal restart_from_pause
signal quit_to_title_from_pause

var is_paused = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('pause_game'):
		if is_paused == false:
			return

		resume()
		#get_viewport().set_input_as_handled()


func defer_setting_pause():
	call_deferred('set_paused')

func set_paused():
	is_paused = true
	$ResumeGame.grab_focus()


func resume():
	if is_paused == false:
		return

	hide()
	JeopardyGlobals.IS_PAUSED = false
	get_viewport().set_input_as_handled()

	#idk if this is like an immediate thing, but putting it at the en here
	get_tree().paused = false
	

func restart_game():
	resume()
	restart_from_pause.emit()

func return_to_title():
	resume()
	quit_to_title_from_pause.emit()


func _on_resume_game_pressed() -> void:
	pass # Replace with function body.
