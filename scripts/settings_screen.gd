extends Node

signal exited_settings


#state inf
var current_state = SettingScreenState.NOT_IN_POPUP
enum SettingScreenState {
	IN_POPUP,
	NOT_IN_POPUP
}

#changes based on if there are any files in the db folder
var EXTRA_DB_LOCATION = 'user://question_sets/'
var IMPORT_CSVS_LOCATION = 'user://conversion_csvs/'

#BROTHER i do not want to be sued
#var BASE_MDFD_QUESTION_SET = ['Official Jeopardy Questions', 'MDFD Questions']
#var all_question_set_options = ['Official Jeopardy Questions', 'MDFD Questions']

var BASE_MDFD_QUESTION_SET = ['MDFD Questions']
var all_question_set_options = ['MDFD Questions']

var custom_questions_locations = {
	
}

var speed_options = ['0.5x', '1x', '1.5x', '2x']
var se_options = []

#positions of buttons
var RETURN_TO_TITLE_BUTTON_POS = 4
var CREATE_QUESTIONS_BUTTON_POS = 5

#variables for selecting and moving
var current_option_position = 0

#bro the integer way of doing this was NOT the move lmfao
var button_by_option_position: Dictionary[int, Control] = {0: null}

#current values
var current_value = {
	0: 0,
	1: 2,
	2: 20,
	3: 20
}

var past_8_inputs := []
var secret_code := ['left', 'up', 'right', 'down', 'left', 'down', 'down', 'select']

func _ready() -> void:
	find_any_other_question_dbs()
	JeopardyGlobals.CURRENT_GAME_STATE = JeopardyGlobals.GameState.SETTINGS_MENU
	button_by_option_position = {
		0: $MainMenuButtons/QuestionSetRow/Value,
		1: $MainMenuButtons/SlowModeRow/Value,
		2: $MainMenuButtons/SoundEffects/Value,
		3: $MainMenuButtons/MusicVolume/Value,
		RETURN_TO_TITLE_BUTTON_POS: $MainMenuButtons/ReturnToTitle,
		CREATE_QUESTIONS_BUTTON_POS: $MainMenuButtons/CreateQuestionSets,
	}

	for i in range(0, 21):
		se_options.append(i * 5)

	#grab focus on first button
	#button_by_option_position[current_option_position].grab_focus()

	#get the setting values from the save game
	#do the db first
	var option_iter = all_question_set_options.find(JeopardySaveData.jeopardy_set)
	current_value[0] = option_iter if option_iter != -1 else 0
	#the time modifier
	option_iter = speed_options.find(JeopardySaveData.time_modifier)
	current_value[1] = option_iter if option_iter != -1 else 0
	#the sound effect volume
	option_iter = se_options.find(JeopardySaveData.se_volume)
	current_value[2] = option_iter if option_iter != -1 else (len(se_options) - 1)
	option_iter = se_options.find(JeopardySaveData.me_volume)
	current_value[3] = option_iter if option_iter != -1 else (len(se_options) - 1)

	print(OS.get_user_data_dir())

	initialize_setting_values()


#look man, this was a mistake alright, i can admit it myself. im embarassed. but im like basically done with this project
#so im just gonna fart this out and make a work around here lmfao
func _input(event):
	#all for secret announcer
	if event.is_action_pressed("move_cursor_down"):
		add_input_and_check('down')
	if event.is_action_pressed("move_cursor_up"):
		add_input_and_check('up')
	if event.is_action_pressed("move_cursor_right"):
		add_input_and_check('right')
	if event.is_action_pressed("move_cursor_left"):
		add_input_and_check('left')
	if event.is_action_pressed("select"):
		add_input_and_check('select')

		
	#if the csv import popup is still present
	if current_state == SettingScreenState.IN_POPUP:
		if event.is_action_pressed("select"):
			hide_popup()
			return
		else:
			get_viewport().set_input_as_handled()
			return


	var old_current_option_position = current_option_position
	if event.is_action_pressed("move_cursor_down"):
		if current_option_position == RETURN_TO_TITLE_BUTTON_POS:
			current_option_position = -1
		current_option_position += 1
	if event.is_action_pressed("move_cursor_up"):
		if current_option_position == CREATE_QUESTIONS_BUTTON_POS:
			current_option_position -= 1
		current_option_position -= 1

	if event.is_action_pressed("move_cursor_left"):
		change_setting_value(false)
	if event.is_action_pressed("move_cursor_right"):
		change_setting_value(true)
		
	#they moved
	if current_option_position != old_current_option_position:
		SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)

	#wrap posityion to valid ones
	current_option_position = wrapi(current_option_position, 0, len(button_by_option_position))

	var selected_node = button_by_option_position[current_option_position]

	if event.is_action_pressed("select") and current_option_position == RETURN_TO_TITLE_BUTTON_POS:
		completed_settings()
	if event.is_action_pressed("select") and current_option_position == CREATE_QUESTIONS_BUTTON_POS:
		create_dbs_from_csvs()


	#hide all arrows
	var all_arrows = get_tree().get_nodes_in_group('Arrows')
	for arrow in all_arrows:
		arrow.hide()

	#show the arrows
	var parent = button_by_option_position[current_option_position].get_parent()
	if parent.has_node('LeftArrow'):
		parent.get_node('LeftArrow').show()
		parent.get_node('RightArrow').show()
		button_by_option_position[RETURN_TO_TITLE_BUTTON_POS].release_focus()
		button_by_option_position[CREATE_QUESTIONS_BUTTON_POS].release_focus()

	#if its the button at the bottom
	elif selected_node is Button:
		selected_node.grab_focus()
	
	get_viewport().set_input_as_handled()

func initialize_setting_values():
	button_by_option_position[0].text = all_question_set_options[current_value[0]]
	button_by_option_position[1].text = speed_options[current_value[1]]
	button_by_option_position[2].text = '%d%%' % se_options[current_value[2]]
	button_by_option_position[3].text = '%d%%' % se_options[current_value[3]]

	#change the text on load
	if button_by_option_position[current_option_position].text == 'MDFD Questions':
		$MainMenuButtons/QuestionSetRow/SettingText.text = "Questions written by the developer of Dave's Questions (and his friends)."
	elif button_by_option_position[current_option_position].text == 'Official Jeopardy Questions':
		$MainMenuButtons/QuestionSetRow/SettingText.text = "The 2 wrong answers were generated by AI. Answers may seem obvious."
	else:
		$MainMenuButtons/QuestionSetRow/SettingText.text = 'Custom question set provided by the user.'

func change_setting_value(right):
	#question set
	if current_option_position == 0:
		current_value[current_option_position] += 1 if right else -1
		current_value[current_option_position] = wrapi(current_value[current_option_position], 0, len(all_question_set_options))
		button_by_option_position[current_option_position].text = all_question_set_options[current_value[current_option_position]]

		#if its the ones that come with it
		if button_by_option_position[current_option_position].text == 'MDFD Questions':
			$MainMenuButtons/QuestionSetRow/SettingText.text = "Questions written by the developer of Dave's Questions (and his friends)."
		elif button_by_option_position[current_option_position].text == 'Official Jeopardy Questions':
			$MainMenuButtons/QuestionSetRow/SettingText.text = "The 2 wrong answers were generated by AI. Answers may seem obvious."
		else:
			$MainMenuButtons/QuestionSetRow/SettingText.text = 'Custom question set provided by the user.'


	#game speed
	if current_option_position == 1:
		current_value[current_option_position] += 1 if right else -1
		current_value[current_option_position] = wrapi(current_value[current_option_position], 0, len(speed_options))
		button_by_option_position[current_option_position].text = speed_options[current_value[current_option_position]]
		
	#sound effects
	if current_option_position == 2 or current_option_position == 3:
		current_value[current_option_position] += 1 if right else -1
		current_value[current_option_position] = wrapi(current_value[current_option_position], 0, len(se_options))
		button_by_option_position[current_option_position].text = '%d%%' % se_options[current_value[current_option_position]]

		if current_option_position == 2:
			JeopardySaveData.se_volume = se_options[current_value[2]]
		if current_option_position == 3:
			SoundController.adjust_volume_of_me(se_options[current_value[current_option_position]])

	if current_option_position == 4:
		current_option_position = 5
	elif current_option_position == 5:
		current_option_position = 4

	SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)

func completed_settings():
	JeopardySaveData.jeopardy_set = all_question_set_options[current_value[0]]
	if all_question_set_options[current_value[0]] not in BASE_MDFD_QUESTION_SET and all_question_set_options[current_value[0]] in custom_questions_locations:
		JeopardySaveData.jeopardy_set_custom_location = custom_questions_locations[all_question_set_options[current_value[0]]]

	JeopardySaveData.time_modifier = speed_options[current_value[1]]
	JeopardySaveData.se_volume = se_options[current_value[2]]
	JeopardySaveData.me_volume = se_options[current_value[3]]

	if JeopardySaveData.me_volume == 0:
		SteamController.set_achievement_achieved(SteamController.Achievements.i_hate_bossa_nova)

	exited_settings.emit()

func find_any_other_question_dbs():
	custom_questions_locations = {}
	#all_question_set_options = ['Official Jeopardy Questions', 'MDFD Questions']
	all_question_set_options = ['MDFD Questions']
	
	#if it doesnt exist create it
	if DirAccess.dir_exists_absolute(EXTRA_DB_LOCATION) == false:
		DirAccess.make_dir_absolute(EXTRA_DB_LOCATION)
		DirAccess.copy_absolute('res://question_set_dbs/README', EXTRA_DB_LOCATION + '/README')
		DirAccess.copy_absolute('res://question_set_dbs/base_db.schema', EXTRA_DB_LOCATION + '/base_db.schema')
		
	if DirAccess.dir_exists_absolute(IMPORT_CSVS_LOCATION) == false:
		DirAccess.make_dir_absolute(IMPORT_CSVS_LOCATION)
		DirAccess.copy_absolute('res://question_set_dbs/CSVREADME', IMPORT_CSVS_LOCATION + '/README')
		DirAccess.copy_absolute('res://question_set_dbs/sample_csv.csv', IMPORT_CSVS_LOCATION + '/sample_csv.csv')

	
	#read every file in the directory
	for file in DirAccess.get_files_at(EXTRA_DB_LOCATION):
		#if its not a db file
		if file.ends_with('.db') == false:
			continue

		var possible_db = SQLite.new()
		possible_db.path = '%s/%s' % [EXTRA_DB_LOCATION, file]
		possible_db.open_db()

		possible_db.query("SELECT * FROM questions limit 1;")
		var results = possible_db.query_result

		#if there are no questions
		if len(results) == 0:
			print('File %s was a .db file, but when opened, it either didnt match the schema, or had no questions in the questions table.' % file)
			continue

		possible_db.query("SELECT QuestionSetNameUI AS Name FROM info WHERE QuestionSetNameUI IS NOT NULL limit 1")
		results = possible_db.query_result

		#if theres no info, then go ahead and skip it
		if len(results) == 0:
			print('File %s was a .db file, but when opened, it either didnt match the schema, or had no data in the info table.' % file)
			continue

		possible_db.close_db()

		
		var problems_with_db = check_db_valid('%s/%s' % [EXTRA_DB_LOCATION, file])
		if len(problems_with_db) != 0:
			print('File %s had the following issues: %s.' % [file, (', '.join(problems_with_db))])
			continue


		#it passed all the other checks, so go ahead and add it to the options
		all_question_set_options.append(results[0]['Name'])
		custom_questions_locations[results[0]['Name']] = '%s/%s' % [EXTRA_DB_LOCATION, file]


func create_dbs_from_csvs():
	var log_messages = ''
	var had_at_least_one_success = false

	for file in DirAccess.get_files_at(IMPORT_CSVS_LOCATION):
		if file.ends_with('.csv') == false:
			continue

		if file == 'sample_csv.csv':
			continue


		var csv_file: FileAccess = FileAccess.open(IMPORT_CSVS_LOCATION.path_join(file), FileAccess.READ)
		if csv_file == null:
			printerr("Could not open file: %s" % error_string(FileAccess.get_open_error()))
			log_messages += "Error processing %s - Could not open file: %s\n" % [file, error_string(FileAccess.get_open_error())]
			continue

		var categories = {}
		var file_name_base = file.get_file().get_basename()

		print_debug('Beginning csv conversion for %s.' % file);

		#read the first header line
		csv_file.get_csv_line()
	
		#copy the sample file over
		DirAccess.copy_absolute('res://question_set_dbs/sample_import.db', EXTRA_DB_LOCATION + '/%s.db' % file_name_base)

		var new_questions_db = SQLite.new()
		new_questions_db.path = EXTRA_DB_LOCATION + '/%s.db' % file_name_base
		new_questions_db.open_db()

		var category_increment = 0
		#go line by line and save it to a local object
		while not csv_file.eof_reached():
			var line_content: PackedStringArray = csv_file.get_csv_line()

			if len(line_content) < 3:
				continue

			var category_name = line_content[0]
			var category_id = -1
			
			#if we didnt already add it
			if category_name not in categories:
				categories[category_name] = category_increment
				var category_type = ''
				if len(line_content) > 6:
					category_type = line_content[6]

				new_questions_db.insert_row('Categories', {
					'Id': category_increment,
					"CategoryName": category_name,
					'CategoryType': category_type
				})

				category_increment += 1

			#get the id to insert with
			category_id = categories[category_name]

			#insert the question
			new_questions_db.insert_row('Questions', {
				'Question': line_content[1],
				'CorrectAnswer': line_content[2],
				'AiCorrectAnswer': line_content[2],
				'WrongAnswer1': line_content[3],
				'WrongAnswer2': line_content[4],
				'Value': line_content[5],
				'CategoryId': category_id
			})

		var username = 'Unknown'
		#get whatever username the playert is using
		if OS.has_environment("USER"):
			username = OS.get_environment("USER")
		elif OS.has_environment("USERNAME"):
			username = OS.get_environment("USERNAME")

		#finally, add the metadata
		new_questions_db.insert_row('Info', {
			'QuestionSetNameUI': file_name_base.replace('_', ' ').substr(0, 50),
			'Author': username
		})


		#close it (we succeeded)
		new_questions_db.close_db()

		var problems_with_db = check_db_valid(EXTRA_DB_LOCATION + '/%s.db' % file_name_base)

		if len(problems_with_db) == 0:
			print_debug('Sucessfully turned %s into a question set.' % file);
			log_messages += 'Sucessfully turned %s into a question set.\n' % file
			had_at_least_one_success = true
		else:
			printerr('File %s had the following issues: %s' % [file, (', '.join(problems_with_db))]);
			log_messages += 'File %s had the following issues: %s\n' % [file, (', '.join(problems_with_db))]
			DirAccess.remove_absolute(EXTRA_DB_LOCATION + '/%s.db' % file_name_base)

		log_messages += '\n'

	if log_messages == '':
		log_messages += 'No .csv files found in %s%s.\n\n\n' % [(OS.get_user_data_dir().replace('/', '\\')), "\\conversion_csvs"]

	log_messages += '\n\n\n\nPress Enter/A/Spacebar to hide this menu.'

	#they imported at least one question, so mark it achieved
	if had_at_least_one_success:
		SteamController.set_achievement_achieved(SteamController.Achievements.ill_take_it_from_here)

	#show the log messages and change states
	$MainMenuButtons/PopupLogs/LogOutput.text = log_messages
	$MainMenuButtons/PopupLogs.show()
	current_state = SettingScreenState.IN_POPUP

	#load them into the view
	find_any_other_question_dbs()
	#reset the value to the default
	current_value[0] = 0
	button_by_option_position[0].text = all_question_set_options[0]


func check_db_valid(db_path):
	var check_db = SQLite.new()
	check_db.path = db_path
	check_db.open_db()
	
	var problems = []

	#so now, check if there is actually 12 categories at least, and 5 questions per category:
	check_db.query('select distinct count(CategoryName) AS cat_count from Categories;')
	var res = check_db.query_result[0]['cat_count']

	#if theres less than 12 categories, since thats the bare minimum we need
	if int(res) < 12:
		problems.append('Not enough categories (12 required, %d in question set)' % int(res))
		

	#so now, check if there are 12 categories with at least 5 questions:
	check_db.query('select count(*) AS cat_count
					from (select distinct c.CategoryName, count(q.Id) AS questionCount 
					from Questions q
					inner join Categories c on q.CategoryId = c.Id
					group by c.CategoryName)
					where questionCount >= 5')
	res = check_db.query_result[0]['cat_count']
	#if theres less than 12 categories, since thats the bare minimum we need
	if int(res) < 12:
		if len(problems) == 0:
			problems.append('There are at least 12 categories, however there are not 12 categories with at least 5 questions, which is required. (%d categories had >= 5 questions)' % int(res))

	check_db.close_db()

	return problems
	
func hide_popup():
	$MainMenuButtons/PopupLogs/LogOutput.text = ''
	$MainMenuButtons/PopupLogs.hide()
	current_state = SettingScreenState.NOT_IN_POPUP

func add_input_and_check(inp := ''):
	if len(past_8_inputs) > 7:
		past_8_inputs = past_8_inputs.slice(1, 8)
	past_8_inputs.append(inp)

	if secret_code == past_8_inputs:
		JeopardySaveData.custom_announcer = !JeopardySaveData.custom_announcer
		print_debug('Toggled the custom announcer field in save data.');
