extends Node

@export var silentwolf_api_key: String = "k1AQz8xJZI1cGIjZqgGiT5NiIBZUR7eP1p9XtNIP"
@export var silentwolf_game_id: String = "mathgodot"
@export var leaderboard_name: String = "main"

func _ready() -> void:
	var silentwolf := get_node_or_null("/root/SilentWolf")
	if silentwolf == null:
		return
	if silentwolf_api_key.is_empty() or silentwolf_game_id.is_empty():
		return

	silentwolf.call("configure", {
		"api_key": silentwolf_api_key,
		"game_id": silentwolf_game_id,
		"log_level": 1,
	})


func silentwolf_ready() -> bool:
	return not silentwolf_api_key.is_empty() and not silentwolf_game_id.is_empty() and has_node("/root/SilentWolf")
