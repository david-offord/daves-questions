extends Control

var file_playing = ''

func keep_alphanumeric(input_string: String) -> String:
    var regex := RegEx.new()
    regex.compile("[^a-zA-Z0-9 ]")
    var result = regex.sub(input_string, "", true)
    return result

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    #wait 3 seconds
    await get_tree().create_timer(1).timeout
    var metadata = MusicMeta.get_mp3_metadata(SoundController.AUDIO_PLAYER_MU.stream)

    $NowPlaying.text = 'Now Playing:
%s - %s' % [keep_alphanumeric(metadata.title) if (metadata.title != null and metadata.title != '') else "Unknown Song", keep_alphanumeric(metadata.artist) if (metadata.artist != null and metadata.artist != '') else "Unknown Artist"]

    start_wait_and_fade()


func start_wait_and_fade() -> void:
    #show yourself
    var fade_tween = get_tree().create_tween()
    fade_tween.tween_property(self ,
        'modulate:a',
        1.0,
        1.0)

    await fade_tween.finished
    

    #wait 3 seconds
    await get_tree().create_timer(3).timeout


    #fade out
    fade_tween = get_tree().create_tween()
    fade_tween.tween_property(self ,
        'modulate:a',
        0,
        3)

    await fade_tween.finished
    
    queue_free()