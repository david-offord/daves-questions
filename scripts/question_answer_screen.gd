extends Node2D

signal answered_correctly(player_id: int, score_value: int)
signal answered_incorrectly(player_id: int, score_value: int)
signal time_ran_out

signal player_temp_disabled(player_id: int, stun_time: float)
signal player_temp_enabled(player_id: int)

signal final_time_ran_out()
signal final_jeopardy_answered(player_id: int, answer: String, correct: bool)

#This is set on initialize
var correct_answer_str = ''
var correct_answer_int = 0

#this is set once a player buzzes in
var player_answering_id: int = -1
var player_answering: String = ''
var disabled_players: Array[int] = []

#this is used for general flow
enum AnsweringState {WAITING_FOR_A, WAITING_FOR_SOMEONE_TO_BUZZ, ANIMATING_ANSWERS, WAITING_FOR_ANSWER, ANIMATING, COMPLETED}
var current_state = AnsweringState.WAITING_FOR_A

#objects created and referenced elsewhere
var onscreen_timer = null
var parent_announcer = null

#timer that triggers the showing of the "press a" button
var time_before_showing: SceneTreeTimer

#variables for holding a button etc etc
var button_0_being_held = false
var held_button_0_perc = 0.0
var button_1_being_held = false
var held_button_1_perc = 0.0
var button_2_being_held = false
var held_button_2_perc = 0.0

#daily double logic
var daily_double_player = -1

#final jeopardy logic
var is_in_final_jeopardy = false
var final_jeopardy_allowed_players = []
var final_jeopardy_players_answered = []


#score value of the question
var score_value = 0
var scoreboard_object: Node = null

const QUESTION_TEXT_Y_OFFSET = 30


func _ready() -> void:
	current_state = AnsweringState.WAITING_FOR_A
	
##Sets all the information about the question into this container
func initialize_questions(question,
							correct_answer,
							wrong_answer1,
							wrong_answer2,
							score,
							how_long_to_wait = 0.0,
							announcer = null,
							daily_double_player_id = -1,
							final_jeopardy_players = null):
	#put all the options in an array and mess it up
	var options = [correct_answer, wrong_answer1, wrong_answer2]
	options.shuffle()
	
	#get the right answer index
	correct_answer_int = options.find(correct_answer)
	correct_answer_str = correct_answer

	score_value = score
	#if default, wait a random amount of time
	if how_long_to_wait == 0.0:
		how_long_to_wait = randf_range(5, 10)
	
	#logic im going for here is left = 0, down = 1, right = 2
	$QuestionTextBox/QuestionText.text = question
	$AnswerOption0/QuestionText.text = options[0] + (' (CORRECT)' if JeopardyGlobals.DEBUG_MODE and correct_answer_int == 0 else '')
	$AnswerOption1/QuestionText.text = options[1] + (' (CORRECT)' if JeopardyGlobals.DEBUG_MODE and correct_answer_int == 1 else '')
	$AnswerOption2/QuestionText.text = options[2] + (' (CORRECT)' if JeopardyGlobals.DEBUG_MODE and correct_answer_int == 2 else '')
	
	#save the daily double player info
	daily_double_player = daily_double_player_id

	#set a timer before the "ANSWER" text appears
	time_before_showing = get_tree().create_timer(how_long_to_wait)

	if final_jeopardy_players != null:
		final_jeopardy_allowed_players = final_jeopardy_players
		is_in_final_jeopardy = true
		time_before_showing.timeout.connect(show_final_jeopardy_answers)
	elif daily_double_player == -1:
		time_before_showing.connect('timeout', show_buzzer_button)
	else:
		time_before_showing.timeout.connect(daily_double_player_buzz_in)


	parent_announcer = announcer

##show the buzzer and create a timer
func show_buzzer_button():
	time_before_showing = null
	current_state = AnsweringState.WAITING_FOR_SOMEONE_TO_BUZZ
	$PressAToGuess.scale = Vector2(1, 1)
	$PressAToGuess.shrink_to_zero = false
	$PressAToGuess.show()
	SoundController.play_sound_effect(SoundController.SoundEffects.BuzzerAppears)

	#spawn the onscreen timer
	create_timer_for_buzzing_in()


func hide_buzzer_button():
	$PressAToGuess.shrink_to_zero = true
	await $PressAToGuess.shrank_to_zero
	$PressAToGuess.hide()
	onscreen_timer.queue_free()
	
	
func _process(delta: float) -> void:
	var fill_up_speed = 2

	if button_0_being_held:
		held_button_0_perc += fill_up_speed * delta
	else:
		held_button_0_perc -= fill_up_speed * delta
		
	if button_1_being_held:
		held_button_1_perc += fill_up_speed * delta
	else:
		held_button_1_perc -= fill_up_speed * delta
		
	if button_2_being_held:
		held_button_2_perc += fill_up_speed * delta
	else:
		held_button_2_perc -= fill_up_speed * delta
		
	#all the logic for setting the range max/min
	if held_button_0_perc > 1.0:
		answer_question(0)
	if held_button_0_perc < 0.0:
		held_button_0_perc = 0.0
		
	if held_button_1_perc > 1.0:
		answer_question(1)
	if held_button_1_perc < 0.0:
		held_button_1_perc = 0.0
		
	if held_button_2_perc > 1.0:
		answer_question(2)
	if held_button_2_perc < 0.0:
		held_button_2_perc = 0.0
	
	#bro this shit sucks lmfao
	#so i have to do this because im scaling the parent for a mask
	#which is dumb
	#and then I have to basically move the child around a little bit

	$AnswerOption0/AnswerHighlightMask.scale.x = held_button_0_perc * 1
	$AnswerOption0/AnswerHighlightMask.position.x = (750 * held_button_0_perc) - 750
	$AnswerOption1/AnswerHighlightMask.scale.x = held_button_1_perc * 1
	$AnswerOption1/AnswerHighlightMask.position.x = (750 * held_button_1_perc) - 750
	$AnswerOption2/AnswerHighlightMask.scale.x = held_button_2_perc * 1
	$AnswerOption2/AnswerHighlightMask.position.x = (750 * held_button_2_perc) - 750
	
	#oh, and also dont even show this if its final jeopardy lmfao
	if is_in_final_jeopardy:
		$AnswerOption0/AnswerHighlightMask.hide()
		$AnswerOption1/AnswerHighlightMask.hide()
		$AnswerOption2/AnswerHighlightMask.hide()


func _input(event: InputEvent) -> void:
	var is_keyboard_input = event is InputEventKey or event is InputEventMouse
	var event_player_id = JeopardyGlobals.get_player_id_by_guid(event.device, is_keyboard_input)
	#if its not a player, just back out
	if event_player_id == -1:
		return

	if current_state == AnsweringState.WAITING_FOR_A and event_player_id not in disabled_players:
		if event.is_action_pressed("buzz_in"):
			temporarily_disable_player(event_player_id)
			return
			
	#whoever buzzs in first
	if current_state == AnsweringState.WAITING_FOR_SOMEONE_TO_BUZZ:
		if event.is_action_pressed("buzz_in") and (event_player_id not in disabled_players):
			player_buzzed_in(event_player_id)
	
	#if we're waiting for them to answer
	if current_state == AnsweringState.WAITING_FOR_ANSWER and is_in_final_jeopardy == false:
		#if the inputting user is the one who is actually answering
		if event_player_id == player_answering_id:
			if event.is_action_pressed("answer_0"):
				button_0_being_held = true
			if event.is_action_released("answer_0"):
				button_0_being_held = false
			if event.is_action_pressed("answer_1"):
				button_1_being_held = true
			if event.is_action_released("answer_1"):
				button_1_being_held = false
			if event.is_action_pressed("answer_2"):
				button_2_being_held = true
			if event.is_action_released("answer_2"):
				button_2_being_held = false

	elif current_state == AnsweringState.WAITING_FOR_ANSWER and is_in_final_jeopardy == true:
		if event_player_id not in final_jeopardy_players_answered and event_player_id in final_jeopardy_allowed_players:
			if event.is_action_pressed("answer_0"):
				final_jeopardy_player_locked_in(event_player_id, $AnswerOption0/QuestionText.text, 0 == correct_answer_int)
			elif event.is_action_pressed("answer_1"):
				final_jeopardy_player_locked_in(event_player_id, $AnswerOption1/QuestionText.text, 1 == correct_answer_int)
			elif event.is_action_pressed("answer_2"):
				final_jeopardy_player_locked_in(event_player_id, $AnswerOption2/QuestionText.text, 2 == correct_answer_int)


func answer_question(answer_id: int):
	button_0_being_held = false; button_1_being_held = false; button_2_being_held = false
	held_button_0_perc = 0; held_button_1_perc = 0; held_button_2_perc = 0;
	
	#get rid of the timer
	onscreen_timer.queue_free()
	
	#so they cant input anything for a minute
	current_state = AnsweringState.ANIMATING
	
	#hide the other buttons
	for i in range(0, 3):
		if i != answer_id:
			get_node("AnswerOption%s" % [i]).hide()
	
	get_node("AnswerOption%s/ButtonPressIcon" % [answer_id]).hide()
	
	
	#get the question selected
	var question_node = get_node("AnswerOption%s" % [answer_id])
	#tween the question selected to the middle
	var tween = get_tree().create_tween()
	tween.tween_property(question_node,
		'position',
		$CenterForQuestions.position,
		0.2)
	await tween.finished
	tween = null
	
	#wait a bit
	await get_tree().create_timer(1.5).timeout
	
	if answer_id == correct_answer_int:
		answered_right()
	else:
		answered_wrong()
	

#called when an answer is correct
func answered_right():
	current_state = AnsweringState.COMPLETED
	#flash an O on the screen
	
	var original_scale: Vector2 = $WrongAnswerX.scale
	$CorrectAnswerO.scale = Vector2(0, 0)
	$CorrectAnswerO.show()
	
	var tween = get_tree().create_tween()
	tween.tween_property($CorrectAnswerO, 'scale', original_scale, 0.2)
	await tween.finished
	if tween != null:
		tween = null

	SoundController.play_sound_effect(SoundController.SoundEffects.RightAnswer)

	await get_tree().create_timer(1).timeout
	$CorrectAnswerO.hide()

	scoreboard_object.highlight_player(-1)
	answered_correctly.emit(player_answering_id, score_value)

#called when the answer is incorrect
func answered_wrong(didnt_answer = false):
	if onscreen_timer != null:
		onscreen_timer.queue_free()

	var original_scale: Vector2 = $WrongAnswerX.scale

	#flash an X on the screen
	$WrongAnswerX.scale = Vector2(0, 0)
	$WrongAnswerX.show()
	
	var tween = get_tree().create_tween()
	tween.tween_property($WrongAnswerX, 'scale', original_scale, 0.2)
	await tween.finished
	if tween != null:
		tween = null

	SoundController.play_sound_effect(SoundController.SoundEffects.WrongAnswer)

	await get_tree().create_timer(1).timeout
	$WrongAnswerX.hide()

	
	parent_announcer.show_text_bubble("Oh, cat got your tongue?" if didnt_answer else "Nope, sorry, wrong answer!", 2)

	await parent_announcer.text_bubble_hidden

	#emit to the parent this player messed up
	scoreboard_object.highlight_player(-1)
	answered_incorrectly.emit(player_answering_id, score_value)


func continue_after_wrong_answer(who_got_it_wrong):
	#add player to list of disabled ones
	disabled_players.append(who_got_it_wrong)
	scoreboard_object.show_disabled(who_got_it_wrong)
	
	#hide all the options once we're going back to the main screen
	$AnswerOption0.hide()
	$AnswerOption1.hide()
	$AnswerOption2.hide()
	
	#move the box back to the center
	var tween = get_tree().create_tween()
	tween.tween_property($QuestionTextBox, 'position', Vector2($QuestionTextBox.position.x, $QuestionTextBox.position.y + QUESTION_TEXT_Y_OFFSET), 0.2)
	await tween.finished
	tween = null
	
	#then wait a bit before showing the button again
	current_state = AnsweringState.WAITING_FOR_A
	await get_tree().create_timer(randf_range(.3, .6)).timeout
	show_buzzer_button()


func nobody_answered():
	button_0_being_held = false; button_1_being_held = false; button_2_being_held = false
	held_button_0_perc = 0.0; held_button_1_perc = 0.0; held_button_2_perc = 0.0;

	hide_buzzer_button()
	onscreen_timer.queue_free()
	current_state = AnsweringState.COMPLETED
	time_ran_out.emit()

func daily_double_player_buzz_in():
	player_buzzed_in(daily_double_player)


func player_buzzed_in(device_int: int):
	print('Controller %s buzzed in.' % [device_int])
	
	#delete the timer
	if onscreen_timer != null:
		onscreen_timer.queue_free()

	current_state = AnsweringState.ANIMATING_ANSWERS
	
	#save id of buzzed player
	player_answering_id = device_int
	player_answering = Input.get_joy_guid(player_answering_id)
	
	hide_buzzer_button()
	SoundController.play_sound_effect(SoundController.SoundEffects.BuzzedIn)
	
	scoreboard_object.highlight_player(player_answering_id)

	#move the question box up
	var tween = get_tree().create_tween()
	tween.tween_property($QuestionTextBox, 'position', Vector2($QuestionTextBox.position.x, $QuestionTextBox.position.y - QUESTION_TEXT_Y_OFFSET), 0.2)
	
	#wait as it moves up
	await get_tree().create_timer(.2).timeout
	$AnswerOption0.position = $AnswerOption0.get_meta('OriginalPosition')
	$AnswerOption1.position = $AnswerOption1.get_meta('OriginalPosition')
	$AnswerOption2.position = $AnswerOption2.get_meta('OriginalPosition')

	#idk if ill have these
	#$AnswerOption0/ButtonPressIcon.show()
	#$AnswerOption1/ButtonPressIcon.show()
	#$AnswerOption2/ButtonPressIcon.show()
	
	$AnswerOption0.show()
	$AnswerOption1.show()
	$AnswerOption2.show()
	
	current_state = AnsweringState.WAITING_FOR_ANSWER
	create_timer_for_picking_an_answer()

func show_final_jeopardy_answers():
	print('Final jeopardy answers shown')
	
	#delete the timer
	if onscreen_timer != null:
		onscreen_timer.queue_free()

	current_state = AnsweringState.ANIMATING_ANSWERS
	
	hide_buzzer_button()
	
	#move the question box up
	var tween = get_tree().create_tween()
	tween.tween_property($QuestionTextBox, 'position', Vector2($QuestionTextBox.position.x, $QuestionTextBox.position.y - QUESTION_TEXT_Y_OFFSET), 0.5)
	
	await tween.finished
	tween = null

	#wait as it moves up
	$AnswerOption0.position = $AnswerOption0.get_meta('OriginalPosition')
	$AnswerOption1.position = $AnswerOption1.get_meta('OriginalPosition')
	$AnswerOption2.position = $AnswerOption2.get_meta('OriginalPosition')
	
	$AnswerOption0.show()
	$AnswerOption1.show()
	$AnswerOption2.show()
	
	current_state = AnsweringState.WAITING_FOR_ANSWER

	#create a timer
	onscreen_timer = JeopardyGlobals.TIMER_SCENE.instantiate()
	onscreen_timer.should_expand_and_shrink = false
	onscreen_timer.initialize(20)
	onscreen_timer.begin_timer()
	onscreen_timer.time_ran_out.connect(final_jeopardy_time_out)

	$TimerLocation.add_child(onscreen_timer)

##Triggers in final jeopardy when player locks in
func final_jeopardy_player_locked_in(player_id: int, answer: String, correct: bool):
	#so first, disable the player
	final_jeopardy_players_answered.append(player_id)
	#emit the fact they locked in
	final_jeopardy_answered.emit(player_id, answer, correct)

	pass

func final_jeopardy_time_out():
	print("FINAL RAN OUT OF TIME")
	final_time_ran_out.emit()
	pass


func temporarily_disable_player(player_id: int):
	#theyre already stunned
	if player_id in disabled_players:
		return

	#cant be stunned in final
	if is_in_final_jeopardy:
		return
	
	#temporarily disable the player
	player_temp_disabled.emit(player_id, JeopardyGlobals.HOW_LONG_TO_STUN_ON_EARLY_BUZZ)
	disabled_players.append(player_id)
	
	#wait 2 seconds
	await get_tree().create_timer(JeopardyGlobals.HOW_LONG_TO_STUN_ON_EARLY_BUZZ).timeout
	
	#then reenable
	player_temp_enabled.emit(player_id)
	disabled_players = disabled_players.filter(func(x): return x != player_id)

##Creates a timer, connects all the signals, and starts it
func create_timer_for_buzzing_in(time = 20):
	#create a timer
	onscreen_timer = JeopardyGlobals.TIMER_SCENE.instantiate()
	onscreen_timer.should_expand_and_shrink = false
	onscreen_timer.initialize(time)
	onscreen_timer.begin_timer()
	onscreen_timer.connect("time_ran_out", nobody_answered)
	$TimerLocation.add_child(onscreen_timer)

##Creates a timer, connects all the signals, and starts it
func create_timer_for_picking_an_answer(time = 20):
	#create a timer
	onscreen_timer = JeopardyGlobals.TIMER_SCENE.instantiate()
	onscreen_timer.should_expand_and_shrink = false
	onscreen_timer.initialize(time)
	onscreen_timer.begin_timer()
	onscreen_timer.time_ran_out.connect(answered_wrong.bind(true))
	$TimerLocation.add_child(onscreen_timer)
