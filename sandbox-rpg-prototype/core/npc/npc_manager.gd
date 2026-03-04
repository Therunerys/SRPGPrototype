# npc_manager.gd
# Autoload singleton — exists for the entire lifetime of the game.
# Acts as the central registry for all NPCs in the world.
# All other systems should access NPC data through here.

extends Node

# ─── STORAGE ──────────────────────────────────────────────────────────────────
# Primary storage. Maps npc_id (String) → NPCData (Resource).
# Using a Dictionary allows O(1) lookups by ID regardless of NPC count.
# Example: _npcs["npc_0042"] → NPCData instance

var _npcs: Dictionary = {}

# ─── SIGNALS ──────────────────────────────────────────────────────────────────
# Other systems can listen to these instead of polling the manager every frame.

signal npc_registered(npc_data: NPCData)
signal npc_removed(npc_id: String)

# ─── REGISTRATION ─────────────────────────────────────────────────────────────

# Adds a new NPC to the registry.
# Called by NPCFactory after generating a new NPC.
func register_npc(npc_data: NPCData) -> void:
	if npc_data.npc_id == "":
		push_error("NPCManager: Tried to register an NPC with no ID.")
		return
	if _npcs.has(npc_data.npc_id):
		push_warning("NPCManager: NPC with ID %s is already registered." % npc_data.npc_id)
		return
	
	_npcs[npc_data.npc_id] = npc_data
	npc_registered.emit(npc_data)

# Removes an NPC from the registry (death, despawn, etc).
func remove_npc(npc_id: String) -> void:
	if not _npcs.has(npc_id):
		push_warning("NPCManager: Tried to remove NPC %s but they don't exist." % npc_id)
		return
	
	_npcs.erase(npc_id)
	npc_removed.emit(npc_id)

# ─── LOOKUP ───────────────────────────────────────────────────────────────────

# Returns the NPCData for a given ID, or null if not found.
# Always check for null when using this — not every ID is guaranteed to exist.
func get_npc(npc_id: String) -> NPCData:
	return _npcs.get(npc_id, null)

# Returns all NPCs as an Array. Useful for iteration but avoid every frame.
func get_all_npcs() -> Array:
	return _npcs.values()

# Returns total number of registered NPCs.
func get_npc_count() -> int:
	return _npcs.size()

# ─── QUERIES ──────────────────────────────────────────────────────────────────

# Returns all NPCs belonging to a specific faction.
func get_npcs_by_faction(faction_id: String) -> Array:
	return _npcs.values().filter(
		func(npc): return npc.faction_id == faction_id
	)

# Returns all NPCs in a specific region.
func get_npcs_by_region(region_id: String) -> Array:
	return _npcs.values().filter(
		func(npc): return npc.home_region_id == region_id
	)
