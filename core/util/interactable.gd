class_name Interactable
extends Node3D
## A station the team body can use when within range.

## The host allows this much extra distance because positions arrive slightly late.
const HOST_RANGE_SLACK := 1.0

var kind: String = ""
var interact_range: float = 0.0


func in_range(point: Vector3, slack: float = 0.0) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= interact_range + slack


## Called on the interacting player's own client.
func interact(_player: PlayerBase) -> void:
	pass


## Called on the interacting player's own client when the button is let go.
func release(_player: PlayerBase) -> void:
	pass


## Host check: the station exists, has this kind, and the team body stands within range.
static func near_team_body(station_id: String, station_kind: String) -> Interactable:
	if Game.world == null:
		return null
	var station := Game.world.get_node_or_null("Entities/%s" % station_id) as Interactable
	var body := Game.team_body()
	if station == null or station.kind != station_kind or body == null:
		return null
	return station if station.in_range(body.global_position, HOST_RANGE_SLACK) else null


static func any_near_team_body(station_kind: String) -> bool:
	if Game.world == null:
		return false
	for node: Node in Game.world.get_node("Entities").get_children():
		if node is Interactable and near_team_body(String(node.name), station_kind) != null:
			return true
	return false
