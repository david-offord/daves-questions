extends Node

@export var title_screen_scene: PackedScene
@export var controller_configuration_scene: PackedScene
@export var question_game_scene: PackedScene
@export var final_score_game_scene: PackedScene

var current_game_scene = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	print_debug('Started a new game.');
	JeopardySaveData.load_from_file()
	JeopardySaveData.save_to_file()
	print_debug('Loaded save file.');

	print_debug('Debug mode is %s' % JeopardyGlobals.DEBUG_MODE);

	
	if JeopardyGlobals.DEBUG_MODE:
		#show_title_screen()
		begin_actual_game()
	else:
		show_title_screen()
	

func show_title_screen():
	print_debug('Showing title screen.');
	JeopardyGlobals.start_new_game()
	if current_game_scene != null:
		current_game_scene.queue_free()

	print_debug('Creating the title screen object.');
	var new_scene = title_screen_scene.instantiate()
	current_game_scene = new_scene
	#connect the signal
	new_scene.started_game.connect(open_controller_configuration)
	
	print_debug('Adding the title screen to the scene.');
	#add it to the scene
	add_child(current_game_scene)
	pass

func _process(_delta: float) -> void:
	if Input.is_action_just_released('debug_note'):
		print_debug('MDFD: Someone pressed the debug note button.');

##spawns the controller configuration screen, and then connects it to the completion
func open_controller_configuration():
	print_debug('Opening the controller configuration screen.');
	if current_game_scene != null:
		current_game_scene.queue_free()
	
	var new_scene = controller_configuration_scene.instantiate()
	current_game_scene = new_scene
	#connect the signal
	new_scene.all_controllers_configured.connect(controller_configuration_completed)
	print_debug('Added it to the game scene.');
	#add it to the scene
	add_child(current_game_scene)


func controller_configuration_completed():
	print_debug('Deleting controller configuration and beginning game.');
	#so the controllers are configured, so move onto the main game
	if current_game_scene != null:
		current_game_scene.queue_free()
	begin_actual_game()
	
##start the actual game with the board and what not
func begin_actual_game():
	if current_game_scene != null:
		current_game_scene.queue_free()

	var new_scene = question_game_scene.instantiate()
	new_scene.going_to_final_score.connect(go_to_final_score)
	current_game_scene = new_scene

	print_debug('Adding question area to scene.');
	#load the db
	JeopardyGlobals.reload_db()
	SoundController.play_music()
	add_child(new_scene)

##Show the final score screen, which does all the animating and what not
func go_to_final_score(everyone_sub_zero = false):
	print_debug('Final score has been initiated Creating the scene. everyone_sub_zero=%s' % str(everyone_sub_zero));
	var final_scene = final_score_game_scene.instantiate()
	final_scene.initialize(current_game_scene.final_jeopardy_allowed_players,
		current_game_scene.final_bet_by_player,
		current_game_scene.final_jeopardy_question,
		current_game_scene.final_answer_by_player,
		everyone_sub_zero)

	if current_game_scene != null:
		current_game_scene.queue_free()

	print_debug('Adding the final scene to the tree, and connecting signals.');
	add_child(final_scene)
	current_game_scene = final_scene

	#connect the signals
	current_game_scene.start_new_game.connect(start_new_game)
	current_game_scene.return_to_title.connect(return_to_title)
	current_game_scene.quit_game.connect(quit_game)


##called by the final scene to start a new game (no configuration)
func start_new_game():
	print_debug('Starting a new game was requested by the button on the final score screen.');
	begin_actual_game()

func return_to_title():
	print_debug('Return to title initiated by final score screen.');
	show_title_screen()

##called by the final scene
func quit_game():
	print_debug('Quitting game.');
	get_tree().quit(0)


func _input(event: InputEvent) -> void:
	if JeopardyGlobals.EXTREMELY_VERBOSE_LOGGING:
		print_debug('%s guid %s pressed button %s' % [event.device, Input.get_joy_guid(event.device), event.as_text()])
