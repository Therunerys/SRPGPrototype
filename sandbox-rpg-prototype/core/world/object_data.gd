# object_data.gd
# Resource that defines a single interactable object in the world.
# Objects are the atomic units of need satisfaction and work.
# They live inside POIs but are independent of POI type.
# A bed in a home and a bed in a tavern work identically —
# the difference is ownership and access level.

class_name ObjectData
extends Resource

# ─── OBJECT TYPES ─────────────────────────────────────────────────────────────

enum Type {
	BED,          # Restores rest. Owned by a specific NPC.
	STRAW_MAT,    # Restores rest poorly. Used in camps and poor homes.
	FIREPLACE,    # Restores safety. Shared by household.
	CAMPFIRE,     # Restores safety and social. Public.
	FORGE,        # Enables smithing work. Work access only.
	ANVIL,        # Required alongside forge for full smithing.
	TABLE,        # Enables eating meals properly.
	CHAIR,        # Minor rest restore. Pairs with table.
	MARKET_STALL, # Enables merchant/guard work.
	COOKING_POT   # Enables cook work and food production.
}

# ─── QUALITY ──────────────────────────────────────────────────────────────────
# Affects how effectively this object satisfies needs.
# Produced by blacksmiths — quality reflects their skill level.

enum Quality {
	POOR,        # 0.25 multiplier — basic, functional
	STANDARD,    # 0.50 multiplier — typical village quality
	FINE,        # 0.75 multiplier — skilled craftwork
	MASTERWORK   # 1.00 multiplier — exceptional quality
}

# Maps quality tier to restore multiplier.
const QUALITY_MULTIPLIER: Dictionary = {
	Quality.POOR:       0.25,
	Quality.STANDARD:   0.50,
	Quality.FINE:       0.75,
	Quality.MASTERWORK: 1.00
}

# Maps quality tier to mood modifier applied when using this object.
const QUALITY_MOOD: Dictionary = {
	Quality.POOR:       -0.05,
	Quality.STANDARD:    0.00,
	Quality.FINE:        0.02,
	Quality.MASTERWORK:  0.05
}

# ─── ACCESS LEVELS ────────────────────────────────────────────────────────────

enum Access {
	OWNER,      # Only the owner NPC can use this
	HOUSEHOLD,  # Owner and any NPC in permitted_ids can use this
	WORK,       # Only the assigned worker can use this
	PUBLIC      # Any NPC can use this
}

# ─── NEED SATISFACTION ────────────────────────────────────────────────────────
# Maps each object type to the need it satisfies.
# Empty string means this is a work object with no direct need satisfaction.

const TYPE_SATISFIES_NEED: Dictionary = {
	Type.BED:          "need_rest",
	Type.STRAW_MAT:    "need_rest",
	Type.FIREPLACE:    "need_safety",
	Type.CAMPFIRE:     "need_safety",
	Type.FORGE:        "",
	Type.ANVIL:        "",
	Type.TABLE:        "need_hunger",
	Type.CHAIR:        "",
	Type.MARKET_STALL: "",
	Type.COOKING_POT:  ""
}

# Base restore amount per use before quality multiplier is applied.
# Work objects have 0.0 since they don't restore needs directly.
const TYPE_BASE_RESTORE: Dictionary = {
	Type.BED:          0.8,
	Type.STRAW_MAT:    0.4,
	Type.FIREPLACE:    0.1,
	Type.CAMPFIRE:     0.08,
	Type.FORGE:        0.0,
	Type.ANVIL:        0.0,
	Type.TABLE:        0.1,  # Bonus on top of food's own restore
	Type.CHAIR:        0.0,
	Type.MARKET_STALL: 0.0,
	Type.COOKING_POT:  0.0
}

# ─── IDENTITY ─────────────────────────────────────────────────────────────────

@export var object_id: String = ""
@export var object_type: Type = Type.BED
@export var quality: Quality = Quality.STANDARD

# Where this object lives.
@export var poi_id: String = ""
@export var region_id: String = ""

# ─── OWNERSHIP ────────────────────────────────────────────────────────────────

@export var owner_id: String = ""
@export var access_level: Access = Access.OWNER

# NPCs the owner has explicitly granted access to.
# Only relevant when access_level is HOUSEHOLD.
@export var permitted_ids: Array[String] = []

# ─── USAGE ────────────────────────────────────────────────────────────────────

# How many NPCs can use this object simultaneously.
@export var capacity: int = 1

# IDs of NPCs currently using this object.
@export var current_users: Array[String] = []

# ─── QUERIES ──────────────────────────────────────────────────────────────────

# Returns true if this NPC is permitted to use this object.
func can_use(npc_id: String) -> bool:
	match access_level:
		Access.PUBLIC:
			return true
		Access.OWNER:
			return npc_id == owner_id
		Access.HOUSEHOLD:
			return npc_id == owner_id or npc_id in permitted_ids
		Access.WORK:
			return npc_id == owner_id
	return false

# Returns true if this object has room for another user.
func has_capacity() -> bool:
	return current_users.size() < capacity

# Returns true if this NPC can use this object right now.
func is_available_for(npc_id: String) -> bool:
	return can_use(npc_id) and has_capacity()

# Returns the need this object satisfies, or empty string if work object.
func get_satisfied_need() -> String:
	return TYPE_SATISFIES_NEED.get(object_type, "")

# Returns the final restore amount after quality multiplier.
func get_restore_amount() -> float:
	var base: float = TYPE_BASE_RESTORE.get(object_type, 0.0)
	var multiplier: float = QUALITY_MULTIPLIER.get(quality, 0.5)
	return base * multiplier

# Returns the mood modifier for using this object.
func get_mood_modifier() -> float:
	return QUALITY_MOOD.get(quality, 0.0)

# Returns quality as a readable string.
func get_quality_name() -> String:
	return Quality.keys()[quality].capitalize()

# Returns object type as a readable string.
func get_type_name() -> String:
	return Type.keys()[object_type].capitalize().replace("_", " ")
	
	func find_usable_object(
	type: ObjectData.Type,
	region_id: String,
	npc_id: String,
	permitted_object_ids: Array = []
) -> ObjectData:
	var candidates := get_objects_by_type(region_id, type)
	for obj in candidates:
		# Check standard access first
		if obj.is_available_for(npc_id):
			return obj
		# Check if NPC has been explicitly granted access
		if obj.object_id in permitted_object_ids and obj.has_capacity():
			return obj
	return null
