# poi_manager.gd
# Autoload singleton — central registry for all POIs in the world.
# All systems looking for a place to eat, work or sleep go through here.

extends Node

# Maps poi_id (String) → POIData (Resource)
var _pois: Dictionary = {}

# ─── SIGNALS ──────────────────────────────────────────────────────────────────

signal poi_registered(poi_data: POIData)
signal poi_removed(poi_id: String)

# ─── REGISTRATION ─────────────────────────────────────────────────────────────

func register_poi(poi_data: POIData) -> void:
	if poi_data.poi_id == "":
		push_error("POIManager: Tried to register a POI with no ID.")
		return
	if _pois.has(poi_data.poi_id):
		push_warning("POIManager: POI %s is already registered." % poi_data.poi_id)
		return
	_pois[poi_data.poi_id] = poi_data
	poi_registered.emit(poi_data)

func remove_poi(poi_id: String) -> void:
	if not _pois.has(poi_id):
		push_warning("POIManager: Tried to remove POI %s but it doesn't exist." % poi_id)
		return
	_pois.erase(poi_id)
	poi_removed.emit(poi_id)

# ─── LOOKUP ───────────────────────────────────────────────────────────────────

func get_poi(poi_id: String) -> POIData:
	return _pois.get(poi_id, null)

func get_all_pois() -> Array:
	return _pois.values()

func get_poi_count() -> int:
	return _pois.size()

# ─── QUERIES ──────────────────────────────────────────────────────────────────

# Returns all POIs in a specific region.
func get_pois_in_region(region_id: String) -> Array:
	return _pois.values().filter(
		func(poi): return poi.region_id == region_id
	)

# Returns all POIs of a given type in a region.
func get_pois_by_type(region_id: String, type: POIData.Type) -> Array:
	return _pois.values().filter(
		func(poi): return poi.region_id == region_id and poi.poi_type == type
	)

# Returns the nearest available POI of a given type to a world position.
# Searches across all regions — useful when the NPC might need to travel.
func get_nearest_poi(poi_type: POIData.Type, from_position: Vector2) -> POIData:
	var nearest: POIData = null
	var nearest_dist := INF

	for poi in _pois.values():
		if poi.poi_type != poi_type or not poi.has_capacity():
			continue
		var region := RegionManager.get_region(poi.region_id)
		if region == null:
			continue
		var dist: float = from_position.distance_to(region.world_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = poi

	return nearest

# ─── OCCUPANCY ────────────────────────────────────────────────────────────────

# Marks an NPC as currently using a POI.
func enter_poi(poi_id: String, npc_id: String) -> bool:
	var poi := get_poi(poi_id)
	if poi == null:
		return false
	if not poi.has_capacity():
		push_warning("POIManager: POI %s is at capacity." % poi_id)
		return false
	if poi.is_in_use_by(npc_id):
		return false
	poi.current_users.append(npc_id)
	return true

# Removes an NPC from a POI when they leave.
func exit_poi(poi_id: String, npc_id: String) -> void:
	var poi := get_poi(poi_id)
	if poi == null:
		return
	poi.current_users.erase(npc_id)
