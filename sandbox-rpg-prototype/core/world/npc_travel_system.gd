# npc_travel_system.gd
# Autoload — processes NPC travel across the simulation world.
# Uses LOD zones to update NPCs at different rates based on player proximity.
# INACTIVE NPCs update hourly, ACTIVE NPCs update every minute.
# PRESENT NPCs are handled by the 3D visual layer later.
# Hooks into WorldClock signals — never runs every frame.

extends Node

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
# LOD zone distances in simulation world units.
# Tune these constants to control how far each zone extends.

const LOD_DISTANCE_PRESENT:  float = 150.0   # Within this → PRESENT
const LOD_DISTANCE_ACTIVE:   float = 400.0   # Within this → ACTIVE
# Beyond LOD_DISTANCE_ACTIVE → INACTIVE

# Base travel speed in world units per game minute.
# Modified by endurance and encumbrance at runtime.
const BASE_TRAVEL_SPEED: float = 2.0

# ─── STATE ────────────────────────────────────────────────────────────────────

# The player's current world position.
# Updated by the player controller when it exists.
# Defaults to world centre until player exists.
var player_position: Vector2 = Vector2(500.0, 500.0)

# ─── SETUP ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	WorldClock.on_minute_passed.connect(_on_minute_passed)
	WorldClock.on_hour_passed.connect(_on_hour_passed)

# ─── CLOCK HOOKS ──────────────────────────────────────────────────────────────

func _on_minute_passed() -> void:
	# Update zones first so buckets are correct before processing
	_update_all_lod_zones()

	for npc in NPCManager.get_simulated_npcs():
		if npc.location.is_travelling():
			_advance_travel(npc, 1.0)

func _on_hour_passed() -> void:
	for npc in NPCManager.get_inactive_npcs():
		if npc.location.is_travelling():
			_advance_travel(npc, 60.0)

# ─── LOD ──────────────────────────────────────────────────────────────────────

func _update_all_lod_zones() -> void:
	for npc in NPCManager.get_all_npcs():
		_update_lod_zone(npc)

func _update_lod_zone(npc: NPCData) -> void:
	var region := RegionManager.get_region(npc.location.current_region_id)

	# No region means we can't calculate distance — default to inactive
	if region == null:
		NPCManager.set_lod_zone(npc.npc_id, NPCLocation.LODZone.INACTIVE)
		return

	var dist: float = player_position.distance_to(region.world_position)

	if dist <= LOD_DISTANCE_PRESENT:
		NPCManager.set_lod_zone(npc.npc_id, NPCLocation.LODZone.PRESENT)
	elif dist <= LOD_DISTANCE_ACTIVE:
		NPCManager.set_lod_zone(npc.npc_id, NPCLocation.LODZone.ACTIVE)
	else:
		NPCManager.set_lod_zone(npc.npc_id, NPCLocation.LODZone.INACTIVE)

# ─── TRAVEL ───────────────────────────────────────────────────────────────────

# Begins travel for an NPC toward a destination POI.
# Calculates travel duration based on distance, endurance and encumbrance.
func begin_travel(npc: NPCData, destination_poi_id: String) -> bool:
	var dest_poi := POIManager.get_poi(destination_poi_id)
	if dest_poi == null:
		push_error("NPCTravelSystem: Destination POI %s not found." % destination_poi_id)
		return false

	if not dest_poi.has_capacity():
		return false

	# Leave current POI
	if npc.location.current_poi_id != "":
		POIManager.exit_poi(npc.location.current_poi_id, npc.npc_id)
		npc.location.current_poi_id = ""

	npc.location.destination_poi_id     = destination_poi_id
	npc.location.destination_region_id  = dest_poi.region_id
	npc.location.travel_progress        = 0.0
	npc.location.travel_duration_minutes = _calculate_travel_duration(npc, dest_poi)

	return true

# Advances travel progress by a given number of game minutes.
func _advance_travel(npc: NPCData, minutes: float) -> void:
	if npc.location.travel_duration_minutes <= 0.0:
		_arrive(npc)
		return

	var progress_gain: float = minutes / npc.location.travel_duration_minutes
	npc.location.travel_progress = clampf(
		npc.location.travel_progress + progress_gain,
		0.0, 1.0
	)

	if npc.location.travel_progress >= 1.0:
		_arrive(npc)

# Called when an NPC completes their journey.
func _arrive(npc: NPCData) -> void:
	var dest_poi_id    := npc.location.destination_poi_id
	var dest_region_id := npc.location.destination_region_id

	# Clear travel state
	npc.location.destination_poi_id      = ""
	npc.location.destination_region_id   = ""
	npc.location.travel_progress         = 0.0
	npc.location.travel_duration_minutes = 0.0

	# Update region
	npc.location.current_region_id = dest_region_id

	# Always set current_poi_id to the destination — never leave it empty.
	# This prevents the debug view from flashing "Unknown" between ticks.
	# If the POI is full, the decision loop will reroute on the next tick.
	POIManager.enter_poi(dest_poi_id, npc.npc_id)
	npc.location.current_poi_id = dest_poi_id

# ─── TRAVEL SPEED ─────────────────────────────────────────────────────────────

# Calculates how many game minutes it takes to reach the destination.
# Based on distance between regions, endurance and encumbrance.
func _calculate_travel_duration(npc: NPCData, dest_poi: POIData) -> float:
	# Get world positions of current and destination regions
	var current_region := RegionManager.get_region(npc.location.current_region_id)
	var dest_region    := RegionManager.get_region(dest_poi.region_id)

	var distance: float = 0.0
	if current_region != null and dest_region != null:
		distance = current_region.world_position.distance_to(dest_region.world_position)

	# Minimum distance for same-region travel (POI to POI within village)
	distance = max(distance, 10.0)

	# Endurance modifier — range 0.5 to 1.0
	var endurance_mod: float = 0.5 + (npc.stat_endurance * 0.5)

	# Encumbrance modifier — range 0.6 to 1.0
	var max_weight: float = npc.inventory.get_max_weight(npc.stat_strength)
	var carry_ratio: float = 0.0
	if max_weight > 0.0:
		carry_ratio = npc.inventory.get_current_weight() / max_weight
	var encumbrance_mod: float = 1.0 - (carry_ratio * 0.4)

	# Final speed and duration
	var speed: float = BASE_TRAVEL_SPEED * endurance_mod * encumbrance_mod
	return distance / speed

# ─── PUBLIC HELPERS ───────────────────────────────────────────────────────────

# Called by the player controller to update player position.
# The 3D layer will call this every frame when it exists.
func set_player_position(pos: Vector2) -> void:
	player_position = pos
