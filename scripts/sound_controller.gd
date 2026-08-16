extends Node

#players
var AUDIO_PLAYER_MU: AudioStreamPlayer = null
var AUDIO_PLAYER_SE_SPAWN_OBJ: Node = null

#prefabs
var NOW_PLAYING_POPUP = preload("res://scenes/now_playing_box.tscn")

var current_now_playing_box = null

#all enums
enum SoundEffects {
	MenuMove,
	MenuSelection,
	WrongAnswer,
	RightAnswer,
	TimeRanOut,
	BetLockIn,
	WinningSound,
	BuzzerAppears,
	BuzzedIn
}
enum SpecificMusic {
	MainMenu
}

#sound effect enum to the actual file
var SOUND_EFFECT_TO_FILE = {
	SoundEffects.MenuMove: 'menu_move.wav',
	SoundEffects.MenuSelection: 'click_standard.wav',
	SoundEffects.WrongAnswer: 'wrong_answer_1.wav',
	SoundEffects.RightAnswer: 'correct_answer_1.wav',
	SoundEffects.TimeRanOut: 'time_ran_out.wav',
	SoundEffects.BetLockIn: 'value_lock_in.wav',
	SoundEffects.WinningSound: 'winning_sound.wav',
	SoundEffects.BuzzerAppears: 'buzzer_appears.wav',
	SoundEffects.BuzzedIn: 'buzzed_in.wav'
}

#these load when the game starts
var se_to_load_on_start: Array[SoundEffects] = [
	SoundEffects.MenuMove,
	SoundEffects.MenuSelection,
	SoundEffects.WrongAnswer,
	SoundEffects.RightAnswer,
	SoundEffects.TimeRanOut,
	SoundEffects.BuzzerAppears,
	SoundEffects.BuzzedIn,
]

#specific music track to file
var SPECIFIC_MUSIC_TO_FILE: Dictionary[SpecificMusic, String] = {
	SpecificMusic.MainMenu: 'til_dawn.mp3'
}

var loaded_sound_effects: Dictionary[SoundEffects, AudioStreamWAV] = {

}


var sound_effect_default_folder: String = 'sound/effects/'
var specific_music_default_folder: String = 'sound/specific_music/'
var music_default_folder: String = 'sound/music/'
var music_custom_folder: String = 'user://custom_music/'

#iteration of the track we are on
var track_iter = 0
#the next track (so we dont have to load on fly)
var current_track_name: String = ''
var next_track: AudioStreamMP3 = null
var next_track_path: String = ''
#all file paths of music
var all_music_track_options = []


func _ready() -> void:
	#load all the files names for the music
	var music_folder := DirAccess.get_files_at("res://" + music_default_folder)

	print_debug('CONTENTS OF CD: %s.' % DirAccess.get_files_at("res://" + music_default_folder));


	for item in music_folder:
		#this import trash is because godot for some reason cant handle loading these dynamically... whatever dude
		if item.ends_with('.mp3') or item.ends_with('.mp3.import'):
			item = item.replace('.import', '')
			all_music_track_options.append('res://' + music_default_folder + item)

	if DirAccess.dir_exists_absolute(music_custom_folder) == false:
		DirAccess.make_dir_absolute(music_custom_folder)

	#load all the custom tracks (only if there are any)
	if DirAccess.dir_exists_absolute(music_custom_folder):
		music_folder = DirAccess.get_files_at(music_custom_folder)
		for item in music_folder:
			if item.ends_with('.mp3'):
				all_music_track_options.append(music_custom_folder + item)

	#randomize the tracks
	all_music_track_options.shuffle()


	#load all the default sound effects
	load_sound_effects(se_to_load_on_start)

	#get the music player
	AUDIO_PLAYER_MU = get_node('/root/MainScene/AudioPlayerME')

	#get the sound effect player
	AUDIO_PLAYER_SE_SPAWN_OBJ = get_node('/root/MainScene/SoundEffectsContainer')

func _input(event: InputEvent) -> void:
	if JeopardyGlobals.MINOR_DEBUG_MODE:
		if event.is_action_pressed("debug_next song"):
			_music_finished_naturally()


func play_music() -> void:
	var sound: AudioStreamMP3 = null

	#if the track was not load it just in time
	if next_track == null:
		_load_next_track()
		track_iter = wrapi(track_iter + 1, 0, len(all_music_track_options))
		current_track_name = all_music_track_options[track_iter]

	print_debug('About to start playing %s.' % current_track_name)
	sound = next_track

	AUDIO_PLAYER_MU.stream = sound
	
	#adjust the sound level
	adjust_volume_of_me(JeopardySaveData.me_volume)
	
	AUDIO_PLAYER_MU.play()
	show_now_playing_box()

	#its playing a custom song they provided, give em the achievement
	if music_custom_folder in next_track_path:
		SteamController.set_achievement_achieved(SteamController.Achievements.dj)

	AUDIO_PLAYER_MU.finished.connect(_music_finished_naturally)

	_load_next_track()

func stop_music() -> void:
	AUDIO_PLAYER_MU.stop()
	
func resume_music() -> void:
	AUDIO_PLAYER_MU.play()
	

func play_specific_music(song: SpecificMusic) -> void:
	#load the file and then save it to the next track
	var sound = ResourceLoader.load(specific_music_default_folder + SPECIFIC_MUSIC_TO_FILE[song], "AudioStreamMP3") as AudioStreamMP3
	AUDIO_PLAYER_MU.stream = sound

	#adjust the sound level
	adjust_volume_of_me(JeopardySaveData.me_volume)

	AUDIO_PLAYER_MU.play()
	show_now_playing_box()
	next_track = null

func _load_next_track():
	var load_iter = track_iter + 1
	load_iter = wrapi(load_iter, 0, len(all_music_track_options))
	
	print_debug("Loading song %s" % all_music_track_options[load_iter])
	#load the file and then save it to the next track
	var file = ResourceLoader.load(all_music_track_options[load_iter], "AudioStreamMP3") as AudioStreamMP3

	var sound := AudioStreamMP3.new()
	sound.data = file.data
	next_track = sound
	next_track_path = all_music_track_options[load_iter]

func _music_finished_naturally():
	print_debug('Finished track %s.' % current_track_name)
	track_iter += 1
	#add modulous here
	track_iter = track_iter % len(all_music_track_options)
	current_track_name = all_music_track_options[track_iter]

	play_music()

#loads a list of sound effects for use later
func load_sound_effects(effects: Array[SoundEffects]):
	for effect in effects:
		#if the sound effect already exists and is loaded
		if effect in loaded_sound_effects and loaded_sound_effects[effect] != null:
			continue

		var path: String = "res://" + sound_effect_default_folder + SOUND_EFFECT_TO_FILE[effect]
		if ResourceLoader.exists(path) == false:
			printerr("A sound effect was attempted to be loaded, but didnt exist. Path: %s" % path)
			continue


		#load sound effect file
		
		var sound = ResourceLoader.load(path, "AudioStreamWAV") as AudioStreamWAV
		#var sound := AudioStreamWAV.load_from_file(path)

		#store it for later
		loaded_sound_effects[effect] = sound
		print_debug("Loaded sound effect %s" % path)

#unloads all sound effects
func unload_all_sound_effects():
	#delete the references
	loaded_sound_effects = {}
	#kill all current sound effects
	for child in AUDIO_PLAYER_SE_SPAWN_OBJ.get_children():
		child.queue_free()

#attempts to play a sound effect. if it was not loaded previously, it loads it on the fly
func play_sound_effect(effect: SoundEffects):
	#if it still needs to be loaded
	if effect not in loaded_sound_effects:
		load_sound_effects([effect])

	#the load failed, so the sound probably does not exist - move on
	if effect not in loaded_sound_effects:
		return

	#create an audio player, then play it
	var temp_player = AudioStreamPlayer.new()
	temp_player.mix_target = AudioStreamPlayer.MIX_TARGET_CENTER
	AUDIO_PLAYER_SE_SPAWN_OBJ.add_child(temp_player)
	temp_player.stream = loaded_sound_effects[effect]

	var mod: float = (100 - JeopardySaveData.se_volume) * .2

	temp_player.volume_db = 0 - mod

	temp_player.play()
	#make it kill itself once its finished
	temp_player.finished.connect(temp_player.queue_free)

func adjust_volume_of_me(level):
	#get vlume from options
	var mod: float = (100 - level) * .1
	AUDIO_PLAYER_MU.volume_db = -9.0 - mod
	if level == 0:
		AUDIO_PLAYER_MU.volume_db = -10000 # lol

func show_now_playing_box():
	hide_now_playing_box()
	
	current_now_playing_box = NOW_PLAYING_POPUP.instantiate()
	get_node('/root/MainScene/AudioPlayerME').add_child(current_now_playing_box)

func hide_now_playing_box():
	if current_now_playing_box != null:
		current_now_playing_box.queue_free()
