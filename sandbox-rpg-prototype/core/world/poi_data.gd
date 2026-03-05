# poi_data.gd
# Resource that holds all data for a single Point of Interest.
# A POI is a named location inside a region that NPCs can travel to
# and interact with to satisfy needs or perform work.
# Pure data container — no logic.

class_name POIData
extends Resource

# ─── POI TYPES ────────────────────────────────────────────────────────────────

enum Type {
	TAVERN,      # Eat and socialize. Cook works here.
	GRANARY,     # Food storage. Farmers deposit here.
	BLACKSMITH,  # Weapon and armour production. Blacksmith works here.
	FARM,        # Food production. Farmer works here.
	HOME,        # Sleep and feel safe.
	MARKET       # Buy and sell goods. Merchant works here.
}

# Which needs each POI type can satisfy.
# Used by the decision loop to find the right POI for a need.
const TYPE_SATISFIES_NEEDS: Dictionary = {
	Type.TAVERN:     ["need_hunger", "need_social"],
	Type.GRANARY:    ["need_hunger"],
	Type.BLACKSMITH: [],
	Type.FARM:       [],
	Type.HOME:       ["need_rest", "need_safety"],
	Type.MARKET:     []
}

# Which profession works at each POI type.
# Empty string means anyone can use it.
const TYPE_WORKER_PROFESSION: Dictionary = {
	Type.TAVERN:     NPCProfession.Type.COOK,
	Type.GRANARY:    NPCProfession.Type.FARMER,
	Type.BLACKSMITH: NPCProfession.Type.BLACKSMITH,
	Type.FARM:       NPCProfession.Type.FARMER,
	Type.HOME:       -1,	# Anyone can sleep at home
	Type.MARKET:     NPCProfession.Type.MERCHANT
}

# ─── IDENTITY ─────────────────────────────────────────────────────────────────

@export var poi_id: String = ""
@export var poi_name: String = ""
@export var poi_type: Type = Type.HOME
@export var region_id: String = ""       # Which region this POI belongs to

# Position within the region (2D local coordinates).
# The 3D visual layer will read this to place the building.
@export var local_position: Vector2 = Vector2.ZERO

# ─── CAPACITY ─────────────────────────────────────────────────────────────────

# Maximum number of NPCs that can use this POI simultaneously.
@export var capacity: int = 1

# IDs of NPCs currently using this POI.
@export var current_users: Array[String] = []

# ─── OWNERSHIP ────────────────────────────────────────────────────────────────

# NPC who owns or operates this POI.
# Empty string means it is unowned (public).
@export var owner_id: String = ""

# ─── RESOURCES ────────────────────────────────────────────────────────────────
# What this POI currently holds in storage.
# Maps item resolved_id → quantity.
# Example: Granary stores { "item_bread": 50 }
# Economy system will read and modify these values later.

@export var stored_items: Dictionary = {}

# ─── QUERIES ──────────────────────────────────────────────────────────────────

# Returns true if this POI can accept another user.
func has_capacity() -> bool:
	return current_users.size() < capacity

# Returns true if a given NPC is currently using this POI.
func is_in_use_by(npc_id: String) -> bool:
	return current_users.has(npc_id)

# Returns the type name as a readable string.
func get_type_name() -> String:
	return Type.keys()[poi_type].capitalize()

# Returns which needs this POI can satisfy.
func get_satisfied_needs() -> Array:
	return TYPE_SATISFIES_NEEDS.get(poi_type, [])

# Returns true if this POI satisfies a specific need.
func satisfies_need(need_name: String) -> bool:
	return need_name in get_satisfied_needs()
