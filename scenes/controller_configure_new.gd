extends Control

signal backout_of_config
signal all_controllers_configured

#so, tragically, i looked it up, and my settings screen thing was considered the best option for a settings thing lmfaoooo
#so here we go

# EVERYONE JUST SHUT THE FUCK UP
#LET ME FUCKING THINK!

@export var press_a_area: Control
@export var comp_choices_menu: Control

@export var controller_config_prompt: Control

enum State {
	HumanCpuConfig,
	ControllerMapping
}
enum ControllerConfigureState {WAITING_FOR_A, ANIMATING, COMPLETE}

var current_game_state := State.HumanCpuConfig
var current_controller_state = ControllerConfigureState.WAITING_FOR_A

#CONTROLLER STUFF
var MAX_NUMBER_OF_CONTROLLERS = 3
var already_used_controllers = []
var current_controller_configuring = 0
var can_complete = false
#END CONTROLLER STUFF

#stuff for moving around menu
var menu_position := 0
var option_position := 0 # basically which of possible values

#constants for this dogshit menu system I built
#built is a gradoise word for this. i would prefer "shat out"
var HUMAN_PLAYER_POSITION := 0
var CPU_PLAYER_POSITION := 1
var CPU_DIFFICULTY_POSITION := 2
var RETURN_TO_TITLE_BUTTON_POS := 4
var START_GAME := 3
#end constants

#All stuff regarding values and labels
var menu_value_by_position = {
	HUMAN_PLAYER_POSITION: 2, # hp
	CPU_PLAYER_POSITION: 1, # cpus
	CPU_DIFFICULTY_POSITION: 'Hard' # diff
}

var menu_possible_values_by_position = {
	HUMAN_PLAYER_POSITION: [1, 2, 3, ],
	CPU_PLAYER_POSITION: [0, 1, 2, ],
	CPU_DIFFICULTY_POSITION: ['Easy', 'Medium', 'Hard']
}

@onready var menu_labels_by_position: Dictionary[int, Control] = {
	HUMAN_PLAYER_POSITION: $CompPlayerNumberChoice/HumanPlayerRow/HPValue,
	CPU_PLAYER_POSITION: $CompPlayerNumberChoice/ComputerPlayerRow/CPUValue,
	CPU_DIFFICULTY_POSITION: $CompPlayerNumberChoice/ComputerDifficulty/CPUDiffValue,
	RETURN_TO_TITLE_BUTTON_POS: $CompPlayerNumberChoice/ButtonsRow/ReturnToTitle,
	START_GAME: $CompPlayerNumberChoice/ButtonsRow/Start,
}

var final_player_count := 0
var final_cpu_count := 0
var final_cpu_difficult := ''


#if its 3 players (humans)
var full_human_game:
	get:
		return menu_value_by_position[0] == 3
#theres at least 1 cpu playuer configured
var show_cpu_options:
	get:
		return menu_value_by_position[1] > 0


func _ready() -> void:
	#reset the number of players
	JeopardyGlobals.number_of_players = 0
	JeopardyGlobals.CURRENT_GAME_STATE = JeopardyGlobals.GameState.CONTROLLER_CONFIGURATION

	#grab the defaults from savedata
	menu_value_by_position[HUMAN_PLAYER_POSITION] = JeopardySaveData.default_player_amts
	menu_value_by_position[CPU_PLAYER_POSITION] = JeopardySaveData.default_comp_amts
	menu_value_by_position[CPU_DIFFICULTY_POSITION] = JeopardySaveData.default_comp_diff

	update_value_labels()
	option_position = menu_possible_values_by_position[menu_position].find(menu_value_by_position[menu_position])


func update_value_labels():
	#for every key
	for l in menu_labels_by_position.keys():
		if menu_labels_by_position[l] is Label:
			menu_labels_by_position[l].text = str(menu_value_by_position[l])


func _input(event):
	#bail if we are not even in the controller config screen
	if JeopardyGlobals.CURRENT_GAME_STATE != JeopardyGlobals.GameState.CONTROLLER_CONFIGURATION:
		return

	if current_game_state == State.HumanCpuConfig:
		if event.is_action_pressed("select") and menu_position == START_GAME:
			finish_cpu_config()
		if event.is_action_pressed("select") and menu_position == RETURN_TO_TITLE_BUTTON_POS:
			back_out()


		if len(menu_labels_by_position.keys()) == 0:
			get_viewport().set_input_as_handled()
			return
			
		#if they try to back out, then go back to the title screen (emit that one return thing)
		if event.is_action_pressed("back_exit_return"):
			back_out()
			get_viewport().set_input_as_handled()


		#handle moving the selection up and down
		var old_menu_position = menu_position
		if event.is_action_pressed("move_cursor_down"):
			if menu_position == START_GAME:
				menu_position = -1
			menu_position += 1
		if event.is_action_pressed("move_cursor_up"):
			if menu_position == RETURN_TO_TITLE_BUTTON_POS:
				menu_position -= 1
			elif menu_position == 0:
				menu_position -= 1
			menu_position -= 1

		#this is because I programmed it poorly, basically if its on an invisible option
		if menu_position == CPU_PLAYER_POSITION || menu_position == CPU_DIFFICULTY_POSITION:
			if full_human_game:
				if event.is_action_pressed("move_cursor_down"):
					menu_position = START_GAME
				if event.is_action_pressed("move_cursor_up"):
					menu_position = HUMAN_PLAYER_POSITION

			if show_cpu_options == false and menu_position == CPU_DIFFICULTY_POSITION:
				if event.is_action_pressed("move_cursor_down"):
					menu_position = START_GAME
				if event.is_action_pressed("move_cursor_up"):
					menu_position = CPU_PLAYER_POSITION


		#change how many CPUs could exist as options
		if menu_position == CPU_PLAYER_POSITION:
			menu_possible_values_by_position[menu_position] = range(0, 4 - menu_value_by_position[0])
			if menu_value_by_position[0] == 1:
				menu_possible_values_by_position[menu_position].remove_at(0)


		#change the options left and right
		if event.is_action_pressed("move_cursor_left"):
			change_setting_value(false)
		if event.is_action_pressed("move_cursor_right"):
			change_setting_value(true)
			
			
		#wrap posityion to valid ones
		menu_position = wrapi(menu_position, 0, len(menu_labels_by_position))


		#they moved, so play a sound
		if menu_position != old_menu_position:
			SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)
			if menu_position in menu_possible_values_by_position:
				option_position = menu_possible_values_by_position[menu_position].find(menu_value_by_position[menu_position])

		#hide all arrows
		var all_arrows = get_tree().get_nodes_in_group('Arrows')
		for arrow in all_arrows:
			arrow.hide()

		#change what node is selected (though I never use this lmfaoooo)
		var selected_node = menu_labels_by_position[menu_position]

		#show the arrows
		var parent = menu_labels_by_position[menu_position].get_parent()
		if parent.has_node('LeftArrow'):
			parent.get_node('LeftArrow').show()
			parent.get_node('RightArrow').show()
			menu_labels_by_position[RETURN_TO_TITLE_BUTTON_POS].release_focus()
			menu_labels_by_position[START_GAME].release_focus()

		#if its the button at the bottom
		elif selected_node is Button:
			selected_node.grab_focus()
	

	elif current_game_state == State.ControllerMapping:
		#if they should be able to move
		if current_controller_state != ControllerConfigureState.WAITING_FOR_A:
			return
		
		#if they try to back out, then go back to the human cpu config
		if event.is_action_pressed("back_exit_return"):
			back_out_to_cpu_menu()
			get_viewport().set_input_as_handled()


		if JeopardyGlobals.VERBOSE_LOGGING:
			print('controller_configure.gd: ' + Input.get_joy_name(event.device) + ' (' + Input.get_joy_guid(event.device) + (') - %d' % event.device))
			
		#check if its a keyboard entry
		var is_keyboard_input = event is InputEventKey or event is InputEventMouse
		
		#check if the controller has already been assigned	
		if '%d_%s' % [event.device, is_keyboard_input] not in already_used_controllers:
			#make sure they actually press the a button
			if event.is_action_pressed('select'):
				#set the controller config and lock buzz ins for a bit
				set_controller_config(event.device, is_keyboard_input)
				#vibrate their cont and play a chime only if its not a keyboard
				if is_keyboard_input == false:
					Input.start_joy_vibration(event.device, 0.75, 0.75, .2)
				SoundController.play_sound_effect(SoundController.SoundEffects.RightAnswer)


		#basically if player one is the one responding, and they can back out
		if (JeopardyGlobals.SINGLEPLAYER_TESTING || can_complete) and JeopardyGlobals.get_player_id_by_guid(event.device, is_keyboard_input) == 0:
			#did they decide to bow out
			if event.is_action_pressed('end_controller_configuration'):
				#bro i am out of here
				current_controller_state = ControllerConfigureState.COMPLETE
				all_controllers_configured.emit()


	get_viewport().set_input_as_handled()


func change_setting_value(right):
	#JUST END THIS PROJECT!!!!
	if menu_position == START_GAME:
		menu_position = RETURN_TO_TITLE_BUTTON_POS
		SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)
		return
	elif menu_position == RETURN_TO_TITLE_BUTTON_POS:
		menu_position = START_GAME
		SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)
		return

	option_position += 1 if right else -1

	#if menu_position == 1:
		#basically, if theres 1 computer player already, keep it stuck on 1/2


	option_position = wrapi(option_position, 0, len(menu_possible_values_by_position[menu_position]))
	menu_value_by_position[menu_position] = menu_possible_values_by_position[menu_position][option_position]
	menu_labels_by_position[menu_position].text = str(menu_possible_values_by_position[menu_position][option_position])

	var combined_player_value = menu_value_by_position[0] + menu_value_by_position[1]

	#if they select 1 hp, we need a bare minimum of 0
	if combined_player_value == 1:
		menu_value_by_position[1] = 1
		update_value_labels()
	if combined_player_value > 3:
		menu_value_by_position[1] = 0
		update_value_labels()


	if menu_position == RETURN_TO_TITLE_BUTTON_POS:
		menu_position = START_GAME
	elif menu_position == START_GAME:
		menu_position = RETURN_TO_TITLE_BUTTON_POS

	SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)

	if full_human_game:
		menu_labels_by_position[1].get_parent().hide()
		menu_labels_by_position[2].get_parent().hide()
	elif show_cpu_options:
		menu_labels_by_position[1].get_parent().show()
		menu_labels_by_position[2].get_parent().show()
	else:
		menu_labels_by_position[1].get_parent().show()
		menu_labels_by_position[2].get_parent().hide()

func back_out_to_cpu_menu():
	menu_position = 0
	current_game_state = State.HumanCpuConfig

	#swap the menus
	press_a_area.hide()
	comp_choices_menu.show()

	#show the arrows
	var parent = menu_labels_by_position[menu_position].get_parent()
	if parent.has_node('LeftArrow'):
		parent.get_node('LeftArrow').show()
		parent.get_node('RightArrow').show()
		menu_labels_by_position[RETURN_TO_TITLE_BUTTON_POS].release_focus()
		menu_labels_by_position[START_GAME].release_focus()

	_ready()

func back_out():
	backout_of_config.emit()

#called when "START!" is pressed
func finish_cpu_config():
	final_player_count = menu_value_by_position[HUMAN_PLAYER_POSITION]
	final_cpu_count = menu_value_by_position[CPU_PLAYER_POSITION]
	final_cpu_difficult = menu_value_by_position[CPU_DIFFICULTY_POSITION]

	#save these as defaults
	JeopardySaveData.default_player_amts = final_player_count
	JeopardySaveData.default_comp_amts = final_cpu_count
	JeopardySaveData.default_comp_diff = final_cpu_difficult
	JeopardySaveData.save_to_file()

	#hide all the shit
	press_a_area.show()
	comp_choices_menu.hide()

	#then change the state
	current_game_state = State.ControllerMapping

func start_controller_config():
	pass


#TODO: all of this lol
func set_controller_config(cont_id: int, is_keyboard = false):
	current_controller_state = ControllerConfigureState.ANIMATING
	JeopardyGlobals.set_player_id_and_guid(current_controller_configuring, cont_id, is_keyboard)
	JeopardyGlobals.money_by_player[current_controller_configuring] = 0

	already_used_controllers.append('%d_%s' % [cont_id, is_keyboard])
	current_controller_configuring += 1

	#if we have all the controllers configured, then leave
	if current_controller_configuring >= final_player_count:
		all_players_configured()
		return
				
	controller_config_prompt.text = 'Player %d, Press A/Space On Your Controller!' % (current_controller_configuring + 1)
	current_controller_state = ControllerConfigureState.WAITING_FOR_A


#fires when all human players buzzed in
func all_players_configured():
	#basically do all the stuff for the computers
	for i in range(final_player_count, final_cpu_count + final_player_count):
		JeopardyGlobals.set_cpu_id_and_guid(i)
		print(i)

	all_controllers_configured.emit()
	pass
