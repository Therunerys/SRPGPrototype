# region_generator.gd
# Static utility for procedurally generating RegionData instances.
# Regions are placed randomly within world bounds for now.
# A heightmap driven placement system can replace this later.

class_name RegionGenerator

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

# The abstract 2D bounds of the simulation world.
# These are not metres — just unitless simulation coordinates.
# The 3D visual layer will scale these to real world space later.
const WORLD_SIZE: Vector2 = Vector2(1000.0, 1000.0)

# How close two regions can be to each other.
# Prevents regions from overlapping.
const MIN_REGION_SPACING: float = 80.0

# Population caps per region type
const POP_CAP_VILLAGE: int = 50
const POP_CAP_WILDERNESS: int = 5  # scouts, hermits, bandits etc

# ─── REGION NAMES ─────────────────────────────────────────────────────────────

const VILLAGE_PREFIXES: Array[String] = [
	"Ash", "Black", "Cold", "Dark", "East",
	"Fair", "Grey", "High", "Iron", "Keld"
]

const VILLAGE_SUFFIXES: Array[String] = [
	"ford", "haven", "hollow", "moor", "reach",
	"stead", "vale", "watch", "wood", "worth"
]

const WILDERNESS_NAMES: Array[String] = [
	"The Ashwood", "Blackfen Marsh", "Coldwater Wilds", "Duskpine Forest",
	"Emberfall Heath", "Greystone Highlands", "Ironroot Thicket",
	"Mistmoor", "Ravenpeak Ridge", "Thornwall Woods", "Silverbrook Fen",
	"Deadwater Flats", "Howling Steppe", "Cinderhollow", "Wychwood",
	"Bleakmoor", "Saltmarsh Expanse", "The Tanglement", "Fogwater Basin",
	"Rustpeak Crags"
]

# ─── PUBLIC API ───────────────────────────────────────────────────────────────

# Generates a full world with a given number of villages and wilderness regions.
# NPCs are generated and assigned to regions automatically.
static func generate_world(village_count: int, wilderness_count: int) -> void:
	_used_wilderness_names.clear()
	var placed_positions: Array[Vector2] = []

	# Always generate wilderness first — it fills the world
	for i in wilderness_count:
		var region := _create_region(RegionData.Type.WILDERNESS, placed_positions)
		if region:
			RegionManager.register_region(region)
			placed_positions.append(region.world_position)

	# Then place villages in remaining space
	for i in village_count:
		var region := _create_region(RegionData.Type.VILLAGE, placed_positions)
		if region:
			RegionManager.register_region(region)
			placed_positions.append(region.world_position)
			_populate_region(region)

	print("RegionGenerator: Generated %d regions. (%d villages, %d wilderness)" % [
		RegionManager.get_region_count(),
		village_count,
		wilderness_count
	])

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

# Creates a single RegionData of the given type.
# Returns null if a valid position could not be found.
static func _create_region(type: RegionData.Type, placed: Array[Vector2]) -> RegionData:
	var pos := _find_valid_position(placed)
	if pos == Vector2.ZERO:
		push_warning("RegionGenerator: Could not find valid position for region.")
		return null

	var region := RegionData.new()
	region.region_id = _generate_id()
	region.region_type = type
	region.world_position = pos

	match type:
		RegionData.Type.VILLAGE:
			region.region_name = _generate_village_name()
			region.population_cap = POP_CAP_VILLAGE
			region.resources = {
				"food": randf_range(0.5, 1.0),
				"wood": randf_range(0.3, 0.8)
			}
		RegionData.Type.WILDERNESS:
			region.region_name = _pick_unique_wilderness_name()
			region.population_cap = POP_CAP_WILDERNESS
			region.resources = {
				"wood": randf_range(0.6, 1.0),
				"food": randf_range(0.2, 0.6)
			}

	return region

# Generates NPCs and assigns them to a region up to its population cap.
static func _populate_region(region: RegionData) -> void:
	var count := randi_range(int(region.population_cap * 0.5), region.population_cap)
	var npcs := NPCGenerator.generate_batch(count)
	for npc in npcs:
		RegionManager.assign_npc_to_region(npc.npc_id, region.region_id)
	POIGenerator.generate_for_region(region)
	_place_npcs_in_region(region)
	# Generate objects AFTER NPCs are placed so ownership is known
	_generate_objects_for_region(region)

static func _generate_objects_for_region(region: RegionData) -> void:
	var pois := POIManager.get_pois_in_region(region.region_id)
	for poi in pois:
		var npc_ids: Array = poi.current_users.duplicate()
		ObjectGenerator.generate_for_poi(poi, npc_ids)

static func _place_npcs_in_region(region: RegionData) -> void:
	var homes := POIManager.get_pois_by_type(region.region_id, POIData.Type.HOME)
	if homes.is_empty():
		return

	var home_index := 0

	for npc_id in region.resident_ids:
		var npc := NPCManager.get_npc(npc_id)
		if npc == null:
			continue

		# Cycle through homes — distributes NPCs evenly across all homes
		var home: POIData = homes[home_index % homes.size()]
		home_index += 1

		# Assign this home to the NPC permanently
		npc.home_poi_id = home.poi_id
		npc.location.current_region_id = region.region_id
		npc.location.current_poi_id    = home.poi_id

		# First NPC assigned becomes the owner
		if home.owner_id == "":
			home.owner_id = npc_id

		POIManager.enter_poi(home.poi_id, npc_id)

# Divides the world into a grid and picks a random point within a cell.
# Guarantees even spread across the map rather than random clustering.
static func _find_valid_position(placed: Array[Vector2]) -> Vector2:
	for attempt in 30:
		var candidate := Vector2(
			randf_range(50.0, WORLD_SIZE.x - 50.0),
			randf_range(50.0, WORLD_SIZE.y - 50.0)
		)
		var valid := true
		for existing in placed:
			if candidate.distance_to(existing) < MIN_REGION_SPACING:
				valid = false
				break
		if valid:
			return candidate

	return Vector2.ZERO

static func _generate_village_name() -> String:
	var prefix := VILLAGE_PREFIXES[randi() % VILLAGE_PREFIXES.size()]
	var suffix := VILLAGE_SUFFIXES[randi() % VILLAGE_SUFFIXES.size()]
	return prefix + suffix

static func _generate_id() -> String:
	return "region_%d_%s" % [Time.get_ticks_msec(), _random_suffix(3)]

static func _random_suffix(length: int) -> String:
	const CHARS = "abcdefghijklmnopqrstuvwxyz"
	var result := ""
	for i in length:
		result += CHARS[randi() % CHARS.length()]
	return result
	
# Tracks used wilderness names to avoid duplicates within a generation pass
static var _used_wilderness_names: Array[String] = []

static func _pick_unique_wilderness_name() -> String:
	# Reset if we've used all available names
	if _used_wilderness_names.size() >= WILDERNESS_NAMES.size():
		_used_wilderness_names.clear()

	var available := WILDERNESS_NAMES.filter(
		func(name): return not _used_wilderness_names.has(name)
	)
	var picked: String = available[randi() % available.size()]
	_used_wilderness_names.append(picked)
	return picked
