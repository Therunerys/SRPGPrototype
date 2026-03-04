# material_data.gd
# Resource that defines a single material type.
# Materials act as multipliers on top of base item stats.
# Example: Iron Shield = Shield base stats * Iron multipliers

class_name MaterialData
extends Resource

# ─── IDENTITY ─────────────────────────────────────────────────────────────────

@export var material_id: String = ""     # e.g. "mat_iron"
@export var material_name: String = ""   # e.g. "Iron"

# ─── MULTIPLIERS ──────────────────────────────────────────────────────────────
# These multiply the base item values.
# 1.0 = no change, 2.0 = double, 0.5 = half.

@export var weight_multiplier: float = 1.0      # Heavier materials weigh more
@export var value_multiplier: float = 1.0       # Better materials are worth more
@export var endurance_multiplier: float = 1.0   # Affects protection bonus
@export var strength_multiplier: float = 1.0    # Affects weapon damage bonus

# ─── COMPATIBILITY ────────────────────────────────────────────────────────────
# Which item categories this material can be used with.
# A sword can't be made of cloth, a tunic can't be made of iron.
# Example: ["CLOTHING", "WEAPON"]

@export var compatible_categories: Array[String] = []

# ─── SETUP ────────────────────────────────────────────────────────────────────

func setup(
	p_id: String,
	p_name: String,
	p_weight_mult: float,
	p_value_mult: float,
	p_endurance_mult: float,
	p_strength_mult: float,
	p_compatible: Array[String]
) -> MaterialData:
	material_id             = p_id
	material_name           = p_name
	weight_multiplier       = p_weight_mult
	value_multiplier        = p_value_mult
	endurance_multiplier    = p_endurance_mult
	strength_multiplier     = p_strength_mult
	compatible_categories   = p_compatible
	return self
