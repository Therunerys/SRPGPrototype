# npc_location.gd
# Resource — stores the abstract world position of a single NPC.
# Position is represented as region + poi rather than raw coordinates.
# This keeps the simulation lightweight at tens of thousands of NPCs.
# The 3D visual layer reads this to know where to render the NPC.
# Attached directly to NPCData.

class_name NPCLocation
extends Resource

# ─── LOD ZONES ────────────────────────────────────────────────────────────────
# Defines how actively this NPC is simulated based on player proximity.
# INACTIVE  → far from player, updated hourly
# ACTIVE    → medium distance, updated every minute
# PRESENT   → near player, updated every frame (3D layer handles this)

enum LODZone {
	INACTIVE,
	ACTIVE,
	PRESENT
}

# ─── CURRENT POSITION ─────────────────────────────────────────────────────────

# Which region the NPC is currently in.
@export var current_region_id: String = ""

# Which POI the NPC is currently at.
# Empty string means the NPC is travelling between POIs.
@export var current_poi_id: String = ""

# ─── TRAVEL STATE ─────────────────────────────────────────────────────────────

# Where the NPC is heading. Empty string means they are not travelling.
@export var destination_poi_id: String = ""

# Which region the destination POI is in.
# May differ from current_region_id if travelling between regions.
@export var destination_region_id: String = ""

# How far along the journey the NPC is.
# Range: 0.0 (just left) to 1.0 (arrived).
@export var travel_progress: float = 0.0

# Total travel time required in game minutes.
# Calculated when travel begins based on distance and NPC stats.
@export var travel_duration_minutes: float = 0.0

# ─── LOD ──────────────────────────────────────────────────────────────────────

# Current LOD zone — set by NPCTravelSystem based on player proximity.
@export var lod_zone: LODZone = LODZone.INACTIVE

# ─── QUERIES ──────────────────────────────────────────────────────────────────

# Returns true if the NPC is currently travelling between POIs.
func is_travelling() -> bool:
	return destination_poi_id != ""

# Returns true if the NPC is at a specific POI.
func is_at_poi(poi_id: String) -> bool:
	return current_poi_id == poi_id and not is_travelling()

# Returns true if the NPC is in a specific region.
func is_in_region(region_id: String) -> bool:
	return current_region_id == region_id
