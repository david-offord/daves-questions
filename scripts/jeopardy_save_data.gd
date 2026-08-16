extends Node

#option values
var jeopardy_set = 'MDFD Questions'
var jeopardy_set_custom_location = ''
var time_modifier = '1x'
var se_volume = 100
var me_volume = 100

#so categories dont repeat
var categories_seen = []

#below are currently unused
var total_money_earned = 0
var total_money_lost = 0
var total_buzzes = 0

var custom_announcer = false

var SAVE_FILE_LOCATION = "user://jeopardy_save.dat"

func add_to_categories_seen(category_id: int):
	if category_id in categories_seen:
		return
	categories_seen.append(category_id)


func save_to_file():
	var file := FileAccess.open(SAVE_FILE_LOCATION, FileAccess.WRITE)

	#save the categories that have already been used
	var cat_seen_str = ','.join(categories_seen)
	file.store_pascal_string(cat_seen_str)

	file.store_pascal_string(jeopardy_set)
	file.store_pascal_string(time_modifier)
	file.store_16(se_volume)
	file.store_16(me_volume)
	file.store_pascal_string(jeopardy_set_custom_location)
	file.store_8(custom_announcer)

func load_from_file():
	var file := FileAccess.open(SAVE_FILE_LOCATION, FileAccess.READ)

	if file == null:
		return
	
	#save the categories that have already been used
	var cat_seen_str = file.get_pascal_string()
	categories_seen = Array(cat_seen_str.split(','))

	jeopardy_set = file.get_pascal_string()
	time_modifier = file.get_pascal_string()
	se_volume = file.get_16()
	me_volume = file.get_16()
	jeopardy_set_custom_location = file.get_pascal_string()
	custom_announcer = file.get_8()

	print(jeopardy_set_custom_location)