extends Node

signal exited_scroll

var starting_pos: Vector2
var ending_pos: Vector2

func _ready() -> void:
	starting_pos = $Credits.position
	ending_pos = Vector2($Credits.position.x, $Credits.position.y - ($Credits.size.y + 1080))
	begin_movement()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("select") or event.is_action_pressed("buzz_in") or event.is_action_pressed("end_controller_configuration"):
		exited_scroll.emit()

func begin_movement():
	while true:
		var tween := get_tree().create_tween()
		tween.tween_property($Credits,
			'position',
			ending_pos,
			20)
		await tween.finished
		if tween != null:
			tween = null

		$Credits.position = starting_pos
