# poi_generator.gd
# Static utility — generates POIs inside a region based on its type.
# Called by RegionGenerator after a region is created.
# Villages get a full set of POIs. Wilderness gets minimal ones.

class_name POIGenerator

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

# How spread out POIs are within a region (local coordinate range).
const REGION_LOCAL_SIZE: Vector2 = Vector2(200.0, 200.0)

# ─── PUBLIC API ───────────────────────────────────────────────────────────────

# Generates and registers all POIs for a given region.
static func generate_for_region(region: RegionData) -> void:
	match region.region_type:
		RegionData.Type.VILLAGE:
			_generate_village_pois(region)
		RegionData.Type.WILDERNESS:
			_generate_wilderness_pois(region)

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

static func _generate_village_pois(region: RegionData) -> void:
	_create_poi(region, POIData.Type.FARM,       "Farm",       10)

	var granary := _create_poi(region, POIData.Type.GRANARY, "Granary", 20)
	granary.stored_items["item_bread"] = 50
	granary.stored_items["item_dried_meat"] = 20

	var tavern := _create_poi(region, POIData.Type.TAVERN, "Tavern", 20)
	tavern.stored_items["item_bread"] = 20
	tavern.stored_items["item_ale"] = 30

	_create_poi(region, POIData.Type.MARKET,     "Market",     15)
	_create_poi(region, POIData.Type.BLACKSMITH, "Blacksmith", 5)

	var resident_count := region.resident_ids.size()
	var home_count: int = max(3, int(resident_count / 3.0))
	var home_capacity: int = max(2, int(float(resident_count) / float(home_count)) + 1)
	for i in home_count:
		_create_poi(region, POIData.Type.HOME, "Home %d" % (i + 1), home_capacity)

static func _generate_wilderness_pois(region: RegionData) -> void:
	# Wilderness only has a camp for basic rest and safety
	_create_poi(region, POIData.Type.HOME, "Camp", 2)

static func _create_poi(
	region: RegionData,
	type: POIData.Type,
	name: String,
	capacity: int
) -> POIData:
	var poi := POIData.new()
	poi.poi_id       = _generate_id()
	poi.poi_name     = "%s %s" % [region.region_name, name]
	poi.poi_type     = type
	poi.region_id    = region.region_id
	poi.capacity     = capacity
	poi.local_position = Vector2(
		randf_range(-REGION_LOCAL_SIZE.x / 2.0, REGION_LOCAL_SIZE.x / 2.0),
		randf_range(-REGION_LOCAL_SIZE.y / 2.0, REGION_LOCAL_SIZE.y / 2.0)
	)
	POIManager.register_poi(poi)
	return poi

static func _generate_id() -> String:
	return "poi_%d_%s" % [Time.get_ticks_msec(), _random_suffix(3)]

static func _random_suffix(length: int) -> String:
	const CHARS = "abcdefghijklmnopqrstuvwxyz"
	var result := ""
	for i in length:
		result += CHARS[randi() % CHARS.length()]
	return result
