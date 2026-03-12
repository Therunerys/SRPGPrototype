# npc_manager.gd
# Autoload singleton — exists for the entire lifetime of the game.
# Acts as the central registry for all NPCs in the world.
# All other systems should access NPC data through here.

extends Node

# ─── STORAGE ──────────────────────────────────────────────────────────────────
# Primary storage. Maps npc_id (String) → NPCData (Resource).
# O(1) lookups by ID regardless of NPC count.

var _npcs: Dictionary = {}

# ─── LOD BUCKETS ──────────────────────────────────────────────────────────────
# Secondary indexes — each NPC exists in exactly one bucket at all times.
# Avoids iterating all NPCs just to skip most of them every tick.
# Updated by set_lod_zone() whenever NPCTravelSystem recalculates proximity.

var _present:  Dictionary = {}   # Near player — updated every minute
var _active:   Dictionary = {}   # Medium distance — updated every minute
var _inactive: Dictionary = {}   # Far from player — updated every hour

# ─── SIGNALS ──────────────────────────────────────────────────────────────────

signal npc_registered(npc_data: NPCData)
signal npc_removed(npc_id: String)

# ─── REGISTRATION ─────────────────────────────────────────────────────────────

func register_npc(npc_data: NPCData) -> void:
	if npc_data.npc_id == "":
		push_error("NPCManager: Tried to register an NPC with no ID.")
		return
	if _npcs.has(npc_data.npc_id):
		push_warning("NPCManager: NPC with ID %s is already registered." % npc_data.npc_id)
		return

	_npcs[npc_data.npc_id] = npc_data

	# All NPCs start inactive — NPCTravelSystem will sort them on the next tick.
	_inactive[npc_data.npc_id] = npc_data

	npc_registered.emit(npc_data)

func remove_npc(npc_id: String) -> void:
	if not _npcs.has(npc_id):
		push_warning("NPCManager: Tried to remove NPC %s but they don't exist." % npc_id)
		return

	# Remove from whichever bucket they're currently in
	_present.erase(npc_id)
	_active.erase(npc_id)
	_inactive.erase(npc_id)

	_npcs.erase(npc_id)
	npc_removed.emit(npc_id)

# ─── LOD BUCKET MANAGEMENT ────────────────────────────────────────────────────

# Moves an NPC into the correct bucket when their LOD zone changes.
# Called by NPCTravelSystem — do not call this from anywhere else.
func set_lod_zone(npc_id: String, zone: NPCLocation.LODZone) -> void:
	var npc: NPCData = _npcs.get(npc_id, null)
	if npc == null:
		return

	# Skip if already in the correct bucket — avoids unnecessary churn
	if npc.location.lod_zone == zone:
		return

	# Remove from current bucket
	_present.erase(npc_id)
	_active.erase(npc_id)
	_inactive.erase(npc_id)

	# Add to new bucket and update the NPC's own zone record
	match zone:
		NPCLocation.LODZone.PRESENT:  _present[npc_id]  = npc
		NPCLocation.LODZone.ACTIVE:   _active[npc_id]   = npc
		NPCLocation.LODZone.INACTIVE: _inactive[npc_id] = npc

	npc.location.lod_zone = zone

# ─── LOOKUP ───────────────────────────────────────────────────────────────────

func get_npc(npc_id: String) -> NPCData:
	return _npcs.get(npc_id, null)

# Returns all NPCs — use sparingly. Prefer the LOD getters below.
func get_all_npcs() -> Array:
	return _npcs.values()

func get_npc_count() -> int:
	return _npcs.size()

# ─── LOD GETTERS ──────────────────────────────────────────────────────────────
# Use these instead of get_all_npcs() in tick-driven systems.

func get_present_npcs() -> Array:
	return _present.values()

func get_active_npcs() -> Array:
	return _active.values()

func get_inactive_npcs() -> Array:
	return _inactive.values()

# Returns present + active combined — useful for minute-tick systems.
func get_simulated_npcs() -> Array:
	return _present.values() + _active.values()

# ─── QUERIES ──────────────────────────────────────────────────────────────────

func get_npcs_by_faction(faction_id: String) -> Array:
	return _npcs.values().filter(
		func(npc): return npc.faction_id == faction_id
	)

func get_npcs_by_region(region_id: String) -> Array:
	return _npcs.values().filter(
		func(npc): return npc.home_region_id == region_id
	)
