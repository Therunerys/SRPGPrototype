# resolved_item.gd
# Represents a fully resolved item — a base item combined with a material.
# This is what NPCs actually carry and equip.
# Never stored in ItemDatabase — created at runtime by ItemResolver.
# Example: ResolvedItem for "Iron Shield" contains final weight, value, bonuses.

class_name ResolvedItem
extends Resource

# ─── IDENTITY ─────────────────────────────────────────────────────────────────

var item_id: String = ""          # Base item id e.g. "item_shield"
var material_id: String = ""      # Material id e.g. "mat_iron"
var resolved_id: String = ""      # Combined id e.g. "item_shield_mat_iron"
var display_name: String = ""     # e.g. "Iron Shield"

# ─── RESOLVED STATS ───────────────────────────────────────────────────────────
# Final computed values after applying material multipliers.

var weight: float = 0.0
var value: float = 0.0
var equip_slot: ItemData.Slot = ItemData.Slot.NONE
var category: ItemData.Category = ItemData.Category.FOOD
var stackable: bool = false

# Final stat bonuses after material multipliers applied
var bonus_strength: float = 0.0
var bonus_endurance: float = 0.0
var bonus_intelligence: float = 0.0
var bonus_charisma: float = 0.0
var carry_bonus: float = 0.0

# Food properties (unaffected by material)
var hunger_restore: float = 0.0
var thirst_restore: float = 0.0
