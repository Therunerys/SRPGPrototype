# object_generator.gd
# Static utility — generates interactable objects inside POIs.
# Called by POIGenerator after each POI is created.
# Object ownership is assigned based on POI type and NPC assignment.

class_name ObjectGenerator

# ─── PUBLIC API ───────────────────────────────────────────────────────────────

# Generates all objects for a given POI.
# npc_ids is the list of NPCs assigned to this POI (for ownership).
static func generate_for_poi(poi: POIData, npc_ids: Array = []) -> void:
	match poi.poi_type:
		POIData.Type.HOME:
			_generate_home_objects(poi, npc_ids)
		POIData.Type.TAVERN:
			_generate_tavern_objects(poi)
		POIData.Type.BLACKSMITH:
			_generate_blacksmith_objects(poi, npc_ids)
		POIData.Type.FARM:
			_generate_farm_objects(poi)
		POIData.Type.MARKET:
			_generate_market_objects(poi, npc_ids)
		POIData.Type.GRANARY:
			pass # No interactable objects yet

# ─── HOME ─────────────────────────────────────────────────────────────────────

static func _generate_home_objects(poi: POIData, npc_ids: Array) -> void:
	# One bed per NPC — owned exclusively by them
	for npc_id in npc_ids:
		var bed := _create_object(poi, ObjectData.Type.BED, ObjectData.Quality.STANDARD)
		bed.owner_id = npc_id
		bed.access_level = ObjectData.Access.OWNER
		bed.capacity = 1

	# One fireplace shared by all household members
	if not npc_ids.is_empty():
		var fireplace := _create_object(
			poi, ObjectData.Type.FIREPLACE, ObjectData.Quality.STANDARD
		)
		fireplace.owner_id = npc_ids[0]
		fireplace.access_level = ObjectData.Access.HOUSEHOLD
		fireplace.permitted_ids.assign(npc_ids.slice(1))
		fireplace.capacity = npc_ids.size()

	# One table and chairs for the household
	if not npc_ids.is_empty():
		var table := _create_object(
			poi, ObjectData.Type.TABLE, ObjectData.Quality.STANDARD
		)
		table.owner_id = npc_ids[0]
		table.access_level = ObjectData.Access.HOUSEHOLD
		table.permitted_ids.assign(npc_ids.slice(1))
		table.capacity = npc_ids.size()

		# One chair per household member
		for npc_id in npc_ids:
			var chair := _create_object(
				poi, ObjectData.Type.CHAIR, ObjectData.Quality.STANDARD
			)
			chair.owner_id = npc_ids[0]
			chair.access_level = ObjectData.Access.HOUSEHOLD
			chair.permitted_ids.assign(npc_ids.slice(1))
			chair.capacity = 1

# ─── TAVERN ───────────────────────────────────────────────────────────────────

static func _generate_tavern_objects(poi: POIData) -> void:
	# Multiple public tables and chairs
	for i in 4:
		var table := _create_object(poi, ObjectData.Type.TABLE, ObjectData.Quality.STANDARD)
		table.access_level = ObjectData.Access.PUBLIC
		table.capacity = 4

		for j in 4:
			var chair := _create_object(
				poi, ObjectData.Type.CHAIR, ObjectData.Quality.STANDARD
			)
			chair.access_level = ObjectData.Access.PUBLIC
			chair.capacity = 1

	# One cooking pot for the cook
	var pot := _create_object(
		poi, ObjectData.Type.COOKING_POT, ObjectData.Quality.STANDARD
	)
	pot.access_level = ObjectData.Access.WORK
	pot.capacity = 1

	# Public campfire/hearth
	var campfire := _create_object(
		poi, ObjectData.Type.CAMPFIRE, ObjectData.Quality.STANDARD
	)
	campfire.access_level = ObjectData.Access.PUBLIC
	campfire.capacity = 8

# ─── BLACKSMITH ───────────────────────────────────────────────────────────────

static func _generate_blacksmith_objects(poi: POIData, npc_ids: Array) -> void:
	var owner_id: String = npc_ids[0] if not npc_ids.is_empty() else ""

	var forge := _create_object(poi, ObjectData.Type.FORGE, ObjectData.Quality.STANDARD)
	forge.owner_id = owner_id
	forge.access_level = ObjectData.Access.WORK
	forge.capacity = 1

	var anvil := _create_object(poi, ObjectData.Type.ANVIL, ObjectData.Quality.STANDARD)
	anvil.owner_id = owner_id
	anvil.access_level = ObjectData.Access.WORK
	anvil.capacity = 1

# ─── FARM ─────────────────────────────────────────────────────────────────────

static func _generate_farm_objects(poi: POIData) -> void:
	# One tool rack shared by all farmers at this farm.
	# Access is WORK so only assigned workers can take from it.
	var rack := _create_object(poi, ObjectData.Type.TOOL_RACK, ObjectData.Quality.STANDARD)
	rack.access_level = ObjectData.Access.WORK
	rack.capacity = 99  # Many tools can be stored, not limited by simultaneous users

	# Initialise the rack's inventory and stock it with starting tools.
	# Strength 99.0 bypasses the weight check — containers have no strength stat.
	rack.is_container = true
	rack.inventory = NPCInventory.new()
	rack.inventory.add_item("item_hoe",      2, 99.0, "mat_iron")
	rack.inventory.add_item("item_scythe",   2, 99.0, "mat_iron")
	rack.inventory.add_item("item_seed_bag", 3, 99.0)

# ─── MARKET ───────────────────────────────────────────────────────────────────

static func _generate_market_objects(poi: POIData, npc_ids: Array) -> void:
	# One market stall per merchant/guard assigned here
	for npc_id in npc_ids:
		var stall := _create_object(
			poi, ObjectData.Type.MARKET_STALL, ObjectData.Quality.STANDARD
		)
		stall.owner_id = npc_id
		stall.access_level = ObjectData.Access.WORK
		stall.capacity = 1

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

static func _create_object(
	poi: POIData,
	type: ObjectData.Type,
	quality: ObjectData.Quality
) -> ObjectData:
	var obj := ObjectData.new()
	obj.object_id  = _generate_id()
	obj.object_type = type
	obj.quality    = quality
	obj.poi_id     = poi.poi_id
	obj.region_id  = poi.region_id
	ObjectManager.register_object(obj)
	return obj

static func _generate_id() -> String:
	return "obj_%d_%s" % [Time.get_ticks_msec(), _random_suffix(3)]

static func _random_suffix(length: int) -> String:
	const CHARS = "abcdefghijklmnopqrstuvwxyz"
	var result := ""
	for i in length:
		result += CHARS[randi() % CHARS.length()]
	return result
