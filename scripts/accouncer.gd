extends Sprite2D

signal text_bubble_hidden

func _ready() -> void:
	$BaseAnnouncer.hide()
	$SecretAnnouncer.hide()
	$JenKennings.hide()

	if JeopardySaveData.announcer == 'Corporal Hundred legs':
		$SecretAnnouncer.show()
	elif JeopardySaveData.announcer == 'Jen Kennings':
		$JenKennings.show()
	else: # dave
		$BaseAnnouncer.show()

func show_text_bubble(text: String, show_for = 0.0):
	$AnnouncerBubble/Label.text = text
	$AnnouncerBubble.show()
	
	if show_for > .5:
		if JeopardyGlobals.DEBUG_MODE:
			show_for = show_for / 2
		else:
			show_for = show_for * 1.3
		await get_tree().create_timer(show_for).timeout
		hide_text_bubble()
	
func hide_text_bubble():
	$AnnouncerBubble/Label.text = "text"
	$AnnouncerBubble.hide()
	text_bubble_hidden.emit()
