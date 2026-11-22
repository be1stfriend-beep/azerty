class_name Imad
extends PlayerBase


func _init() -> void:
	name = "imad"
	character = Characters.Character.IMAD


func _ready() -> void:
	move_speed = Data.balance("imad_crawl")
	super._ready()


func _build_rig() -> CharacterBuilder:
	return CharacterBuilder.build_imad()


func _collider_radius() -> float:
	return 0.45


func _collider_height() -> float:
	return 1.2
