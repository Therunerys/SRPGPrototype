# npc_skills.gd
# Resource — stores all skill levels for a single NPC.
# Skills are stored as raw floats (0.0 - 1.0) internally
# but exposed as named thresholds for readability.
# Skills improve through use — a blacksmith gets better by smithing.
# Attached directly to NPCData.

class_name NPCSkills
extends Resource

# ─── THRESHOLDS ───────────────────────────────────────────────────────────────
# Named levels based on raw skill value.

enum Level {
	NOVICE,      # 0.00 - 0.19
	APPRENTICE,  # 0.20 - 0.39
	JOURNEYMAN,  # 0.40 - 0.59
	EXPERT,      # 0.60 - 0.79
	MASTER       # 0.80 - 1.00
}

# How much experience is gained per practice event.
# Small value — mastery should take a long time.
const XP_PER_PRACTICE: float = 0.005

# Stats that influence how fast specific skills improve.
# Each entry maps a skill name to a stat on NPCData.
const SKILL_STAT_AFFINITY: Dictionary = {
	"combat":       "stat_strength",
	"farming":      "stat_endurance",
	"smithing":     "stat_strength",
	"trading":      "stat_charisma",
	"cooking":      "stat_intelligence",
	"hunting":      "stat_endurance",
	"construction": "stat_strength",
	"medicine":     "stat_intelligence"
}

# ─── SKILL VALUES ─────────────────────────────────────────────────────────────
# Raw float values. Never read these directly outside this class —
# use get_level() or get_value() instead.

@export var combat:       float = 0.0
@export var farming:      float = 0.0
@export var smithing:     float = 0.0
@export var trading:      float = 0.0
@export var cooking:      float = 0.0
@export var hunting:      float = 0.0
@export var construction: float = 0.0
@export var medicine:     float = 0.0

# ─── READ ─────────────────────────────────────────────────────────────────────

# Returns the raw float value of a skill by name.
func get_value(skill_name: String) -> float:
	return get(skill_name) if _is_valid(skill_name) else 0.0

# Returns the threshold Level enum for a given skill.
func get_level(skill_name: String) -> Level:
	return _value_to_level(get_value(skill_name))

# Returns the threshold name as a readable string.
# Example: get_level_name("smithing") → "Expert"
func get_level_name(skill_name: String) -> String:
	return Level.keys()[get_level(skill_name)].capitalize()

# Returns all skills and their level names as a Dictionary.
# Useful for UI and debugging.
func get_summary() -> Dictionary:
	var result := {}
	for skill_name in _all_skill_names():
		result[skill_name] = get_level_name(skill_name)
	return result

# ─── IMPROVE ──────────────────────────────────────────────────────────────────

# Improves a skill by one practice event.
# The owning NPC is passed in so stat affinity can influence gain rate.
# Returns the new raw value.
func practice(skill_name: String, npc: NPCData) -> float:
	if not _is_valid(skill_name):
		push_warning("NPCSkills: Unknown skill '%s'." % skill_name)
		return 0.0

	# Stat affinity gives a small bonus to experience gain
	var stat_name: String = SKILL_STAT_AFFINITY.get(skill_name, "")
	var stat_value: float = npc.get(stat_name) if stat_name != "" else 0.5

	# Affinity bonus: high stat = up to 50% faster skill gain
	var xp := XP_PER_PRACTICE * (1.0 + stat_value * 0.5)

	var current: float = get_value(skill_name)
	var new_value: float = clampf(current + xp, 0.0, 1.0)
	set(skill_name, new_value)

	return new_value

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

func _value_to_level(value: float) -> Level:
	if value >= 0.80: return Level.MASTER
	if value >= 0.60: return Level.EXPERT
	if value >= 0.40: return Level.JOURNEYMAN
	if value >= 0.20: return Level.APPRENTICE
	return Level.NOVICE

func _is_valid(skill_name: String) -> bool:
	return skill_name in _all_skill_names()

func _all_skill_names() -> Array[String]:
	return [
		"combat", "farming", "smithing", "trading",
		"cooking", "hunting", "construction", "medicine"
	]
