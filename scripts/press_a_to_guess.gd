extends Sprite2D

signal shrank_to_zero

@export var SCALE_MIN = 0.7
@export var SCALE_MAX = 1.0
@export var scale_speed = 0.7
@export var scale_to_zero_speed = 5

var expand = true
var shrink_to_zero = false

func _process(delta: float) -> void:
	if shrink_to_zero == true:
		scale.x = scale.x - (scale_to_zero_speed * delta)
		scale.y = scale.x
		scale = scale.clamp(Vector2(0,0), Vector2(2,2))
		if scale.x == 0.0:
			shrank_to_zero.emit()
		
	else:
		if expand:
			scale.x = scale.x + (scale_speed * delta)
		else:
			scale.x = scale.x - (scale_speed * delta)
		scale.y = scale.x
		
		if scale.x < SCALE_MIN or scale.x > SCALE_MAX:
			expand = !expand
