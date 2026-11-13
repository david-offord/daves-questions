extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for player in JeopardyGlobals.player_id_to_is_cpu.keys():
		if JeopardyGlobals.player_id_to_is_cpu[player]:
			(get_node("Player%sScore/Label" % [player + 1]) as Label).text = 'CPU %d' % (player + 1)
