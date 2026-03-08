# object_manager.gd
# Autoload singleton — central registry for all interactable objects.
# Maintains a spatial index so finding objects by region and type is O(1).
# All systems looking for a bed, forge, table etc go through here.

extends Node

# ─── STORAGE ──────────────────────────────────────────────────────────────────

# Primary storage. object_id → ObjectData.
var _objects: Dictionary = {}

# Spatial index. region_id → { ObjectType → Array[ObjectData] }
# Allows O(1) lookup of all beds in a region without scanning everything.
var _by_region_type: Dictionary = {}

# ─── SIGNALS ──────────────────────────────────────────────────────────────────

signal object_registered(object_data: ObjectData)
signal object_removed(object_id: String)

# ─── REGISTRATION ─────────────────────────────────────────────────────────────

func register_object(obj: ObjectData) -> void:
	if obj.object_id == "":
		push_error("ObjectManager: Tried to register an object with no ID.")
		return
	if _objects.has(obj.object_id):
		push_warning("ObjectManager: Object %s already registered." % obj.object_id)
		return

	_objects[obj.object_id] = obj
	_add_to_index(obj)
	object_registered.emit(obj)

func remove_object(object_id: String) -> void:
	if not _objects.has(object_id):
		push_warning("ObjectManager: Object %s not found." % object_id)
		return

	var obj: ObjectData = _objects[object_id]
	_remove_from_index(obj)
	_objects.erase(object_id)
	object_removed.emit(object_id)

# ─── LOOKUP ───────────────────────────────────────────────────────────────────

func get_object(object_id: String) -> ObjectData:
	return _objects.get(object_id, null)

func get_all_objects() -> Array:
	return _objects.values()

func get_object_count() -> int:
	return _objects.size()

# Returns all objects of a given type in a region.
func get_objects_by_type(region_id: String, type: ObjectData.Type) -> Array:
	if not _by_region_type.has(region_id):
		return []
	return _by_region_type[region_id].get(type, [])

# Returns all objects inside a specific POI.
func get_objects_in_poi(poi_id: String) -> Array:
	return _objects.values().filter(
		func(obj): return obj.poi_id == poi_id
	)

# ─── QUERIES ──────────────────────────────────────────────────────────────────

# Finds the first available object of a given type in a region that the NPC
# is permitted to use.
# permitted_object_ids: extra object IDs the NPC has been granted access to
# (e.g. household objects owned by a housemate).
func find_usable_object(
	type: ObjectData.Type,
	region_id: String,
	npc_id: String,
	permitted_object_ids: Array = []
) -> ObjectData:
	var candidates := get_objects_by_type(region_id, type)
	for obj in candidates:
		# Standard access check (owner, household, public, work)
		if obj.is_available_for(npc_id):
			return obj
		# Explicit permission granted by another NPC (e.g. housemate's fireplace)
		if obj.object_id in permitted_object_ids and obj.has_capacity():
			return obj
	return null

# Finds a usable object across all regions when local search fails.
# Returns the closest available object by region world position.
func find_usable_object_global(
	type: ObjectData.Type,
	npc_id: String,
	from_position: Vector2
) -> ObjectData:
	var best_obj: ObjectData = null
	var best_dist := INF

	for obj in _objects.values():
		if obj.object_type != type:
			continue
		if not obj.is_available_for(npc_id):
			continue
		var region := RegionManager.get_region(obj.region_id)
		if region == null:
			continue
		var dist: float = from_position.distance_to(region.world_position)
		if dist < best_dist:
			best_dist = dist
			best_obj = obj

	return best_obj

# ─── OCCUPANCY ────────────────────────────────────────────────────────────────

# Marks an NPC as using an object.
func begin_use(object_id: String, npc_id: String) -> bool:
	var obj := get_object(object_id)
	if obj == null:
		return false
	if not obj.is_available_for(npc_id):
		return false
	obj.current_users.append(npc_id)
	return true

# Removes an NPC from an object when they finish using it.
func end_use(object_id: String, npc_id: String) -> void:
	var obj := get_object(object_id)
	if obj == null:
		return
	obj.current_users.erase(npc_id)

# ─── CONTAINERS ───────────────────────────────────────────────────────────────

# Takes an item from a container object and puts it in the NPC's inventory.
# Returns true if the transfer succeeded.
func take_from_container(object_id: String, item_id: String, material_id: String, quantity: int, npc: NPCData) -> bool:
	var obj := get_object(object_id)
	if obj == null or not obj.is_container or obj.inventory == null:
		return false
	var resolved_id := item_id if material_id == "" else "%s__%s" % [item_id, material_id]
	if not obj.inventory.has_item(resolved_id):
		return false
	if not obj.inventory.remove_item(resolved_id, quantity):
		return false
	return npc.inventory.add_item(item_id, quantity, npc.stat_strength, material_id)

# Returns an item from an NPC's inventory back into a container.
# Returns true if the transfer succeeded.
func return_to_container(object_id: String, item_id: String, material_id: String, quantity: int, npc: NPCData) -> bool:
	var obj := get_object(object_id)
	if obj == null or not obj.is_container or obj.inventory == null:
		return false
	var resolved_id := item_id if material_id == "" else "%s__%s" % [item_id, material_id]
	if not npc.inventory.has_item(resolved_id):
		return false
	if not npc.inventory.remove_item(resolved_id, quantity):
		return false
	# Containers have no strength limit — use 99.0 to bypass weight check
	return obj.inventory.add_item(item_id, quantity, 99.0, material_id)

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

func _add_to_index(obj: ObjectData) -> void:
	if not _by_region_type.has(obj.region_id):
		_by_region_type[obj.region_id] = {}
	if not _by_region_type[obj.region_id].has(obj.object_type):
		_by_region_type[obj.region_id][obj.object_type] = []
	_by_region_type[obj.region_id][obj.object_type].append(obj)

func _remove_from_index(obj: ObjectData) -> void:
	if not _by_region_type.has(obj.region_id):
		return
	if not _by_region_type[obj.region_id].has(obj.object_type):
		return
	_by_region_type[obj.region_id][obj.object_type].erase(obj)
