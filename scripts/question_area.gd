extends Node

@export var question_scene: PackedScene
@export var category_header_scene: PackedScene
@export var buzz_in_and_answer_scene: PackedScene

signal going_to_final_score(bool)


#this is used for general flow
enum QUESTION_AREA_STATES {SPAWNING_QUESTIONS, WAITING_FOR_SELECTION, TIME_RAN_OUT_SELECTING, AWAITING_DAILY_DOUBLE_INPUT, AWAITING_FINAL_JEOPARDY_INPUT}
var current_state: QUESTION_AREA_STATES = QUESTION_AREA_STATES.SPAWNING_QUESTIONS

#position of the cursor
var current_position_x = 0
var current_position_y = 0

#array (dict of dict) of questions
var question_box_array = {}

#which player is currently moving the cursor
var current_player_selecting = 0

#presumably the number of player, once everyone guess wrong, bail out
var MAX_NUMBER_OF_WRONG_GUESSES = 3
var number_of_wrong_guesses = 0

#daily double logic
var is_in_daily_double = false
var daily_double_val_defined = 0

#object holders (created in functions and need to be destroyed/modified later)
var currently_shown_question = null
var current_buzz_and_answer_child = null
var daily_double_child = null
var onscreen_timer = null

#double jeopardy logic
@export var is_in_double_jeopardy = false # JeopardyGlobals.DEBUG_MODE

#final jeopardy logic
var final_jeopardy_allowed_players = []
var number_of_people_in_final_bet_selection = 1
var final_bet_by_player = {}
var final_jeopardy_question = null
#keep track of how many people are still in the answer stage
var number_of_people_in_final_jeopardy_question = 0
#keep track of their answers/text
var final_answer_by_player = {
	0: {
		'text': 'wrongtest',
		'correct': false,
		'failed_to_answer': true
	},
	1: {
		'text': 'righttest',
		'correct': true,
		'failed_to_answer': true
	},
	2: {
		'text': '',
		'correct': false,
		'failed_to_answer': true
	},
}

var TIME_BETWEEN_BUTTON_PRESSES = .25
var NUMBER_OF_COLUMNS = 2
var NUMBER_OF_ROWS = 5
var SECONDS_PER_WORD = 0.4

#DEBUG VARIABLES
var debug_simulate_none_left_after = 2
var debug_questions_asked = 0

#steam achievement variables
var ever_got_a_question_wrong = false


func _ready() -> void:
	#set the scores when the game starts
	JeopardyGlobals.set_up_player_money()

	print_debug('Question area spawned and starting.');
	#if JeopardyGlobals.MINOR_DEBUG_MODE:
	#	is_in_double_jeopardy = true
	#	JeopardyGlobals.money_by_player[1] = -200

	#get number of columns based on the number of headers
	var column_num_nodes = get_tree().get_nodes_in_group('category_header')
	column_num_nodes = column_num_nodes.filter(func(x): return x.get_parent().is_in_group('active_column'))
	NUMBER_OF_COLUMNS = len(column_num_nodes)


	print_debug('The max number of players is %d.' % JeopardyGlobals.number_of_players);
	#get the number of players and max wrong guesses
	MAX_NUMBER_OF_WRONG_GUESSES = JeopardyGlobals.number_of_players

	#set the current game state
	JeopardyGlobals.CURRENT_GAME_STATE = JeopardyGlobals.GameState.GAMEBOARD
	JeopardyGlobals.start_new_game()

	print_debug('Number of columns: %d.' % NUMBER_OF_COLUMNS);
	#initialize the 2d array
	for i in range(0, NUMBER_OF_COLUMNS):
		question_box_array[i] = {}
		
	$PlayerScoreBoard.update_score(0); $PlayerScoreBoard.update_score(1); $PlayerScoreBoard.update_score(2)
	
	if JeopardyGlobals.DEBUG_DEMO_PURPOSES:
		spawn_questions()
		#JeopardyGlobals.money_by_player[0] = -600
		#JeopardyGlobals.money_by_player[1] = -200
		#JeopardyGlobals.money_by_player[2] = -1200
		#trigger_final_jeopardy_input()
		#final_bet_by_player = {
		#	0: 1000,
		#	1: 2000,
		#	2: 9000
		#}
		#going_to_final_score.emit()
		pass
	else:
		await spawn_questions()


##spawns the questions on the start of the game, and loads the questions
func spawn_questions():
	print_debug('Spawning questions into question area.');
	#$HUD.set_label_on_front("")
	var qmarkers := get_tree().get_nodes_in_group('question_marker')
	var category_headers := get_tree().get_nodes_in_group('category_header')

	category_headers = category_headers.filter(func(x): return x.get_parent().is_in_group('active_column'))
	qmarkers = qmarkers.filter(func(x): return x.get_parent().is_in_group('active_column'))
	
	print_debug('Getting categories.');
	var categories = JeopardyGlobals.get_categories()
	var category_to_questions = []
	
	for category in categories:
		var questions = JeopardyGlobals.get_questions(category['Id'])
		category_to_questions.append({
				'category_name': category['CategoryName'],
				'questions': questions
			})
		JeopardySaveData.add_to_categories_seen(category['Id'])

	print_debug('Spawning column headers.');

	if JeopardyGlobals.db_load_error_msg != '':
		$TestAnnouncer.show_text_bubble(JeopardyGlobals.db_load_error_msg, 5)
		JeopardyGlobals.db_load_error_msg = ''

	#spawn category headers here
	for header in category_headers:
		var col = int(header.get_parent().name.substr(3, 1))
		
		#initialize the question boxes
		var cat_header = category_header_scene.instantiate()
		cat_header.init_header(category_to_questions[col]['category_name'].replace('�', ''))
		header.add_child(cat_header)
		SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)
		await get_tree().create_timer(1.0 if JeopardyGlobals.DEBUG_MODE == false else 0.2).timeout
		
	
	print_debug('Getting the daily double iteration.');
	var daily_double_iter = randi_range(0, len(qmarkers))
	var daily_double_second_iter = -1
	print_debug('Daily double iteration was %d.' % daily_double_iter);

	#if its a double jeopardy round, come up with a second box
	if is_in_double_jeopardy:
		print_debug('We are in double jeopardy, so getting a second double jeopardy.');
		daily_double_second_iter = daily_double_iter
		while daily_double_second_iter == daily_double_iter:
			daily_double_second_iter = randi_range(0, len(qmarkers))
		print_debug('Second double iteration was %d.' % daily_double_second_iter);

	var i = 0

	#just by the nature of the terrible way I set it up, this also causes all options to spawn in sequence. I could fix it but its a debug thing so whatever. idk man, leave me alone
	if JeopardyGlobals.FIRST_QUESTION_ALWAYS_DAILY_DOUBLE:
		daily_double_iter = 0
		daily_double_second_iter = 1 if daily_double_second_iter != -1 else -1
	else:
		qmarkers.shuffle()


	print_debug('Spawning questions.');
	#spawn questions
	for qmark in qmarkers:
		#get the row and column reference based on the name
		var col = int(qmark.get_parent().name.substr(3, 1))
		var row = int(qmark.name.substr(3, 1))
		
		#initialize the question boxes
		var question_box = question_scene.instantiate()
		
		#get the question to render into this box
		var quest_obj = category_to_questions[col]['questions'][(row * 200) + 200]
		
		#here is where we would do all the question logic (like answer, points, etc)
		question_box.init_question(quest_obj['Question'],
			quest_obj['AiCorrectAnswer'],
			quest_obj['WrongAnswer1'],
			quest_obj['WrongAnswer2'],
			(quest_obj['Value'] * 2) if is_in_double_jeopardy else quest_obj['Value'],
			false,
			i == daily_double_iter or i == daily_double_second_iter or JeopardyGlobals.DEBUG_ALL_QUESTIONS_DAILY_DOUBLE
			#true if JeopardyGlobals.DEBUG_MODE else i == double_jeopardy_iter
		)
		
		#add it to the scene
		qmark.add_child(question_box)
		
		#add it to our 2d array
		question_box_array[col][row] = question_box
		
		#wait a lil bit before we add another
		await get_tree().create_timer(.05 if JeopardyGlobals.DEBUG_MODE == false else 0.05).timeout

		if i % 2 == 0:
			SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)

		i += 1
	
	print_debug('Beginning selection process, highlighting player, and creating timer.');
	#initialize the movement
	move_selection('')
	current_state = QUESTION_AREA_STATES.WAITING_FOR_SELECTION
	$PlayerScoreBoard.highlight_player(current_player_selecting)
	
	#show the announcer
	$TestAnnouncer.show_text_bubble('Pick a question!', 2)
	
	#create a timer
	create_timer_for_selecting_question()

func _input(event: InputEvent) -> void:
	var is_keyboard_input = event is InputEventKey or event is InputEventMouse
	var event_player_id = JeopardyGlobals.get_player_id_by_guid(event.device, is_keyboard_input)
	#if its not a player, just back out
	if event_player_id == -1:
		return

	#if we're not even on this menu, just bail
	if JeopardyGlobals.CURRENT_GAME_STATE != JeopardyGlobals.GameState.GAMEBOARD:
		return
	
	#if they should be able to move
	if current_state != QUESTION_AREA_STATES.WAITING_FOR_SELECTION:
		return
	
	if JeopardyGlobals.VERBOSE_LOGGING:
		print(Input.get_joy_name(event.device) + ' (' + Input.get_joy_guid(event.device) + (') - %d' % event.device))
	

	if event_player_id == current_player_selecting:
		var move_direction = ''
		if true:
			if Input.is_action_just_released("move_cursor_right"):
				move_direction = 'right'
			if Input.is_action_just_released("move_cursor_left"):
				move_direction = 'left'
			if Input.is_action_just_released("move_cursor_down"):
				move_direction = 'down'
			if Input.is_action_just_released("move_cursor_up"):
				move_direction = 'up'
		
		if event.is_action_pressed("select"):
			selected_question()
			move_direction = ''
			
		if move_direction != '':
			move_selection(move_direction)
		
##when a player picks a question
func selected_question():
	print_debug('Someone selected a question.');
	is_in_daily_double = false
	currently_shown_question = question_box_array[current_position_x][current_position_y]
	
	#if its a question that has already been selected, skip
	if currently_shown_question.disabled:
		return
	
	JeopardyGlobals.CURRENT_GAME_STATE = JeopardyGlobals.GameState.QUESTION_ANSWER
	if onscreen_timer != null:
		onscreen_timer.queue_free()

	
	#is it a daily double
	if currently_shown_question.is_daily_double:
		print_debug('The question selected is a daily double. Changing the state of the game.');
		current_state = QUESTION_AREA_STATES.AWAITING_DAILY_DOUBLE_INPUT
		$TestAnnouncer.show_text_bubble("That's the double Dave! How much do you want to wager?", 2)
		await $TestAnnouncer.text_bubble_hidden
		
		$TestAnnouncer.hide()

		print_debug('Spawning daily double value input .');
		daily_double_child = JeopardyGlobals.DAILY_DOUBLE_SCENE.instantiate()
		daily_double_child.initialize(current_player_selecting, [], is_in_double_jeopardy)
		daily_double_child.player_confirmed.connect(daily_double_value_locked_in)
		add_child(daily_double_child)
		
		$QuestionSpawnLocation.hide()
		$PlayerScoreBoard.highlight_player(current_player_selecting)
		$TestAnnouncer.hide_text_bubble()

		
	else:
		spawn_question_answer_area()
	
##move the cursor around and what not
func move_selection(direction):
	var current_selection = question_box_array[current_position_x][current_position_y]
	if direction == 'right':
		current_position_x = current_position_x + 1
		#basically if it needs to wrap around
		if current_position_x >= NUMBER_OF_COLUMNS:
			current_position_x = 0
			
	if direction == 'left':
		current_position_x = current_position_x - 1
		if current_position_x < 0:
			current_position_x = NUMBER_OF_COLUMNS - 1
			
	if direction == 'up':
		current_position_y = current_position_y - 1
		if current_position_y < 0:
			current_position_y = NUMBER_OF_ROWS - 1
			
	if direction == 'down':
		current_position_y = current_position_y + 1
		if current_position_y >= NUMBER_OF_ROWS:
			current_position_y = 0
	
	var new_selection = question_box_array[current_position_x][current_position_y]
	
	#select the menu option	
	if new_selection != null:
		if current_selection != null:
			current_selection.deselect()
		new_selection.select()
	
	SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)

func return_from_question_show_board():
	print_debug('Returning from question answer scene.');
	#show the question board
	$QuestionSpawnLocation.show()
	#kill the question
	if current_buzz_and_answer_child != null:
		current_buzz_and_answer_child.queue_free()
		current_buzz_and_answer_child = null

	if daily_double_child != null:
		daily_double_child.queue_free()

	#set the gamestate
	JeopardyGlobals.CURRENT_GAME_STATE = JeopardyGlobals.GameState.GAMEBOARD
	current_state = QUESTION_AREA_STATES.WAITING_FOR_SELECTION

	#reset this back to 0 for the next question
	number_of_wrong_guesses = 0
	if currently_shown_question != null:
		currently_shown_question.disable()

	$PlayerScoreBoard.enable_everyone()

	#check if there are any questions still left
	var questions_remain = false
	for col in question_box_array:
		for row in question_box_array[col]:
			if question_box_array[col][row].disabled == false:
				questions_remain = true
	
	if JeopardyGlobals.MINOR_DEBUG_MODE:
		debug_questions_asked += 1
		if debug_questions_asked >= debug_simulate_none_left_after:
			questions_remain = false

	#if there are no more enabled questions
	if questions_remain == false:
		print_debug('There are no questions left. Moving on to either final jeopardy or double jeopardy.');
		#if we need to go to final jeopardy
		if is_in_double_jeopardy:
			print_debug('We are triggering final jeopardy.');
			trigger_final_jeopardy_input()
		#if we need to go to double jeopardy
		else:
			print_debug('We are triggering double jeopardy.');
			trigger_double_jeopardy()

	#if there ARE enabled questions still
	else:
		print_debug('There are questions remaining. Moving on...');
		#highlight the player who should be selecting
		$PlayerScoreBoard.highlight_player(current_player_selecting)

		#create the timer
		create_timer_for_selecting_question()
	
func user_answered_incorrectly(player_id: int, score_value: int):
	#they got a quesiton wrong so set that for the achievement
	ever_got_a_question_wrong = true

	print_debug('Player %d answered incorrectly.' % player_id);
	if is_in_daily_double:
		#if the player bet everything and lost
		if JeopardyGlobals.money_by_player[player_id] == daily_double_val_defined:
			SteamController.set_achievement_achieved(SteamController.Achievements.lost_it_all)

		JeopardyGlobals.change_player_money(player_id, -1 * daily_double_val_defined)
	else:
		JeopardyGlobals.change_player_money(player_id, -1 * score_value)
		number_of_wrong_guesses += 1
		$PlayerScoreBoard.show_disabled(player_id)

	print_debug('Number of wrong guesses: %d Maximum # of wrong guesses: %d.' % [number_of_wrong_guesses, MAX_NUMBER_OF_WRONG_GUESSES]);
	$PlayerScoreBoard.update_score(player_id)
	
	#so many people failed we just bounce, or its a daily double
	if MAX_NUMBER_OF_WRONG_GUESSES <= number_of_wrong_guesses or is_in_daily_double:
		$TestAnnouncer.show_text_bubble('The correct answer was "%s"' % currently_shown_question.correct_answer, 4)
		await $TestAnnouncer.text_bubble_hidden
		return_from_question_show_board()
	else:
		current_buzz_and_answer_child.continue_after_wrong_answer(player_id)

func user_answered_correctly(player_id: int, score_value: int):
	print_debug('Player %d answered correctly.' % player_id);
	#change the money
	if is_in_daily_double:
		JeopardyGlobals.change_player_money(player_id, daily_double_val_defined)
	else:
		JeopardyGlobals.change_player_money(player_id, score_value)
	
	$PlayerScoreBoard.update_score(player_id)
	#set the winner as the selecting player
	current_player_selecting = player_id

	current_state = QUESTION_AREA_STATES.WAITING_FOR_SELECTION

	#move back to the game board  
	return_from_question_show_board()

func nobody_answered():
	print_debug('Nobody answered.');
	$TestAnnouncer.show_text_bubble('Ooo, no takers?', 2)
	await $TestAnnouncer.text_bubble_hidden

	$TestAnnouncer.show_text_bubble('The correct answer was "%s"' % currently_shown_question.correct_answer, 4)
	await $TestAnnouncer.text_bubble_hidden

	return_from_question_show_board()

func user_temporarily_disable(player_id: int, stun_time: float):
	print_debug('Question answer reported player %d answered early.' % player_id);
	$PlayerScoreBoard.temporarily_disable(player_id, stun_time)
	await get_tree().create_timer(stun_time).timeout
	
func user_temporarily_enable(player_id: int):
	print_debug('Temporarily reenabling %d.' % player_id);
	$PlayerScoreBoard.temporarily_reenable(player_id)

##When the timer is up for picking a new question
func question_picking_time_up():
	print_debug('Question picking up ran out.');
	
	#kill the timer and change the state
	if onscreen_timer != null:
		onscreen_timer.queue_free()
	current_state = QUESTION_AREA_STATES.TIME_RAN_OUT_SELECTING

	#remove any highlighting
	$PlayerScoreBoard.highlight_player(-1)
	
	#Make the announcer call you a dummy
	$TestAnnouncer.show_text_bubble('You took too long to pick. Let\'s move on to Player %d!' % (((current_player_selecting + 1) % JeopardyGlobals.number_of_players) + 1), 5)
	await $TestAnnouncer.text_bubble_hidden
	
	#change the current player who is selecting
	current_player_selecting += 1
	current_player_selecting = current_player_selecting % JeopardyGlobals.number_of_players
	set_player_as_active_selector(current_player_selecting)
	
	create_timer_for_selecting_question()
	current_state = QUESTION_AREA_STATES.WAITING_FOR_SELECTION

##Does all things associated with changing who is currently selecting a question
func set_player_as_active_selector(player_id: int):
	print_debug('Setting player %d as active selector.' % player_id);
	current_player_selecting = player_id
	$PlayerScoreBoard.highlight_player(player_id)
	
##Creates a timer, connects all the signals, and starts it
func create_timer_for_selecting_question(time = 20):
	#create a timer
	onscreen_timer = JeopardyGlobals.TIMER_SCENE.instantiate()
	onscreen_timer.initialize(time)
	onscreen_timer.should_expand_and_shrink = false
	onscreen_timer.begin_timer()
	onscreen_timer.connect("time_ran_out", question_picking_time_up)
	$TimerLocation.add_child(onscreen_timer)

##Spawns the question area for a question
func spawn_question_answer_area(daily_double = false, final_jeopardy = false):
	print_debug('Spawning the question answer area.');
	current_buzz_and_answer_child = buzz_in_and_answer_scene.instantiate()

	#bind the signals
	current_buzz_and_answer_child.connect('answered_incorrectly', user_answered_incorrectly)
	current_buzz_and_answer_child.connect('answered_correctly', user_answered_correctly)
	current_buzz_and_answer_child.connect('time_ran_out', nobody_answered)
	current_buzz_and_answer_child.connect('player_temp_disabled', user_temporarily_disable)
	current_buzz_and_answer_child.connect('player_temp_enabled', user_temporarily_enable)

	current_buzz_and_answer_child.final_jeopardy_answered.connect(final_jeopardy_answer_lock_in)
	current_buzz_and_answer_child.final_time_ran_out.connect(final_jeopardy_time_ran_out)
	current_buzz_and_answer_child.scoreboard_object = $PlayerScoreBoard
	
	add_child(current_buzz_and_answer_child)
	
	var time_estimate = 0.0
	
	#do all the logic for figuring out how long the question should show
	#split the sentence in to a bunch of words
	var question_text = currently_shown_question.question_text.to_lower().replace(",", " ").replace("!", " ").replace(".", " ")
	#create a regex and compile it
	var regex = RegEx.new()
	regex.compile(r'\s{1,50}')
	#replace all multiple spaces with 1 space
	question_text = regex.sub(question_text, ' ', true)
	#get the word count and multiply it
	var word_count = len(question_text.split(' '))
	time_estimate = (1.0 * word_count) * SECONDS_PER_WORD
	time_estimate = wrapf(time_estimate, 4, 15)

	current_buzz_and_answer_child.initialize_questions(
		currently_shown_question.question_text,
	 	currently_shown_question.correct_answer,
		currently_shown_question.wrong_answer1,
		currently_shown_question.wrong_answer2,
		currently_shown_question.score_amount,
		JeopardyGlobals.FORCE_QUESTION_TIME if JeopardyGlobals.MINOR_DEBUG_MODE else 0.0,
		$TestAnnouncer,
		current_player_selecting if daily_double else -1,
		final_jeopardy_allowed_players if final_jeopardy else null
		)

	JeopardyGlobals.CURRENT_GAME_STATE = JeopardyGlobals.GameState.QUESTION_ANSWER
	$QuestionSpawnLocation.hide()
	$PlayerScoreBoard.highlight_player(-1)
	$TestAnnouncer.hide_text_bubble()

	#disable all none participating
	if daily_double:
		$PlayerScoreBoard.disable_everyone()
		$PlayerScoreBoard.temporarily_reenable(current_player_selecting)

##Triggers when the person picks a daily double value
func daily_double_value_locked_in(player_id, value):
	print_debug('Player %d locked in their daily double value %d.' % [player_id, value]);
	#hide the question spawn location, show the announcer
	$QuestionSpawnLocation.hide()
	$TestAnnouncer.show()

	var rating = (1.0 * value) / JeopardyGlobals.money_by_player[player_id]
	print(rating)

	#if they have no money, idk what to even say
	if JeopardyGlobals.money_by_player[player_id] <= 0:
		rating = .51

	#rank their bet
	if rating > .99:
		$TestAnnouncer.show_text_bubble('Whoa, a true double up!', 2)
		SteamController.set_achievement_achieved(SteamController.Achievements.true_double_up)
	elif rating > .75:
		$TestAnnouncer.show_text_bubble('What a bet!', 1)
	elif rating > .5:
		$TestAnnouncer.show_text_bubble("Alright, let's see the question!", 2)
	elif rating > .2:
		$TestAnnouncer.show_text_bubble("I've seen bigger bets, but hey, its your choice!", 3)
	else:
		$TestAnnouncer.show_text_bubble("I bet you don't take many chances in life, do ya? Just show the question.", 4)
	#wait for text to end
	await $TestAnnouncer.text_bubble_hidden

	#set the variables used later
	is_in_daily_double = true
	daily_double_val_defined = value

	#we need to spawn the question, with the fact it is a daily double
	spawn_question_answer_area(true)

##changes from single jeopardy to double jeopardy
func trigger_double_jeopardy():
	print_debug('Changing from single jeopardy to double jeopardy.');
	#save the categories
	JeopardySaveData.save_to_file()

	#they didnt get a single question wrong
	if ever_got_a_question_wrong == false:
		SteamController.set_achievement_achieved(SteamController.Achievements.star_guesser)

	#reset this, lest they failed last round and get it next round
	ever_got_a_question_wrong = false

	is_in_double_jeopardy = true
	current_state = QUESTION_AREA_STATES.SPAWNING_QUESTIONS

	$TestAnnouncer.show_text_bubble("That brings us into the double dave round!", 3)
	await $TestAnnouncer.text_bubble_hidden

	print_debug('Getting a current rank of player.');
	var rankings = JeopardyGlobals.get_player_rankings()

	$TestAnnouncer.show_text_bubble("Player %d will take the first pick." % (rankings[-1]['player'] + 1), 3)
	await $TestAnnouncer.text_bubble_hidden

	#delete all question boxes and headers
	var all_questions = get_tree().get_nodes_in_group('question_selection_box')
	for quest in all_questions:
		quest.queue_free()
	all_questions = get_tree().get_nodes_in_group('question_header_box')
	for quest in all_questions:
		quest.queue_free()

	$TestAnnouncer.show_text_bubble('Lets see the new categories!', 3)
	await $TestAnnouncer.text_bubble_hidden

	spawn_questions()

	debug_questions_asked = 0

	print_debug('Setting current player as player in last.');
	current_player_selecting = rankings[-1]['player']
	$PlayerScoreBoard.highlight_player(rankings[-1]['player'])

##changes from double jeopardy to score entry for final jeopardy
func trigger_final_jeopardy_input():
	#they didnt get a single question wrong
	if ever_got_a_question_wrong == false:
		SteamController.set_achievement_achieved(SteamController.Achievements.star_guesser)


	print_debug('Changing from dj to fj.');
	#save the categories
	JeopardySaveData.save_to_file()
	
	current_state = QUESTION_AREA_STATES.AWAITING_FINAL_JEOPARDY_INPUT
	
	print_debug('Getting a list of players who can and cannot participate.');
	#get a list of players that have 0 money
	var players_that_cant_partake = []
	for p in JeopardyGlobals.money_by_player:
		if JeopardyGlobals.money_by_player[p] <= 0:
			players_that_cant_partake.append(p)
		else:
			final_jeopardy_allowed_players.append(p)

	print_debug('Players that cannot partake: "%s"; Players that can: "%s".' % [','.join(players_that_cant_partake), ','.join(final_jeopardy_allowed_players)]);
	#get the final question from the DB
	final_jeopardy_question = JeopardyGlobals.get_final_jeopardy_question()

	var question_box = question_scene.instantiate()
	question_box.init_question(final_jeopardy_question['Question'],
		final_jeopardy_question['AiCorrectAnswer'],
		final_jeopardy_question['WrongAnswer1'],
		final_jeopardy_question['WrongAnswer2'],
		0,
		false,
		false
	)
	currently_shown_question = question_box


	var someone_has_positive_money = false
	for kv in JeopardyGlobals.money_by_player.keys():
		#if a player has more than 0$ lol
		if JeopardyGlobals.money_by_player[kv] > 0:
			someone_has_positive_money = true
			break

	#literally everyone is in the hole
	if someone_has_positive_money == false:
		$TestAnnouncer.show_text_bubble("And that brings us to the fina.... Wait a minute...", 3)
		await $TestAnnouncer.text_bubble_hidden
		$TestAnnouncer.show_text_bubble("None of you have any money?!", 3)
		await $TestAnnouncer.text_bubble_hidden
		$TestAnnouncer.show_text_bubble("Well, okay... It's a race to the bottom I guess.", 3)
		await $TestAnnouncer.text_bubble_hidden

		#TRIGGER FINAL SCORE BUT LOSER VERSION
		create_final_score(true)
		return
		
	
	#show the text for category and announcement
	$TestAnnouncer.show_text_bubble("And that brings us to the final davening!", 3)
	await $TestAnnouncer.text_bubble_hidden

	$TestAnnouncer.show_text_bubble("The category is \"%s\"." % final_jeopardy_question['CategoryName'], 4)
	await $TestAnnouncer.text_bubble_hidden


	#get number of people we are waiting for bets on
	number_of_people_in_final_bet_selection = JeopardyGlobals.number_of_players - len(players_that_cant_partake)
	print_debug('Number of people in final bet selection: %d.' % number_of_people_in_final_bet_selection);

	print_debug('Disabling all non partaking players.');
	for p in players_that_cant_partake:
		$PlayerScoreBoard.show_disabled(p)

	#instantiate the bet input, connect it, and add it to the scene
	daily_double_child = JeopardyGlobals.DAILY_DOUBLE_SCENE.instantiate()
	daily_double_child.initialize(-1, players_that_cant_partake)
	daily_double_child.player_confirmed.connect(final_jeopardy_value_lock_in)
	add_child(daily_double_child)

	#hide the stuff not needed for the bet input
	$QuestionSpawnLocation.hide()
	$PlayerScoreBoard.highlight_player(-1)
	$TestAnnouncer.hide_text_bubble()
	$TestAnnouncer.hide()

func final_jeopardy_value_lock_in(player_id: int, value: int):
	print_debug('Player %d locked in fj value.' % player_id);


	#if the player is in first, and they still bet it all, give em the achievement
	var rankings = JeopardyGlobals.get_player_rankings()
	if JeopardyGlobals.money_by_player[player_id] == value and rankings[0]['player'] == player_id:
		SteamController.set_achievement_achieved(SteamController.Achievements.go_big_or_go_home)

	#change the number of people who hae locked in
	number_of_people_in_final_bet_selection -= 1

	#save who bet what
	final_bet_by_player[player_id] = value

	print_debug('number_of_people_in_final_bet_selection: %d.' % number_of_people_in_final_bet_selection);
	if number_of_people_in_final_bet_selection <= 0:
		print_debug('Number of people remaining for bet selection is 0. Transferring to final jeopardy.');
		transfer_to_final_jeopardy()

func transfer_to_final_jeopardy():
	print_debug('Transferring into final jeopardy from input selection.');
	if daily_double_child != null:
		daily_double_child.queue_free()

	number_of_people_in_final_jeopardy_question = len(final_jeopardy_allowed_players)
	
	$TestAnnouncer.show()
	$TestAnnouncer.show_text_bubble("The bets are in, let's see the question!", 4)
	await $TestAnnouncer.text_bubble_hidden

	print_debug('Spawning answer area with final jeopardy = true.');
	spawn_question_answer_area(false, true)

##if for some reason someone fails to answer in double jeopardy, end the game and mark them as unanswered
func final_jeopardy_time_ran_out():
	print_debug('The final jeopardy timer ran out.');
	going_to_final_score.emit()

func final_jeopardy_answer_lock_in(player_id: int, answer: String, was_correct = true):
	SoundController.play_sound_effect(SoundController.SoundEffects.RightAnswer)
	print_debug('Player %d has locked in their final jeopardy answer.' % player_id);
	#record someone answered
	number_of_people_in_final_jeopardy_question -= 1
	#disable the player in the ui
	$PlayerScoreBoard.show_disabled(player_id)


	final_answer_by_player[player_id]['text'] = answer
	final_answer_by_player[player_id]['correct'] = was_correct
	final_answer_by_player[player_id]['failed_to_answer'] = false


	print_debug('Number of people remaining: %d.' % number_of_people_in_final_jeopardy_question);
	#everyone has answered
	if number_of_people_in_final_jeopardy_question == 0:
		create_final_score()

func create_final_score(no_winners = false):
	print_debug('Emitting that we need to go to the final score.');
	going_to_final_score.emit(no_winners)
