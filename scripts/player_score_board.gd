extends Node2D

func _ready() -> void:
	#hide the third player if its only 2
	if JeopardyGlobals.number_of_players == 2:
		get_node('Player3Board').hide()
		#literally only if im testing solo
	if JeopardyGlobals.SINGLEPLAYER_TESTING:
		get_node('Player2Board').hide()
		get_node('Player3Board').hide()

func update_score(player_id: int):
	print_debug('Updating the score on the scoreboard for player %d' % player_id);
	if player_id not in JeopardyGlobals.money_by_player:
		return
	var update_text: Label = get_node('Player%dBoard/PointTotal' % [player_id + 1])
	update_text.text = str(JeopardyGlobals.format_scoreboard_currency((JeopardyGlobals.money_by_player[player_id])))

func show_disabled(player_id: int):
	print_debug('Player %d was disabled.' % player_id);
	get_node('Player%dBoard/DisabledColoring' % [player_id + 1]).show()

func disable_everyone():
	print_debug('Disabling all players on the scoreboard.');
	var all_disabled_color = get_tree().get_nodes_in_group("DisabledColoring")
	for dc in all_disabled_color:
		dc.show()

func enable_everyone():
	print_debug('Enabling all players on the scoreboard.');
	var all_disabled_color = get_tree().get_nodes_in_group("DisabledColoring")
	for dc in all_disabled_color:
		dc.hide()

func temporarily_disable(player_id: int, time_stunned: int):
	print_debug('Temporarily disabled player %d for %d seconds.' % [player_id, time_stunned]);
	var temp_node = get_node('Player%dBoard/DisabledColoring' % [player_id + 1])
	temp_node.scale = Vector2(1, 1)
	temp_node.show()
	
	var tween = get_tree().create_tween()
	tween.tween_property(temp_node,
		'scale',
		Vector2(0, 1),
		time_stunned)
	await tween.finished
	if tween != null:
		tween = null
	temp_node.hide()
	temp_node.scale = Vector2(1, 1)

func temporarily_reenable(player_id: int):
	print_debug('Reenabling player %d after they were disabled for buzzin in early.' % player_id);
	var temp_node = get_node('Player%dBoard/DisabledColoring' % [player_id + 1])
	temp_node.hide()

func highlight_player(player_id: int):
	print_debug('Highlighting player %d .' % player_id);
	var all_disabled_color = get_tree().get_nodes_in_group("HighlightColoring")
	for dc in all_disabled_color:
		dc.hide()
	if player_id != -1:
		get_node('Player%dBoard/HighlightColoring' % [player_id + 1]).show()
