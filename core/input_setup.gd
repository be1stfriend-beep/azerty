class_name InputSetup

const KEYS: Dictionary = {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"move_up": KEY_W,
	"move_down": KEY_S,
	"aim_left": KEY_LEFT,
	"aim_right": KEY_RIGHT,
	"aim_up": KEY_UP,
	"aim_down": KEY_DOWN,
	"jump": KEY_SPACE,
	"kick": KEY_J,
	"interact": KEY_E,
	"use_tool": KEY_F,
	"tool_next": KEY_R,
	"mount": KEY_M,
	"dismount": KEY_N,
}


static func register() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		# Physical keys keep WASD in the same place on AZERTY and other layouts.
		event.physical_keycode = KEYS[action]
		InputMap.action_add_event(action, event)
