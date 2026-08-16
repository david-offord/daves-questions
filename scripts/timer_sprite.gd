extends Node2D

signal time_ran_out

@export var should_expand_and_shrink = true

var MAX_SCALE = scale.x + .4
var MIN_SCALE = scale.x

var just_shrank = true;

func initialize(timer_seconds: float):
	$AnimatedSprite2D.animation = "normaltimer"
	$AnimatedSprite2D.speed_scale = 1 / (timer_seconds * float(JeopardySaveData.time_modifier.left(-1)))

func begin_timer():
	$AnimatedSprite2D.play()
	await $AnimatedSprite2D.animation_finished
	time_ran_out.emit()
	
func _ready() -> void:
	if should_expand_and_shrink:
		call_deferred(await begin_movement())

func begin_movement():
	while true:
		if just_shrank:
			var tween = get_tree().create_tween()
			tween.tween_property(self , "scale", Vector2(MAX_SCALE, MAX_SCALE), 1)
			await tween.finished
			tween = null
			just_shrank = false
		else:
			var tween = get_tree().create_tween()
			tween.tween_property(self , "scale", Vector2(MIN_SCALE, MIN_SCALE), 1)
			await tween.finished
			tween = null
			just_shrank = true
