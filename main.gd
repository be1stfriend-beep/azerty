extends Node


func _ready() -> void:
	if not Data.is_loaded:
		await Data.data_loaded
	print("Data loaded")
