class_name Palette

const HAZE_SKY := Color(0.851, 0.627, 0.400)
const DUST_GROUND := Color(0.710, 0.514, 0.310)
const RUST := Color(0.541, 0.294, 0.165)
const SOOT := Color(0.227, 0.200, 0.188)
const CONCRETE := Color(0.561, 0.529, 0.478)
const BONE := Color(0.953, 0.922, 0.867)
const RESTORED_GRASS := Color(0.545, 0.765, 0.290)
const RESTORED_SKY := Color(0.494, 0.784, 0.890)
const RESTORED_TEAL := Color(0.184, 0.639, 0.604)
const BJORN_PARKA := Color(0.208, 0.714, 0.839)
const BJORN_POMPOM := Color(0.847, 0.263, 0.180)
const IMAD_VEST := Color(0.169, 0.298, 0.608)
const IMAD_GOGGLES := Color(0.941, 0.541, 0.141)
const SKIN_A := Color(0.945, 0.827, 0.745)
const SKIN_B := Color(0.690, 0.478, 0.333)
const ROACH_SHELL := Color(0.227, 0.165, 0.247)
const DANGER := Color(0.898, 0.204, 0.165)

## Tint groups referenced by prefabs.json and the builders. Unknown groups fall back to CONCRETE.
const TINTS: Dictionary = {
	"plastic": RESTORED_SKY,
	"metal": BONE,
	"paper": IMAD_GOGGLES,
	"compost": RESTORED_GRASS,
	"wood": HAZE_SKY,
	"rust": RUST,
	"soot": SOOT,
	"concrete": CONCRETE,
	"bone": BONE,
	"teal": RESTORED_TEAL,
	"danger": DANGER,
	"bjorn_parka": BJORN_PARKA,
	"bjorn_pompom": BJORN_POMPOM,
	"imad_vest": IMAD_VEST,
	"imad_goggles": IMAD_GOGGLES,
	"skin_a": SKIN_A,
	"skin_b": SKIN_B,
	"roach_shell": ROACH_SHELL,
}


static func tint(group: String) -> Color:
	return TINTS.get(group, CONCRETE)
