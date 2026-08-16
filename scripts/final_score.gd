extends Node2D

signal start_new_game
signal return_to_title
signal quit_game

var players_info = {}

var participating_final_jeopardy_players := []
var last_bet_by_player := {}
var last_question = null
var last_answers_by_player := {}
var nobody_could_play := false

var buttons_selectable = false
var current_button_pos = 0
var samp: Button
var buttons_order = {
}

func initialize(final_jeopardy_allowed_players, final_bet_by_player, final_jeopardy_question, final_answer_by_player, everyone_sub_zero = false):
	participating_final_jeopardy_players = final_jeopardy_allowed_players
	last_bet_by_player = final_bet_by_player
	last_question = final_jeopardy_question
	last_answers_by_player = final_answer_by_player
	nobody_could_play = everyone_sub_zero

#start up all the timers 
func _ready() -> void:
	begin_final_score_show()
	buttons_order = {
		0: $ButtonsMenu/NewGame,
		1: $ButtonsMenu/ReturnToTitle,
		2: $ButtonsMenu/QuitGame,
	}

func begin_final_score_show():
	if nobody_could_play == false:
		$FinaleAnnouncer.show_text_bubble("Alright, let's see the guesses and final score!", 4)
		await $FinaleAnnouncer.text_bubble_hidden

	#nobody participated - this is like catastrophic levels of stupidity
	if len(participating_final_jeopardy_players) == 0:
		pass
	#if only 1 person participated, idk how this can even happen just like above
	elif len(participating_final_jeopardy_players) == 1:
		$FinaleAnnouncer.show_text_bubble("Looks like only 1 person participated... Yikes!", 3)
		await $FinaleAnnouncer.text_bubble_hidden

	
	for player in participating_final_jeopardy_players:
		$FinaleAnnouncer.show_text_bubble("Player %d answered..." % (player + 1), 2)
		await $FinaleAnnouncer.text_bubble_hidden
		await get_tree().create_timer(1).timeout


		#if they didnt answer for some reason
		if last_answers_by_player[player]['failed_to_answer'] == true:
			#make fun of them
			$FinaleAnnouncer.show_text_bubble("Oh my, it seems like they didn't answer! How utterly foolish.", 5)
			await $FinaleAnnouncer.text_bubble_hidden
			#show the money loss
			await show_money_gain_loss(last_bet_by_player[player], false)
			await get_tree().create_timer(3).timeout
			#hide the money loss
			$FinalAnswerShowing/AnswerBox.hide()
			hide_money_gain_loss()
			JeopardyGlobals.change_player_money(player, -1 * last_bet_by_player[player])
			continue

		#show the answer in the box, and sleep a minute
		await show_answer_box_with_text(last_answers_by_player[player]['text'])
		await get_tree().create_timer(1).timeout

		#check if they were correct
		var was_correct = last_answers_by_player[player]['correct']
		#show the announcement saying if they were correct
		$FinaleAnnouncer.show_text_bubble("And that was %s!" % ('correct' if was_correct else 'incorrect'), 2)
		await $FinaleAnnouncer.text_bubble_hidden

		#TODO: THIS crashes lol, saying player 0 does not have a bet in "last_bet_by_player"
		assert(player in last_bet_by_player, 'Player %d should have an entry in last_bet_by_player, yet does not.' % player)
		if player not in last_bet_by_player:
			last_bet_by_player[player] = 0

		JeopardyGlobals.change_player_money(player, (1 if was_correct else -1) * last_bet_by_player[player])

		#then, show the money decrease/increase
		await show_money_gain_loss(last_bet_by_player[player], was_correct)
		await get_tree().create_timer(3).timeout

		$FinalAnswerShowing/AnswerBox.hide()
		hide_money_gain_loss()

	
	if nobody_could_play:
		$FinaleAnnouncer.show_text_bubble("Since you're all such immense crapouts, let's see who's the king of the fools!", 2)
	else:
		$FinaleAnnouncer.show_text_bubble("And now, let's see the final scores!", 2)
	await $FinaleAnnouncer.text_bubble_hidden

	var fade_in_interval = 2.0

	#write all the player's money to their windows
	for player in JeopardyGlobals.money_by_player:
		var score_parent: Sprite2D = get_node("RankingBoard/Player%dScore" % (player + 1))
		get_node("RankingBoard/Player%dScore/Score" % (player + 1)).text = ('' if JeopardyGlobals.money_by_player[player] >= 0 else '-') + JeopardyGlobals.format_currency(JeopardyGlobals.money_by_player[player])
		score_parent.show()
		score_parent.modulate.a = 0

		var fade_tween = get_tree().create_tween()
		fade_tween.tween_property(score_parent,
			'modulate:a',
			1,
			fade_in_interval)

	#wait for the tween to complete
	await get_tree().create_timer(fade_in_interval).timeout

	#now check if the order is 1,2,3
	var ranking = JeopardyGlobals.get_player_rankings()
	var already_in_order = true
	var i = 0
	for item in ranking:
		#basically is player 0 at pos 0, player 1 at 1, etc
		if item['player'] != i:
			already_in_order = false
			break

		i += 1
	
	var tie_status = 'none'
	if JeopardyGlobals.number_of_players == 3:
		if JeopardyGlobals.money_by_player[ranking[0]['player']] == JeopardyGlobals.money_by_player[ranking[1]['player']] and JeopardyGlobals.money_by_player[ranking[0]['player']] == JeopardyGlobals.money_by_player[ranking[2]['player']]:
			tie_status = 'all_players_tied'
		elif JeopardyGlobals.money_by_player[ranking[0]['player']] == JeopardyGlobals.money_by_player[ranking[1]['player']]:
			tie_status = '2way'

	if JeopardyGlobals.number_of_players == 3:
		if JeopardyGlobals.money_by_player[ranking[0]['player']] == JeopardyGlobals.money_by_player[ranking[1]['player']]:
			tie_status = 'all_players_tied'


	#basically we need to reorder the final scores
	if already_in_order == false and tie_status != 'all_players_tied':
		$FinaleAnnouncer.show_text_bubble("Let's go ahead and fix the order here...", 3)
		await $FinaleAnnouncer.text_bubble_hidden
		i = 0
		var move_timer = 0.75

		for rank in ranking:
			var player_node = get_node("RankingBoard/Player%dScore" % (rank['player'] + 1))
			var rank_marker: Marker2D = get_node("PlaceLocations/Place%dMarker" % (i + 1))

			var move_tween = get_tree().create_tween()
			move_tween.tween_property(player_node,
				'position',
				rank_marker.position,
				move_timer)

			i += 1
		#wait for the tween to finish
		await get_tree().create_timer(move_timer + .75).timeout
		$FinaleAnnouncer.show_text_bubble("That's better!", 2)
		await $FinaleAnnouncer.text_bubble_hidden

	
	#everyone was negative, and all players are not tied
	if nobody_could_play and tie_status != 'all_players_tied':
		$FinaleAnnouncer.show_text_bubble("Well you know what they say, in the land of the fools, the person with %s is king." % JeopardyGlobals.format_scoreboard_currency(JeopardyGlobals.money_by_player[ranking[0]['player']]), 6)
		await $FinaleAnnouncer.text_bubble_hidden
		$FinaleAnnouncer.show_text_bubble("Congratulations to Player %d!" % [(ranking[0]['player'] + 1)], 3)
	#everyone was negative, and all players were tied
	elif nobody_could_play and tie_status == 'all_players_tied':
		$FinaleAnnouncer.show_text_bubble('Great news, the %d of you are are equally terrible!' % JeopardyGlobals.number_of_players, 4)
		#await $FinaleAnnouncer.text_bubble_hidden

	#some people had positive, and everyone still tied
	if nobody_could_play == false and tie_status == 'all_players_tied':
		$FinaleAnnouncer.show_text_bubble("My goodness, it's a %d way tie! Great job everyone!" % JeopardyGlobals.number_of_players, 3)
	#people had positive, and there was a 2 way tie
	if nobody_could_play == false and tie_status == '2way':
		$FinaleAnnouncer.show_text_bubble("Congratulations to Player %d and Player %d!" % [(ranking[0]['player'] + 1), (ranking[1]['player'] + 1)], 3)
	#people had positive, and there was no tie
	if nobody_could_play == false and tie_status == 'none':
		$FinaleAnnouncer.show_text_bubble("Congratulations to Player %d!" % [(ranking[0]['player'] + 1)], 3)
	
	#if everyone was negative, give em the achievement
	if nobody_could_play:
		SteamController.set_achievement_achieved(SteamController.Achievements.go_back_to_school)

	#if there was no tie, the winner was negative at one point in the game, and their current money is > 0, give em the achievement
	if tie_status == 'none' and JeopardyGlobals.player_to_ever_negative[ranking[0]['player']] == true and JeopardyGlobals.money_by_player[ranking[0]['player']] > 0:
		SteamController.set_achievement_achieved(SteamController.Achievements.started_from_the_bottom)

	#they completed a game with 3 people, give em the achievement
	if JeopardyGlobals.number_of_players == 3:
		SteamController.set_achievement_achieved(SteamController.Achievements.the_more_the_merrier)

	#add to the number of games played
	SteamController.set_statistic(SteamController.Statistics.games_played, 1)

	SoundController.play_sound_effect(SoundController.SoundEffects.WinningSound)

	await $FinaleAnnouncer.text_bubble_hidden
	finish_up()

func finish_up():
	buttons_selectable = true
	$ButtonsMenu.show()
	$ButtonsMenu/NewGame.grab_focus()

func show_answer_box_with_text(text_for_box: String):
	#set the text
	$FinalAnswerShowing/AnswerBox/Answer.text = text_for_box
	$FinalAnswerShowing/AnswerBox.modulate.a = 0
	$FinalAnswerShowing/AnswerBox.show()

	var fade_tween = get_tree().create_tween()
	fade_tween.tween_property($FinalAnswerShowing/AnswerBox,
		'modulate:a',
		1,
		.75)

	return fade_tween.finished

func show_money_gain_loss(amount: int, correct = false):
	var label: Label = $FinalAnswerShowing/MoneyIncreaseText/MoneyIncreaseText
	
	if correct:
		label.text = '+%s' % JeopardyGlobals.format_currency(amount)
		label.add_theme_color_override('font_color', Color8(122, 255, 122))

	else:
		label.text = '-%s' % JeopardyGlobals.format_currency(amount)
		label.add_theme_color_override('font_color', Color8(255, 122, 122))

	label.show()

	label.scale = Vector2(0, 0)

	var fade_tween = get_tree().create_tween()
	fade_tween.tween_property(label,
		'scale',
		Vector2(1.25, 1.25),
		.25)
	await fade_tween.finished
	
	#play the buzz or kaling
	SoundController.play_sound_effect(SoundController.SoundEffects.WrongAnswer if correct == false else SoundController.SoundEffects.RightAnswer)

	fade_tween = get_tree().create_tween()
	fade_tween.tween_property(label,
		'scale',
		Vector2(1, 1),
		.1)
	return fade_tween.finished

func hide_money_gain_loss():
	$FinalAnswerShowing/MoneyIncreaseText/MoneyIncreaseText.hide()


func _input(event):
	var is_keyboard_input = event is InputEventKey or event is InputEventMouse
	var player_id = JeopardyGlobals.get_player_id_by_guid(event.device, is_keyboard_input)

	if player_id != 0:
		get_viewport().set_input_as_handled()
		return

	if buttons_selectable == false:
		return

	if event.is_action_pressed("move_cursor_left"):
		current_button_pos -= 1
		SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)

	if event.is_action_pressed("move_cursor_right"):
		current_button_pos += 1
		SoundController.play_sound_effect(SoundController.SoundEffects.MenuMove)
	if event.is_action_pressed("select"):
		SoundController.play_sound_effect(SoundController.SoundEffects.MenuSelection)
		press_button(current_button_pos)
		get_viewport().set_input_as_handled()
		return

	current_button_pos = wrapi(current_button_pos, 0, 3)
	buttons_order[current_button_pos].grab_focus()
	get_viewport().set_input_as_handled()

func press_button(button):
	buttons_selectable = false

	#start new game
	if button == 0:
		start_new_game.emit()
		
	#go to main menu
	if button == 1:
		return_to_title.emit()

	#quit game
	if button == 2:
		$FinaleAnnouncer.show_text_bubble("See you next time!", 2)
		await $FinaleAnnouncer.text_bubble_hidden
		quit_game.emit()
