extends Node

const DEBUG_ACHIEVE = preload("uid://d25muavc7owga")


enum Achievements {
	true_double_up, # NEEDS TESTING
	lost_it_all, # NEEDS TESTING
	ill_take_it_from_here, # NEEDS TESTING
	i_hate_bossa_nova, # NEEDS TESTING
	star_guesser, # NEEDS TESTING
	go_back_to_school, # NEEDS TESTING
	started_from_the_bottom, # NEEDS TESTING
	go_big_or_go_home, # NEEDS TESTING
	i_can_finally_buy_a_house, # NEEDS TESTING
	the_more_the_merrier, # NEEDS TESTING
	dj, # DONE
	played_10_games, # NEEDS TESTING
}

enum Statistics {
	money_gained_in_totality,
	games_played
}


var achievements: Dictionary[String, bool] = {
	"true_double_up": false, # player at one point bet everything on a daily double (they had at least $10,000)
	"lost_it_all": false, # player at one point bet everything on a daily double (they had at least $10,000) and also lost it
	"ill_take_it_from_here": false, # player at one point actually imported their own question set
	"i_hate_bossa_nova": false, # player turned the music down to 0 and saved
	"star_guesser": false, # players got every single answer right in a single round
	"go_back_to_school": false, # players get to the final davening and nobody has any money to bet
	"started_from_the_bottom": false, # a player at one point had negative money, and ended up winning the game
	"go_big_or_go_home": false, # player bets everything on the final jeopardy, even when they are in first
	"i_can_finally_buy_a_house": false, # total money earned over all games crosses $1,000,000
	"the_more_the_merrier": false, # complete a full game with 3 people
	"dj": false, # play your own custom music
	"played_10_games": false # played 10 games in totality
}

var statistics: Dictionary[String, int] = {
	"money_gained_in_totality": 0,
	"games_played": 0,
}

var STEAM_CONNECTED_SUCCESFULLY = false

func _ready() -> void:
	initiailize_steam()


#initialize the steam connection
func initiailize_steam():
	var initialize_response: Dictionary = Steam.steamInitEx()
	print_debug("Tried to initialize steam connection. Results: %s." % initialize_response)
	
	#if it failed, then just bounce
	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print_debug("Failed to initialize Steam: %s." % initialize_response['status'])
		return

	STEAM_CONNECTED_SUCCESFULLY = true
	load_steam_stats()
	load_steam_achievements()

#attempts to load the steam stats into our stats dict
func load_steam_stats() -> void:
	for this_stat in statistics.keys():
		var stat_value: int = Steam.getStatInt(this_stat)
		print_debug("Retrieved %s stat: %s." % [this_stat, stat_value])
		statistics[this_stat] = stat_value

	print_debug("Loaded the steam stats.")

#attempts to load the steam achievements
func load_steam_achievements() -> void:
	for this_achievement in achievements.keys():
		print(this_achievement)
		var steam_achievement = Steam.getAchievement(this_achievement)
		print(steam_achievement)
		#check if the achievement is even in the backend
		if not steam_achievement['ret']:
			print_debug("Steam does not have this achievement %s, ignoring it." % this_achievement)
			continue

		achievements[this_achievement] = steam_achievement['achieved']

	print_debug("Loaded the steam achievements.")


func set_statistic(stat_enum: Statistics, add_val: int = 1) -> void:
	var this_stat = Statistics.keys()[stat_enum]
	if not statistics.has(this_stat):
		print_debug("This statistic does not exist locally: %s." % this_stat)
		return

	#save the stat locally
	statistics[this_stat] += add_val

	#save the steam version of the stat
	if not Steam.setStatInt(this_stat, statistics[this_stat]):
		print_debug("Failed to set stat %s to: %s" % [this_stat, add_val])
		return

	print_debug("Set statistics %s succesfully: %s." % [this_stat, add_val])
	store_steam_data()

#set an achievement was completed
func set_achievement_achieved(this_achievement: Achievements) -> void:
	#change the enum to a string
	var set_achieve: String = Achievements.keys()[this_achievement]
	if not achievements.has(set_achieve):
		print("This achievement does not exist locally: %s" % set_achieve)
		return

	if JeopardyGlobals.ACHIEVEMENT_DEBUGGING:
		var temp = DEBUG_ACHIEVE.instantiate()
		temp.display_text = "Achievement would have been unlocked: %s" % set_achieve
		get_node('/root/MainScene').add_child(temp)

	#set the achievement locally
	achievements[set_achieve] = true

	if not Steam.setAchievement(set_achieve):
		print("Failed to set achievement: %s" % set_achieve)
		return

	print("Set acheivement: %s" % set_achieve)
	store_steam_data()


#save the steam data up
func store_steam_data() -> void:
	if not Steam.storeStats():
		print("Failed to store data on Steam, should be stored locally")
		return
	print("Data successfully sent to Steam")
