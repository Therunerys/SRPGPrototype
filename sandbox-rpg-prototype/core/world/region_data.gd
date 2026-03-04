# region_data.gd
# Resource that holds all data for a single region.
# Pure data container — no logic. The simulation layer's representation
# of a named area in the world (village, forest, etc).

class_name RegionData
extends Resource

# ─── REGION TYPES ─────────────────────────────────────────────────────────────
enum Type {
	WILDERNESS,
	VILLAGE
}

# ─── IDENTITY ─────────────────────────────────────────────────────────────────

@export var region_id: String = ""
@export var region_name: String = ""
@export var region_type: Type = Type.WILDERNESS

# Position in the simulation world (2D abstract coordinates).
# The 3D visual layer will read this to know where to generate terrain.
@export var world_position: Vector2 = Vector2.ZERO

# ─── POPULATION ───────────────────────────────────────────────────────────────
# Stores npc_ids of all NPCs that currently live in this region.
# We store IDs only — never direct references to NPCData.

@export var resident_ids: Array[String] = []

# Maximum number of NPCs this region can comfortably support.
# Overpopulation will drive NPCs to leave later.
@export var population_cap: int = 0

# ─── RESOURCES ────────────────────────────────────────────────────────────────
# What this region naturally produces. Maps resource name to abundance.
# Range: 0.0 (depleted) to 1.0 (plentiful)
# Example: { "food": 0.8, "wood": 0.6 }
# The economy system will read and modify these values later.

@export var resources: Dictionary = {}

# ─── CONTROL ──────────────────────────────────────────────────────────────────
# Which faction currently controls this region.
# Empty string means unclaimed/neutral.
@export var controlling_faction_id: String = ""
