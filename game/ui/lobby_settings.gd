class_name LobbySettings
extends RefCounted
## Login choices kept between launches, so a phone reconnects with one tap.

const PATH := "user://settings.cfg"
const SECTION := "login"
const DEFAULT_ADDRESS := "127.0.0.1"
const MAX_RECENT := 3

var player_name: String = Game.DEFAULT_NAME
var address: String = DEFAULT_ADDRESS
var recent: PackedStringArray = PackedStringArray()
var choice: String = ""


func load_file() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	player_name = Game.clean_name(str(config.get_value(SECTION, "name", Game.DEFAULT_NAME)))
	address = str(config.get_value(SECTION, "address", DEFAULT_ADDRESS))
	choice = str(config.get_value(SECTION, "choice", ""))
	var stored: Variant = config.get_value(SECTION, "recent", PackedStringArray())
	if stored is PackedStringArray:
		recent = stored


func remember_address(new_address: String) -> void:
	address = new_address
	var index := recent.find(new_address)
	if index != -1:
		recent.remove_at(index)
	recent.insert(0, new_address)
	recent.resize(mini(recent.size(), MAX_RECENT))


func save_file() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "name", player_name)
	config.set_value(SECTION, "address", address)
	config.set_value(SECTION, "recent", recent)
	config.set_value(SECTION, "choice", choice)
	config.save(PATH)
