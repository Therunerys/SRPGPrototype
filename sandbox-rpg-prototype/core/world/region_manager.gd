# region_manager.gd
# Autoload singleton — central registry for all regions in the world.
# All other systems should access region data through here.

extends Node

# ─── STORAGE ──────────────────────────────────────────────────────────────────
# Maps region_id (String) → RegionData (Resource)

var _regions: Dictionary = {}

# ─── SIGNALS ──────────────────────────────────────────────────────────────────

signal region_registered(region_data: RegionData)
signal region_removed(region_id: String)

# ─── REGISTRATION ─────────────────────────────────────────────────────────────

func register_region(region_data: RegionData) -> void:
	if region_data.region_id == "":
		push_error("RegionManager: Tried to register a region with no ID.")
		return
	if _regions.has(region_data.region_id):
		push_warning("RegionManager: Region %s is already registered." % region_data.region_id)
		return

	_regions[region_data.region_id] = region_data
	region_registered.emit(region_data)

func remove_region(region_id: String) -> void:
	if not _regions.has(region_id):
		push_warning("RegionManager: Tried to remove region %s but it doesn't exist." % region_id)
		return

	_regions.erase(region_id)
	region_removed.emit(region_id)

# ─── LOOKUP ───────────────────────────────────────────────────────────────────

func get_region(region_id: String) -> RegionData:
	return _regions.get(region_id, null)

func get_all_regions() -> Array:
	return _regions.values()

func get_region_count() -> int:
	return _regions.size()

# ─── POPULATION HELPERS ───────────────────────────────────────────────────────

# Assigns an NPC to a region. Updates both the region and the NPC's home.
func assign_npc_to_region(npc_id: String, region_id: String) -> void:
	var region := get_region(region_id)
	var npc := NPCManager.get_npc(npc_id)

	if region == null:
		push_error("RegionManager: Region %s not found." % region_id)
		return
	if npc == null:
		push_error("RegionManager: NPC %s not found." % npc_id)
		return
	if region.resident_ids.has(npc_id):
		return

	region.resident_ids.append(npc_id)
	npc.home_region_id = region_id

# Removes an NPC from their current region.
func remove_npc_from_region(npc_id: String, region_id: String) -> void:
	var region := get_region(region_id)
	if region == null:
		push_error("RegionManager: Region %s not found." % region_id)
		return

	region.resident_ids.erase(npc_id)

# ─── QUERIES ──────────────────────────────────────────────────────────────────

# Returns all regions of a given type.
func get_regions_by_type(type: RegionData.Type) -> Array:
	return _regions.values().filter(
		func(region): return region.region_type == type
	)

# Returns the nearest region to a given world position.
func get_nearest_region(pos: Vector2) -> RegionData:
	var nearest: RegionData = null
	var nearest_dist := INF

	for region in _regions.values():
		var dist := pos.distance_to(region.world_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = region

	return nearest
