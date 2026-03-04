# npc_need_decay.gd
# Autoload — processes need decay for all NPCs every game hour.
# Hooks into WorldClock signals so it never runs every frame.
# Trait values subtly influence how fast each need drops.

extends Node

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
# Base decay amounts per game hour for each need.
# These are the baseline values before trait influence is applied.

const BASE_DECAY_HUNGER: float  = 0.04   # Empties fully in ~25 hours
const BASE_DECAY_REST: float    = 0.03   # Empties fully in ~33 hours
const BASE_DECAY_SAFETY: float  = 0.02   # Empties fully in ~50 hours baseline
const BASE_DECAY_SOCIAL: float  = 0.01   # Empties fully in ~100 hours

# How much a trait can influence decay rate.
# At max trait value (1.0), decay is multiplied by (1 + TRAIT_INFLUENCE).
# At min trait value (-1.0), decay is multiplied by (1 - TRAIT_INFLUENCE).
const TRAIT_INFLUENCE: float = 0.3

# ─── SETUP ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect to the clock — decay runs once per game hour
	WorldClock.on_hour_passed.connect(_on_hour_passed)

# ─── DECAY ────────────────────────────────────────────────────────────────────

func _on_hour_passed() -> void:
	for npc in NPCManager.get_all_npcs():
		_decay_needs(npc)

func _decay_needs(npc: NPCData) -> void:
	# Each need decays at base rate modified by a relevant trait.
	# _trait_modifier returns a multiplier between (1 - TRAIT_INFLUENCE)
	# and (1 + TRAIT_INFLUENCE) based on the trait value.

	# Hunger — greedy NPCs consume more resources
	npc.need_hunger = clampf(
		npc.need_hunger - BASE_DECAY_HUNGER * _trait_modifier(npc.trait_greed),
		0.0, 1.0
	)

	# Rest — ambitious NPCs push through fatigue longer
	# Ambition is inverted — high ambition means slower decay
	npc.need_rest = clampf(
		npc.need_rest - BASE_DECAY_REST * _trait_modifier(-npc.trait_ambition),
		0.0, 1.0
	)

	# Safety — cowardly NPCs feel unsafe more readily
	# Courage is inverted — high courage means slower safety decay
	npc.need_safety = clampf(
		npc.need_safety - BASE_DECAY_SAFETY * _trait_modifier(-npc.trait_courage),
		0.0, 1.0
	)

	# Social — empathetic NPCs crave company more strongly
	npc.need_social = clampf(
		npc.need_social - BASE_DECAY_SOCIAL * _trait_modifier(npc.trait_empathy),
		0.0, 1.0
	)

	# Update mood based on overall need satisfaction
	_update_mood(npc)

# ─── MOOD ─────────────────────────────────────────────────────────────────────

# Mood drifts toward the average satisfaction of all needs.
# It doesn't snap instantly — it shifts gradually each hour.
func _update_mood(npc: NPCData) -> void:
	var average_need := (
		npc.need_hunger +
		npc.need_rest   +
		npc.need_safety +
		npc.need_social
	) / 4.0

	# Convert 0.0-1.0 need average to -1.0-1.0 mood range
	var target_mood := (average_need * 2.0) - 1.0

	# Mood shifts 10% toward target each hour rather than snapping
	npc.mood = lerpf(npc.mood, target_mood, 0.1)

# ─── HELPERS ──────────────────────────────────────────────────────────────────

# Converts a trait value (-1.0 to 1.0) into a decay multiplier.
# Example: trait = 0.5, TRAIT_INFLUENCE = 0.3
# Returns: 1.0 + (0.5 * 0.3) = 1.15 (15% faster decay)
func _trait_modifier(trait_value: float) -> float:
	return 1.0 + (trait_value * TRAIT_INFLUENCE)
