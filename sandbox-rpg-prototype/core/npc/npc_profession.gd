# npc_profession.gd
# Resource — stores profession and employment state for a single NPC.
# Primary profession is the NPC's identity and long term goal.
# Current job is what they are actually doing right now to survive.
# These can differ — a blacksmith might labour on a farm if no smithy is available.
# Attached directly to NPCData.

class_name NPCProfession
extends Resource

# ─── PROFESSION TYPES ─────────────────────────────────────────────────────────

enum Type {
	FARMER,       # Produces food, uses farming skill
	BLACKSMITH,   # Produces weapons/armour, uses smithing skill
	MERCHANT,     # Trades goods between regions, uses trading skill
	HUNTER,       # Gathers food from wilderness, uses hunting skill
	COOK,         # Produces better food from ingredients, uses cooking skill
	GUARD,        # Provides safety to a region, uses combat skill
	HEALER,       # Restores NPC health, uses medicine skill
	LABOURER      # Unskilled fallback job, uses construction skill
}

# Maps each profession to the skill it primarily uses and improves.
# When an NPC works, this skill gets a practice call.
const PROFESSION_SKILL: Dictionary = {
	Type.FARMER:     "farming",
	Type.BLACKSMITH: "smithing",
	Type.MERCHANT:   "trading",
	Type.HUNTER:     "hunting",
	Type.COOK:       "cooking",
	Type.GUARD:      "combat",
	Type.HEALER:     "medicine",
	Type.LABOURER:   "construction"
}

# Maps each skill name to its corresponding profession type.
# Used when deriving profession from highest skill at generation.
const SKILL_PROFESSION: Dictionary = {
	"farming":      Type.FARMER,
	"smithing":     Type.BLACKSMITH,
	"trading":      Type.MERCHANT,
	"hunting":      Type.HUNTER,
	"cooking":      Type.COOK,
	"combat":       Type.GUARD,
	"medicine":     Type.HEALER,
	"construction": Type.LABOURER
}

# ─── STATE ────────────────────────────────────────────────────────────────────

# What the NPC identifies as — their background and long term goal.
# Never changes unless a major life event occurs.
@export var primary_profession: Type = Type.LABOURER

# What the NPC is actually doing right now.
# Changes based on available work in their current region.
@export var current_job: Type = Type.LABOURER

# Whether the NPC is currently employed.
# Unemployed NPCs actively seek work and suffer mood penalties.
@export var is_employed: bool = false

# How satisfied the NPC is with their current job.
# Range: 0.0 (miserable) to 1.0 (content).
# Low satisfaction drives NPCs to seek better work.
# Influenced by whether current_job matches primary_profession.
@export var job_satisfaction: float = 0.5

# ─── SETUP ────────────────────────────────────────────────────────────────────

# Initializes profession from the NPC's highest skill with some randomness.
# chance_of_random: 0.0 = always match skill, 1.0 = always random
func derive_from_skills(skills: NPCSkills, chance_of_random: float = 0.3) -> void:
	var highest_skill := _get_highest_skill(skills)
	
	if randf() < chance_of_random:
		# Random profession — represents background not matching skills
		var all_types := Type.values()
		primary_profession = all_types[randi() % all_types.size()]
	else:
		# Match profession to highest skill
		primary_profession = SKILL_PROFESSION.get(highest_skill, Type.LABOURER)

	# Start unemployed — they will find work through the simulation
	current_job    = primary_profession
	is_employed    = false
	job_satisfaction = 0.5

# ─── WORK ─────────────────────────────────────────────────────────────────────

# Called when an NPC performs a unit of work.
# Improves the skill associated with their current job.
# Returns the updated skill value.
func do_work(npc: NPCData) -> float:
	var skill_name: String = PROFESSION_SKILL.get(current_job, "construction")
	return npc.skills.practice(skill_name, npc)

# ─── SATISFACTION ─────────────────────────────────────────────────────────────

# Updates job satisfaction based on whether current job matches primary profession.
# Called periodically by the simulation — not every frame.
func update_satisfaction() -> void:
	if not is_employed:
		# Unemployment is always dissatisfying
		job_satisfaction = clampf(job_satisfaction - 0.05, 0.0, 1.0)
		return

	if current_job == primary_profession:
		# Working in their field — satisfaction drifts upward
		job_satisfaction = clampf(job_satisfaction + 0.02, 0.0, 1.0)
	else:
		# Working outside their field — satisfaction drifts downward
		job_satisfaction = clampf(job_satisfaction - 0.02, 0.0, 1.0)

# ─── QUERIES ──────────────────────────────────────────────────────────────────

# Returns the primary profession as a readable string.
func get_primary_name() -> String:
	return Type.keys()[primary_profession].capitalize()

# Returns the current job as a readable string.
func get_current_job_name() -> String:
	return Type.keys()[current_job].capitalize()

# Returns true if the NPC is working outside their primary profession.
func is_working_outside_field() -> bool:
	return is_employed and current_job != primary_profession

# Returns the skill name this NPC improves when working their current job.
func get_current_skill() -> String:
	return PROFESSION_SKILL.get(current_job, "construction")

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

# Finds the name of the skill with the highest value on the given NPCSkills.
func _get_highest_skill(skills: NPCSkills) -> String:
	var all_skills := [
		"farming", "smithing", "trading", "hunting",
		"cooking", "combat", "medicine", "construction"
	]
	var highest_name := "construction"
	var highest_value := 0.0
	for skill_name in all_skills:
		var value: float = skills.get_value(skill_name)
		if value > highest_value:
			highest_value = value
			highest_name = skill_name
	return highest_name
