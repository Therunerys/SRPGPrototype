# poi_data.gd
# Resource that holds all data for a single Point of Interest.
# A POI is a named location inside a region that NPCs can travel to.
# Need satisfaction is handled by interactable objects inside the POI,
# not by the POI type itself.

class_name POIData
extends Resource

# ─── POI TYPES ────────────────────────────────────────────────────────────────

enum Type {
	TAVERN,
	GRANARY,
	BLACKSMITH,
	FARM,
	HOME,
	MARKET
}

# Which profession works at each POI type.
const TYPE_WORKER_PROFESSION: Dictionary = {
	Type.TAVERN:     NPCProfession.Type.COOK,
	Type.GRANARY:    NPCProfession.Type.FARMER,
	Type.BLACKSMITH: NPCProfession.Type.BLACKSMITH,
	Type.FARM:       NPCProfession.Type.FARMER,
	Type.HOME:       -1,
	Type.MARKET:     NPCProfession.Type.MERCHANT
}

# ─── IDENTITY ─────────────────────────────────────────────────────────────────

@export var poi_id: String = ""
@export var poi_name: String = ""
@export var poi_type: Type = Type.HOME
@export var region_id: String = ""

@export var local_position: Vector2 = Vector2.ZERO

# ─── CAPACITY ─────────────────────────────────────────────────────────────────

@export var capacity: int = 1
@export var current_users: Array[String] = []

# ─── OWNERSHIP ────────────────────────────────────────────────────────────────

@export var owner_id: String = ""

# ─── RESOURCES ────────────────────────────────────────────────────────────────

@export var stored_items: Dictionary = {}

# ─── QUERIES ──────────────────────────────────────────────────────────────────

func has_capacity() -> bool:
	return current_users.size() < capacity

func is_in_use_by(npc_id: String) -> bool:
	return current_users.has(npc_id)

func get_type_name() -> String:
	return Type.keys()[poi_type].capitalize()
