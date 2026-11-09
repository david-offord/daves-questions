extends Sprite2D

signal player_confirmed(player_id, value)

var onscreen_timer = null

var can_player_overbet = true
var double_jeopardy = false

var specific_player = 0

var position_to_mult = {
	5: 1,
	4: 10,
	3: 100,
	2: 1000,
	1: 10000,
	0: 100000
}

var player_positions = {
	0: 5,
	1: 5,
	2: 5,
}

var player_can_interact = {
	0: false,
	1: false,
	2: false,
}

##Initializes the daily double input - basically just saves who exactly is asking for this daily double 
func initialize(player_specific = -1, disallowed_players = [], is_in_double_jeopardy = false):
	specific_player = player_specific
	double_jeopardy = is_in_double_jeopardy
	if player_specific == -1:
		can_player_overbet = false
	
	#if it is specifically only 1 player, then set that here
	if player_specific != -1:
		player_can_interact[player_specific] = true
	#otherwise, set true for all of them
	else:
		player_can_interact = {
			0: true,
			1: true,
			2: true,
		}

		for p in disallowed_players:
			player_can_interact[p] = false

		if JeopardyGlobals.number_of_players == 2:
			player_can_interact[2] = false

	#do the ai logic here
	for pid in player_can_interact.keys():
		if pid not in JeopardyGlobals.player_id_to_is_cpu:
			continue

		if player_can_interact[pid] == false:
			continue

		if JeopardyGlobals.player_id_to_is_cpu[pid] or (JeopardyGlobals.CPU_TESTING):
			call_deferred("process_ai_logic", pid)


func _ready() -> void:
	#get a list of all player sections
	var all_player_selections = get_tree().get_nodes_in_group('PlayerSection')
	#if its only 1 player, then hide all of them except that player
	if specific_player != -1:
		for ps in all_player_selections:
			ps.hide()
		get_node("Player%dSection" % specific_player).show()
	#otherwise, show em all
	else:
		for ps in player_can_interact:
			if player_can_interact[ps] == true:
				all_player_selections[ps].show()
			else:
				all_player_selections[ps].hide()


	#create a timer
	onscreen_timer = JeopardyGlobals.TIMER_SCENE.instantiate()
	if JeopardyGlobals.DEBUG_MODE:
		onscreen_timer.initialize(20)
	else:
		onscreen_timer.initialize(30)
	onscreen_timer.begin_timer()
	onscreen_timer.time_ran_out.connect(timer_ran_out)
	$TimerLocation.add_child(onscreen_timer)

func _input(event: InputEvent) -> void:
	var is_keyboard_input = event is InputEventKey or event is InputEventMouse
	var event_player_id = JeopardyGlobals.get_player_id_by_guid(event.device, is_keyboard_input)
	#if its not a player, just back out
	if event_player_id == -1:
		return

	#check if this player can even interact
	if player_can_interact[event_player_id]:
		#move digit selector left or right
		if event.is_action_pressed("move_cursor_right"):
			move_cursor_left_right(event_player_id, 'right')
		if event.is_action_pressed("move_cursor_left"):
			move_cursor_left_right(event_player_id, 'left')
			
		#increases value
		if event.is_action_pressed("move_cursor_up"):
			change_value(event_player_id, 'up')
		if event.is_action_pressed("move_cursor_down"):
			change_value(event_player_id, 'down')

		#confirm the value
		if event.is_action_pressed("select"):
			confirm_player_value(event_player_id)

		
		if event.is_action_pressed("max_bet"):
			max_out_bet(event_player_id)

func max_out_bet(player_id: int):
	set_value_based_on_ui(player_id, JeopardyGlobals.money_by_player[player_id])


##Confirm the value the player has set - emits the player id and the value
func confirm_player_value(player_id: int):
	player_can_interact[player_id] = false
	get_node("Player%dSection/UpArrow" % [player_id]).hide()
	get_node("Player%dSection/DownArrow" % [player_id]).hide()

	SoundController.play_sound_effect(SoundController.SoundEffects.BetLockIn)

	#if there is an onscreen timer active
	var all_players_completed = true
	for key in player_can_interact:
		if player_can_interact[key]:
			all_players_completed = false

	if onscreen_timer != null and all_players_completed:
		onscreen_timer.queue_free()

	var player_area: Node2D = get_node("Player%dSection" % [player_id])
	var fade_tween = get_tree().create_tween()

	fade_tween.tween_property(player_area,
		'modulate:a',
		0,
		1.0)

	await fade_tween.finished

	player_confirmed.emit(player_id, get_value_based_on_ui(player_id))

##when the timer runs out 
func timer_ran_out():
	for key in player_can_interact:
		if player_can_interact[key]:
			confirm_player_value(key)

	onscreen_timer.queue_free()

#just to be clear, i am aware the below code is absolutely busted, 
#but I think it is the best way I can do it while I code this, while watching family guy

##move the cursor left or right
func move_cursor_left_right(player_id: int, left_right: String):
	if left_right == 'right':
		player_positions[player_id] = player_positions[player_id] + 1
	else:
		player_positions[player_id] = player_positions[player_id] - 1
	
	if player_positions[player_id] > 5:
		player_positions[player_id] = 0
	if player_positions[player_id] < 0:
		player_positions[player_id] = 5

	var rect: ColorRect = get_node("Player%dSection/%dInput" % [player_id, position_to_mult[player_positions[player_id]]])
	var centerPos = rect.position.x + (rect.size.x / 2)

	var upArrow: Sprite2D = get_node("Player%dSection/UpArrow" % [player_id])
	var downArrow: Sprite2D = get_node("Player%dSection/DownArrow" % [player_id])
	
	upArrow.position = Vector2(centerPos, upArrow.position.y)
	downArrow.position = Vector2(centerPos, downArrow.position.y)

##changes the value in the UI
func change_value(player_id: int, up_down: String):
	var mult = position_to_mult[player_positions[player_id]]

	var label: Label = get_node("Player%dSection/%dInput/Label" % [player_id, mult])
	var digit_value = int(label.text)
	
	if up_down == 'up':
		digit_value += 1
	else:
		digit_value += -1
	
	if digit_value > 9:
		digit_value = 0
	if digit_value < 0:
		digit_value = 9

	label.text = '%d' % digit_value


	var maximum_bet = 0
	#get the player max bet. if its allowed to overbet, then set to 100
	if can_player_overbet and double_jeopardy:
		maximum_bet = 2000 if 2000 > JeopardyGlobals.money_by_player[player_id] else JeopardyGlobals.money_by_player[player_id]
	elif can_player_overbet and !double_jeopardy:
		maximum_bet = 1000 if 1000 > JeopardyGlobals.money_by_player[player_id] else JeopardyGlobals.money_by_player[player_id]
	#presumably final jeopardy
	else:
		maximum_bet = JeopardyGlobals.money_by_player[player_id]

	var new_value = get_value_based_on_ui(player_id)
	if new_value > maximum_bet:
		new_value = maximum_bet
		set_value_based_on_ui(player_id, new_value)

##get value from UI elements
func get_value_based_on_ui(player_id: int):
	var labels = get_labels_by_player_id(player_id)

	var val = ''

	for label in labels:
		val += label.text
		
	return int(val)

#set the UI value
func set_value_based_on_ui(player_id: int, value: int):
	#var labels = get_node("Player%dSection" % [player_id]).get_children()
	var labels = get_labels_by_player_id(player_id)

	var val = '%d' % value

	while len(val) < 6:
		val = '0' + val

	var i = 0
	for label in labels:
		label.text = val[i]
		i += 1
		
	return int(val)

func get_labels_by_player_id(player_id: int):
	var all_labels = get_tree().get_nodes_in_group('PlayerValueDigit')
	var player_labels = []
	
	for label in all_labels:
		if label.get_parent().get_parent().name == ("Player%dSection" % [player_id]):
			player_labels.append(label)

	return player_labels

func process_ai_logic(player_id):
	#get the amount to bet
	var curr_money = JeopardyGlobals.money_by_player[player_id]
	var bet_amt = 0
	#if theyre down so catastrophic they only have 100, dont bet
	if curr_money > 100:
		match JeopardySaveData.default_comp_diff:
			JeopardyGlobals.EASY_CPU_DIFFFICULTY:
				#check if they go all in for the hell of it
				if JeopardyGlobals.dice_roll(50):
					bet_amt = curr_money
				else:
					#basically bet a random amount
					bet_amt = randi_range(1, curr_money + 1)

			JeopardyGlobals.MEDIUM_CPU_DIFFFICULTY:
				#check if they go all in for the hell of it
				if JeopardyGlobals.dice_roll(30):
					bet_amt = curr_money
				else:
					#never in a million years will I understand why I need to do this
					#this is not something to warn me over - this is very intentional godot
					@warning_ignore("integer_division")
					bet_amt = randi_range(curr_money / 2, curr_money + 1)

			JeopardyGlobals.HARD_CPU_DIFFFICULTY:
				pass
		#if this is near max money (i.e. 57 and their max is 65)
		if bet_amt + 10 >= curr_money:
			bet_amt = curr_money
		else:
			bet_amt = floori(bet_amt)
	else:
		if can_player_overbet:
			if double_jeopardy:
				bet_amt = 2000
			else:
				bet_amt = 1000


	#bet is determined, so now do the input lol
	#i forgot how fucking stupid this method of putting inputs in was lmfao
	#but also Im just gonna do it again
	var movements: Array[String] = []
	var str_value = str(bet_amt) # ex 127
	str_value = str_value.reverse() # now 721
	var chars = str_value.split("") # now [7,2,1]

	#this may be legitimately one of the stupidest things i have ever programmed
	#for every digit
	for character in chars:
		#get the in value
		var intval = int(character)
		#if its more than 5 go backwards
		if intval > 5:
			var moves = 10 - intval
			for m in range(moves):
				movements.append("down")
		#else go up
		elif intval > 0:
			for m in range(intval):
				movements.append("up")
		#move left 
		movements.append('left')

	movements.pop_back()

	await get_tree().create_timer(1).timeout

	for move in movements:
		if move == "left" or move == "right":
			move_cursor_left_right(player_id, move)
		else:
			change_value(player_id, move)

		await get_tree().create_timer(.3).timeout
	
	await get_tree().create_timer(.7).timeout
	confirm_player_value(player_id)