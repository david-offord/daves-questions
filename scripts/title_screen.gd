extends Node

signal started_game

@export var settings_scene: PackedScene = null
@export var credits_scroll: PackedScene = null


var instantiated_settings_scene = null
var instantiated_credits_scroll = null

@onready var help_screen: HelpTextController = $HelpTextControl
var currently_in_controller_config = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	JeopardyGlobals.CURRENT_GAME_STATE = JeopardyGlobals.GameState.MAIN_MENU
	$MainMenuButtons/StartGame.grab_focus()
	SoundController.play_specific_music(SoundController.SpecificMusic.MainMenu)

	call_deferred('grab_focus')

	help_screen.backed_out.connect(backout_of_controls)

	#if JeopardyGlobals.MINOR_DEBUG_MODE:
	#	SteamController.set_achievement_achieved(SteamController.Achievements.dj)
	

func grab_focus():
	$MainMenuButtons/StartGame.grab_focus()

func _on_start_game_pressed() -> void:
	SoundController.play_sound_effect(SoundController.SoundEffects.MenuAccept)
	started_game.emit()


func _on_configure_pressed() -> void:
	SoundController.hide_now_playing_box()
	var new_scene = settings_scene.instantiate()
	new_scene.exited_settings.connect(return_from_settings)

	print_debug('Adding setting area to scene.');
	$TitleScreenImage.hide()
	$MainMenuButtons.hide()
	add_child(new_scene)
	instantiated_settings_scene = new_scene
	

func return_from_settings():
	$MainMenuButtons/Configure.grab_focus()
	if instantiated_settings_scene != null:
		instantiated_settings_scene.queue_free()

	$TitleScreenImage.show()
	$MainMenuButtons.show()
	call_deferred('focus_configure')
	
	SoundController.play_sound_effect(SoundController.SoundEffects.MenuAccept)

	#save the options
	JeopardySaveData.save_to_file()

func focus_configure():
	$MainMenuButtons/Configure.grab_focus()


func _on_credits_pressed() -> void:
	var new_scene = credits_scroll.instantiate()
	new_scene.exited_scroll.connect(return_from_credits)

	print_debug('Adding credits area to scene.');
	
	$TitleScreenImage.hide()
	$MainMenuButtons.hide()
	for butt: Button in $MainMenuButtons.get_children():
		print(butt.name)
		butt.disabled = true

	add_child(new_scene)
	instantiated_credits_scroll = new_scene

func return_from_credits():
	$MainMenuButtons/Credits.grab_focus()
	if instantiated_credits_scroll != null:
		instantiated_credits_scroll.queue_free()

	$TitleScreenImage.show()
	$MainMenuButtons.show()
	
	call_deferred("reenable_buttons")
	
func reenable_buttons():
	for butt: Button in $MainMenuButtons.get_children():
		butt.disabled = false

func show_controls():
	for butt: Button in $MainMenuButtons.get_children():
		butt.disabled = true
	
	help_screen.show_help()


func _on_quit_pressed() -> void:
	get_tree().quit(0)


func _on_controls_pressed() -> void:
	currently_in_controller_config = true
	$MainMenuButtons/Controls.release_focus()
	show_controls()

func backout_of_controls():
	currently_in_controller_config = false
	$MainMenuButtons/Controls.grab_focus()
	reenable_buttons()
