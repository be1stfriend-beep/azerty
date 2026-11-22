extends Node

signal data_loaded

const DATA_DIR := "res://data/"
const LEVELS_DIR := "res://data/levels/"

var is_loaded: bool = false

var _tables: Dictionary = {}
var _levels: Dictionary = {}


func _ready() -> void:
	_tables = _load_dir(DATA_DIR)
	_levels = _load_dir(LEVELS_DIR)
	is_loaded = true
	data_loaded.emit()


func config() -> Dictionary:
	return _table("config")


func item(id: String) -> Dictionary:
	return _entry("items", id)


func recipe(id: String) -> Dictionary:
	return _entry("recipes", id)


func prefab(id: String) -> Dictionary:
	return _entry("prefabs", id)


func entity(kind: String) -> Dictionary:
	return _entry("entities", kind)


func items() -> Dictionary:
	return _table("items")


func recipes() -> Dictionary:
	return _table("recipes")


func balance(key: String) -> Variant:
	var table := _table("balance")
	if not table.has(key):
		push_error("Data: missing balance key '%s'" % key)
		assert(false, "missing balance key " + key)
		return null
	return table[key]


func dialogue(id: String) -> Array:
	var table := _table("dialogue")
	if not table.has(id):
		push_error("Data: missing dialogue '%s'" % id)
		return []
	return table[id]


func level(level_name: String) -> Dictionary:
	if not _levels.has(level_name):
		push_error("Data: missing level '%s'" % level_name)
		return {}
	return _levels[level_name]


func _table(table_name: String) -> Dictionary:
	if not _tables.has(table_name):
		push_error("Data: missing table '%s'" % table_name)
		return {}
	return _tables[table_name]


func _entry(table_name: String, id: String) -> Dictionary:
	var table := _table(table_name)
	if not table.has(id):
		push_error("Data: missing id '%s' in %s" % [id, table_name])
		return {}
	return table[id]


func _load_dir(path: String) -> Dictionary:
	var result: Dictionary = {}
	for file_name in DirAccess.get_files_at(path):
		# Exported builds may list remapped names; only plain .json is data.
		if file_name.get_extension() != "json":
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + file_name))
		if parsed is Dictionary:
			result[file_name.get_basename()] = parsed
		else:
			push_error("Data: could not parse %s%s" % [path, file_name])
	return result
