extends Node2D

var display_text = ''

func init_header(text):
	display_text = text
	

func _ready():
	$AnimatedSprite2D/Label.text = str(display_text)
