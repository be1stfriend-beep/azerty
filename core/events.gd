extends Node

signal state_changed
signal air_changed(value: float)
signal mount_changed(state: String)
signal trash_picked(id: String)
signal item_crafted(id: String)
signal material_produced(material: String, world_position: Vector3)
signal tower_activated(index: int)
signal boss_state_changed(state: String)
signal dialogue_requested(id: String)
signal context_changed
