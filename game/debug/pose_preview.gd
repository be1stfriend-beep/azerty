class_name PosePreview
extends Node
## --pose moving|merged in the dev level: drives the static rigs so a screenshot can show
## the run, the crawl and the ride pose without a network match.

const MOVING := "moving"
const MERGED := "merged"

var _bjorn: CharacterBuilder
var _imad: CrawlRig
var _pose: String


func _init(bjorn: CharacterBuilder, imad: CrawlRig, pose: String) -> void:
	_bjorn = bjorn
	_imad = imad
	_pose = pose


func _ready() -> void:
	if _pose == MOVING:
		# Side-on to the camera so the swing and the crawl read in profile.
		_bjorn.rotation.y = PI * 0.5
		_imad.rotation.y = PI * 0.5
	_imad.riding = _pose == MERGED


func _process(delta: float) -> void:
	var bjorn_velocity := Vector3.ZERO
	var imad_velocity := Vector3.ZERO
	if _pose == MOVING:
		bjorn_velocity = Vector3(float(Data.balance("bjorn_walk")), 0, 0)
		imad_velocity = Vector3(float(Data.balance("imad_crawl")), 0, 0)
	_bjorn.update_wobble(delta, bjorn_velocity, true)
	if _pose == MERGED:
		var saddle := _bjorn.body.get_node("Saddle") as Node3D
		_imad.global_position = saddle.global_position + Imad.SEAT_OFFSET
		_imad.rotation.y = _bjorn.rotation.y
	_imad.update_wobble(delta, imad_velocity, true)
