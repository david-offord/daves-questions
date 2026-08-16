extends Node2D

@export var question_text: String
@export var correct_answer: String
@export var wrong_answer1: String
@export var wrong_answer2: String
@export var score_amount = 0
@export var is_daily_double = false


var currently_selected = false
var disabled = false

func init_question(qt, ca, wa1, wa2, score, category_header = false, dd = false):
	question_text = qt
	correct_answer = ca
	wrong_answer1 = wa1
	wrong_answer2 = wa2
	score_amount = score
	is_daily_double = dd
	
	if category_header:
		$AnimatedSprite2D/Label.add_theme_font_size_override("font_size", 16)
	$Hightlight.hide()
	
func _ready():
	$AnimatedSprite2D/Label.text = '$' + str(score_amount)

func disable():
	disabled = true
	$AnimatedSprite2D.hide()
	$DisabledBox.show()

func select():
	$Hightlight.show()
	currently_selected = true

func deselect():
	$Hightlight.hide()
	currently_selected = false
