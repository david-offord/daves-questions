extends Sprite2D

signal all_controllers_configured

var MAX_NUMBER_OF_CONTROLLERS = 3

#state management
enum ControllerConfigureState {WAITING_FOR_A, ANIMATING, COMPLETE}
var current_state = ControllerConfigureState.WAITING_FOR_A

var already_used_controllers = []
var current_controller_configuring = 0
var can_complete = false

func _ready() -> void:
	#reset the number of players
	JeopardyGlobals.number_of_players = 0

	JeopardyGlobals.CURRENT_GAME_STATE = JeopardyGlobals.GameState.CONTROLLER_CONFIGURATION
	$TextContainer/PlayerPressPrompt.text = 'Player 1, Press A On Your Controller!'
	$TextContainer/PlayerPressPrompt.show()


func _input(event: InputEvent) -> void:
	#bail if we are not even in the controller config screen
	if JeopardyGlobals.CURRENT_GAME_STATE != JeopardyGlobals.GameState.CONTROLLER_CONFIGURATION:
		return
	
	#if they should be able to move
	if current_state != ControllerConfigureState.WAITING_FOR_A:
		return
	
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
			current_state = ControllerConfigureState.COMPLETE
			all_controllers_configured.emit()


func set_controller_config(cont_id: int, is_keyboard = false):
	current_state = ControllerConfigureState.ANIMATING
	JeopardyGlobals.set_player_id_and_guid(current_controller_configuring, cont_id, is_keyboard)
	JeopardyGlobals.money_by_player[current_controller_configuring] = 0

	already_used_controllers.append('%d_%s' % [cont_id, is_keyboard])
	current_controller_configuring += 1

	#if we have all the controllers configured, then leave
	if current_controller_configuring >= MAX_NUMBER_OF_CONTROLLERS:
		all_controllers_configured.emit()
		return
				
	if current_controller_configuring == 3:
		$TextContainer/PlayerPressPrompt.text = 'Press B at any time to end configuration!'
	else:
		$TextContainer/PlayerPressPrompt.text = 'Player %d, Press A On Your Controller!' % (current_controller_configuring + 1)
	current_state = ControllerConfigureState.WAITING_FOR_A

	#if we have more than 2 players, they can stop now
	if current_controller_configuring > 1:
		$TextContainer/PressBToStop.show()
		can_complete = true
