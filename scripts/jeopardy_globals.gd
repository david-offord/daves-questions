extends Node

#DEBUG STUFF
var DEBUG_MODE = false # general state changes, skipping entire sections of game - only used for testing specific features
var MINOR_DEBUG_MODE = true # smaller changes (i.e. number of questions to do before state change)
var ACHIEVEMENT_DEBUGGING = false # shows a thing saying steam would have unlocked an achievement
var FIRST_QUESTION_ALWAYS_DAILY_DOUBLE = false # stops shuffling of questions at start of round, and makes the first 1 (or 2) the daily double
var DEBUG_ALL_QUESTIONS_DAILY_DOUBLE = false # turn all questions into daily doubles
var DEBUG_DEMO_PURPOSES = false # allows this to be played with only the keyboard
var SINGLEPLAYER_TESTING = false # allows one person to use the same controller for 2 plaers
var VERBOSE_LOGGING = false # for testing, logs more detailed things about player controller input
var EXTREMELY_VERBOSE_LOGGING = false # extremely verbose, literally logging every input made on a global level
var FORCE_QUESTION_TIME = 2.0 # time to make a question read time, if MINOR_DEBUG_MODE is enabled

#this is set and displayed if there was an issue loading the db file 
var db_load_error_msg = ''

#CONSTANTS 
var HOW_LONG_TO_STUN_ON_EARLY_BUZZ = 2.0

#STATE INFORMATION
enum GameState {
		MAIN_MENU,
		CHARACTER_SELECT,
		GAMEBOARD,
		QUESTION_ANSWER,
		CONTROLLER_CONFIGURATION,
		SETTINGS_MENU
	}
	
var CURRENT_GAME_STATE = GameState.GAMEBOARD

#PACKED SCENES USED EVERYWHERE
var TIMER_SCENE = preload("res://scenes/on_screen_timer_new.tscn")
var DAILY_DOUBLE_SCENE = preload("res://scenes/daily_double_input.tscn")

#VARIABLES USED EVERYWHERE
var number_of_players = 3
var money_by_player: Dictionary[int, int] = {
	0: 0,
	1: 0,
}

#map of player guid to device id
var player_id_by_device_guid = {
	0: '',
	1: '',
}

var player_to_ever_negative = {
	0: '',
	1: ''
}

#load a base database
var questions_db = SQLite.new()

func _ready() -> void:
	if DEBUG_MODE:
		money_by_player = {
			0: 4300,
			1: - 4900,
			2: - 10,
		}
		number_of_players = 2
		set_player_id_and_guid(0, 0)

	else:
		money_by_player = {
			0: 0,
			1: 0,
			2: 0,
		}


func reload_db():
	db_load_error_msg = ''

	#for legal reasons, we dont have this option anymore lol
	if JeopardySaveData.jeopardy_set == 'Official Jeopardy Questions':
		questions_db.path = 'res://question_set_dbs/original_jeopardy_questions.db'
	elif JeopardySaveData.jeopardy_set == 'MDFD Questions':
		questions_db.path = 'res://question_set_dbs/data.db'
	#its a custom data set
	else:
		#if it actually exists, go ahead and load it
		if FileAccess.file_exists(JeopardySaveData.jeopardy_set_custom_location) and JeopardySaveData.jeopardy_set_custom_location != '':
			questions_db.path = JeopardySaveData.jeopardy_set_custom_location
		#if it does not, then load the default
		else:
			printerr('DB File %s could not be found/loaded. Moving on...' % JeopardySaveData.jeopardy_set_custom_location.replace('user:/', OS.get_user_data_dir()));
			db_load_error_msg = 'Just so you know, I tried to load the custom db file you specified in the settings, but I failed to do so. You should look in the logs.'
			questions_db.path = 'res://question_set_dbs/data.db'
			JeopardySaveData.jeopardy_set = 'MDFD Questions'
			JeopardySaveData.save_to_file()

	
	questions_db.open_db()

func change_player_money(playerId: int, money: int):
	if playerId not in money_by_player:
		print_debug('Money was attempted to be changed for player %d but that player wasnt in the player money obj. Adding the player now.' % playerId)
		money_by_player[playerId] = 0
		#return
	money_by_player[playerId] = money_by_player[playerId] + money

	if money_by_player[playerId] < 0:
		player_to_ever_negative[playerId] = true

	#set how much money they have gained (i dont think it makes sense to lower it, idk if you even can in steam)
	if money > 0:
		SteamController.set_statistic(SteamController.Statistics.money_gained_in_totality, money)

func set_up_player_money():
	money_by_player = {}
	for i in range(0, number_of_players):
		money_by_player[i] = 0
		player_to_ever_negative[i] = false

	if DEBUG_DEMO_PURPOSES:
		for i in money_by_player.keys():
			money_by_player[i] = (randi_range(100, 25000) / 100) * 100

func get_categories(amount = 6):
	questions_db.query("SELECT 
						    c.id AS Id,
						    c.CategoryName AS CategoryName
						FROM categories c
						INNER JOIN questions q 
						    ON q.CategoryId = c.id
						WHERE q.WrongAnswer1 IS NOT NULL and q.Question!=''
						GROUP BY c.id, c.CategoryName
						HAVING COUNT(q.id) > 4;")
	
	var category_options = questions_db.query_result
	category_options.shuffle()

	var category_options_temp = category_options.filter(func(x): return JeopardySaveData.categories_seen.has(str(x['Id'])) == false)
	
	#if we have enough to restrict them
	if len(category_options_temp) >= amount:
		category_options = category_options_temp

	#we have seen them all , so start over
	else:
		JeopardySaveData.categories_seen = []

	var retval = category_options.slice(0, amount).map(func(x): return {'CategoryName': x['CategoryName'], 'Id': x['Id']})
	return retval
	
func get_questions(category_id: int):
	var return_questions = {
		200: null,
		400: null,
		600: null,
		800: null,
		1000: null,
	}
	
	var already_used_questions = []
	
	questions_db.query("SELECT * FROM questions where CategoryId='%d' and WrongAnswer1 is not NULL and Question!='' ;" % category_id)
	var questions = questions_db.query_result
	#mix em up
	questions.shuffle()
	
	#for every question from the db
	for question in questions:
		#if the value isnt valid, skip
		if question['Value'] == null or question['Value'] not in return_questions:
			continue
		#if the value for this is still null in our answer options, set it here
		if return_questions[question['Value']] == null:
			return_questions[question['Value']] = question
			already_used_questions.append(question['Id'])
	
	#check if any questions are null
	for val in return_questions.keys():
		#if they are, then grab a random item from the array
		if return_questions[val] == null:
			#get a list of questions that have not already been picked
			return_questions[val] = questions.filter(func(x): return x['Id'] not in already_used_questions).pick_random()
			return_questions[val]['Value'] = val
			#add the newly added quesiton to the array
			already_used_questions.append(return_questions[val]['Id'])
		
	return return_questions

func get_final_jeopardy_question():
	questions_db.query("SELECT q.*, c.CategoryName FROM questions q inner join categories c on c.Id = q.CategoryId where value > 600 and WrongAnswer1 is not NULL and Question!=''  ORDER BY RANDOM() LIMIT 1")
	var questions = questions_db.query_result
	return questions[0]

func get_player_rankings():
	var playermoney = []
	for key in money_by_player:
		playermoney.append({'player': key, 'value': money_by_player[key]})

	playermoney.sort_custom(player_sort_algo)

	return playermoney

func player_sort_algo(a: Dictionary, b: Dictionary) -> bool:
	return a['value'] > b['value']

#func is_there_a_tie():
#	mo = 

func set_player_id_and_guid(player_id: int, controller_id: int, is_keyboard = false):
	print(is_keyboard)
	number_of_players += 1
	player_id_by_device_guid[player_id] = '%d_%s' % [controller_id, is_keyboard]
	print('%d_%s' % [controller_id, is_keyboard])
	
	money_by_player[player_id] = 0

##get the id of the player based on the controller guid
func get_player_id_by_guid(cont_id, is_keyboard = false):
	for entry in player_id_by_device_guid:
		if player_id_by_device_guid[entry] == '%d_%s' % [cont_id, is_keyboard]:
			return entry
	#some random controller is buzzing in
	return -1

func start_new_game(reset_controllers = false):
	if reset_controllers:
		#reset the player info
		player_id_by_device_guid = {
			0: '',
			1: '',
		}

		#reset the number of players
		number_of_players = 3

func format_currency(number_int: int) -> String:
	if number_int < 0:
		number_int *= -1

	var number_string := "%d" % float(number_int)
		
	var decimal_pos = number_string.length()
		
	for idx in range(decimal_pos - 3, 0, -3):
		number_string = number_string.insert(idx, ",")
		
	return "$" + number_string

func format_scoreboard_currency(number_int: int) -> String:
	var is_negative = false
	if 0 > number_int:
		is_negative = true

	var formatted := format_currency(number_int)
	return ('-' if is_negative else '') + formatted
