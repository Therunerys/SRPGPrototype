# npc_decision_loop.gd
# Autoload — drives autonomous NPC decision making.
# Every NPC periodically evaluates their situation and decides what to do.
# Uses a weighted scoring system influenced by needs, traits, profession
# and time of day. Respects a day/night cycle and meal times.
# INACTIVE NPCs decide hourly, ACTIVE and PRESENT NPCs decide every minute.

extends Node

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

# Needs below this threshold are considered critical.
# Critical needs override all other decisions including work.
const CRITICAL_THRESHOLD: float = 0.25

# Needs above this threshold are considered satisfied and ignored in scoring.
const SATISFIED_THRESHOLD: float = 0.85

# How much traits amplify need scores.
const TRAIT_INFLUENCE: float = 0.4

# Work hours — NPCs only work between these hours.
const WORK_HOUR_START: int = 6
const WORK_HOUR_END: int = 20

# Meal times — hours when NPCs are boosted to eat regardless of hunger level.
const MEAL_HOURS: Array[int] = [7, 13, 19]

# How close to a meal hour triggers the meal boost (in hours).
const MEAL_WINDOW: int = 1

# ─── SETUP ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	WorldClock.on_minute_passed.connect(_on_minute_passed)
	WorldClock.on_hour_passed.connect(_on_hour_passed)

# ─── CLOCK HOOKS ──────────────────────────────────────────────────────────────

func _on_minute_passed() -> void:
	for npc in NPCManager.get_all_npcs():
		if npc.location.lod_zone == NPCLocation.LODZone.ACTIVE or \
		   npc.location.lod_zone == NPCLocation.LODZone.PRESENT:
			if not npc.location.is_travelling():
				_make_decision(npc)

func _on_hour_passed() -> void:
	for npc in NPCManager.get_all_npcs():
		if npc.location.lod_zone == NPCLocation.LODZone.INACTIVE:
			if not npc.location.is_travelling():
				_make_decision(npc)
		npc.profession.update_satisfaction()

# ─── DECISION MAKING ──────────────────────────────────────────────────────────

func _make_decision(npc: NPCData) -> void:
	# Never make decisions while travelling — wait until arrived
	if npc.location.is_travelling():
		return

	# Critical hunger — try inventory first
	if npc.need_hunger <= CRITICAL_THRESHOLD:
		if NPCNeedActions.consume_food(npc):
			return

	var scores := _calculate_scores(npc)
	var best_action := ""
	var best_score := 0.0
	for action in scores:
		if scores[action] > best_score:
			best_score = scores[action]
			best_action = action

	if best_action != "":
		_execute_action(npc, best_action)

# ─── SCORING ──────────────────────────────────────────────────────────────────

func _calculate_scores(npc: NPCData) -> Dictionary:
	var scores := {}
	var hour := WorldClock.hour
	var is_night: bool = hour >= WORK_HOUR_END or hour < WORK_HOUR_START
	var is_meal_time: bool = _is_meal_time(hour)

	# ── Hunger ────────────────────────────────────────────────────────────────
	# Always score hunger if critical, boost at meal times
	var hunger_urgency: float = 1.0 - npc.need_hunger
	if npc.need_hunger <= CRITICAL_THRESHOLD:
		# Critical hunger always gets maximum score
		scores["eat"] = 1.0
	elif is_meal_time and npc.need_hunger < SATISFIED_THRESHOLD:
		# Meal time boost — NPC wants to eat even if not very hungry
		var trait_mod: float = 1.0 + (npc.trait_greed * TRAIT_INFLUENCE)
		scores["eat"] = clampf(hunger_urgency * trait_mod + 0.3, 0.0, 1.0)
	elif npc.need_hunger < SATISFIED_THRESHOLD:
		# Normal hunger scoring
		var trait_mod: float = 1.0 + (npc.trait_greed * TRAIT_INFLUENCE)
		scores["eat"] = hunger_urgency * trait_mod

	# ── Rest ──────────────────────────────────────────────────────────────────
	if npc.need_rest < SATISFIED_THRESHOLD:
		var urgency: float = 1.0 - npc.need_rest
		var trait_mod: float = 1.0 - (npc.trait_ambition * TRAIT_INFLUENCE)
		var rest_score: float = urgency * trait_mod
		# Boost sleep score at night significantly
		if is_night:
			rest_score += 0.5
		scores["sleep"] = clampf(rest_score, 0.0, 1.0)

	# ── Safety ────────────────────────────────────────────────────────────────
	if npc.need_safety < SATISFIED_THRESHOLD:
		var urgency: float = 1.0 - npc.need_safety
		var trait_mod: float = 1.0 + (-npc.trait_courage * TRAIT_INFLUENCE)
		scores["seek_safety"] = urgency * trait_mod

	# ── Social ────────────────────────────────────────────────────────────────
	# Only socialize during the day and evening, not at night
	if not is_night and npc.need_social < SATISFIED_THRESHOLD:
		var urgency: float = 1.0 - npc.need_social
		var trait_mod: float = 1.0 + (npc.trait_empathy * TRAIT_INFLUENCE)
		scores["socialize"] = urgency * trait_mod

	# ── Work ──────────────────────────────────────────────────────────────────
	# Only work during work hours and if no need is critical.
	# Base score is high enough to compete with satisfied needs —
	# an NPC with full needs should default to working during the day.
	var most_urgent_need: float = _get_most_urgent_need(npc)
	if not is_night and most_urgent_need < CRITICAL_THRESHOLD:
		# Base drive: NPCs want to work by default during the day
		var work_score: float = 0.55
		# Ambition pushes score higher, laziness pulls it down
		work_score += npc.trait_ambition * TRAIT_INFLUENCE
		# Job satisfaction modifier — miserable workers are less motivated
		work_score *= npc.profession.job_satisfaction * 0.4 + 0.6
		# Penalise if needs are dropping — address needs first
		work_score *= 1.0 - (most_urgent_need * 0.5)
		scores["work"] = clampf(work_score, 0.0, 1.0)

	return scores

# Returns true if the current hour is within a meal window.
func _is_meal_time(hour: int) -> bool:
	for meal_hour in MEAL_HOURS:
		if abs(hour - meal_hour) <= MEAL_WINDOW:
			return true
	return false

# Returns the urgency of the most critical need.
func _get_most_urgent_need(npc: NPCData) -> float:
	return max(
		1.0 - npc.need_hunger,
		max(
			1.0 - npc.need_rest,
			max(
				1.0 - npc.need_safety,
				1.0 - npc.need_social
			)
		)
	)

# ─── ACTION EXECUTION ─────────────────────────────────────────────────────────

func _execute_action(npc: NPCData, action: String) -> void:
	match action:
		"eat":         _action_eat(npc)
		"sleep":       _action_sleep(npc)
		"seek_safety": _action_seek_safety(npc)
		"socialize":   _action_socialize(npc)
		"work":        _action_work(npc)

# ─── ACTIONS ──────────────────────────────────────────────────────────────────

func _action_eat(npc: NPCData) -> void:
	# Declare once at the top to avoid redeclaration warning
	var table: ObjectData = ObjectManager.find_usable_object(
		ObjectData.Type.TABLE,
		npc.location.current_region_id,
		npc.npc_id,
		npc.permitted_object_ids
	)

	# Already at a POI with a usable table — eat here
	if table and table.poi_id == npc.location.current_poi_id:
		var current_poi := POIManager.get_poi(npc.location.current_poi_id)
		var ate := false
		if current_poi:
			ate = _take_food_from_poi(npc, current_poi)
		if not ate:
			ate = NPCNeedActions.consume_food(npc)
		if ate:
			# Apply table quality bonus on top of food's own restore
			npc.need_hunger = clampf(
				npc.need_hunger + table.get_restore_amount(),
				0.0, 1.0
			)
			npc.mood = clampf(npc.mood + table.get_mood_modifier(), -1.0, 1.0)
			return

	# No table here — eat from inventory directly if critically hungry
	if npc.need_hunger <= CRITICAL_THRESHOLD:
		if NPCNeedActions.consume_food(npc):
			return

	# Travel to the table found above
	if table:
		NPCTravelSystem.begin_travel(npc, table.poi_id)
	else:
		# No table in region — search globally
		var region := RegionManager.get_region(npc.location.current_region_id)
		if region:
			var global_table: ObjectData = ObjectManager.find_usable_object_global(
				ObjectData.Type.TABLE, npc.npc_id, region.world_position
			)
			if global_table:
				NPCTravelSystem.begin_travel(npc, global_table.poi_id)

func _action_sleep(npc: NPCData) -> void:
	# Declare once to avoid redeclaration warning
	var bed: ObjectData = ObjectManager.find_usable_object(
		ObjectData.Type.BED,
		npc.location.current_region_id,
		npc.npc_id,
		npc.permitted_object_ids
	)

	# Already at the POI with this bed — sleep now
	if bed and bed.poi_id == npc.location.current_poi_id:
		ObjectManager.begin_use(bed.object_id, npc.npc_id)
		NPCNeedActions.sleep(npc, bed.get_restore_amount())
		npc.mood = clampf(npc.mood + bed.get_mood_modifier(), -1.0, 1.0)
		ObjectManager.end_use(bed.object_id, npc.npc_id)
		return

	# Travel to the bed found above
	if bed:
		NPCTravelSystem.begin_travel(npc, bed.poi_id)
	else:
		# No bed available — try straw mat as fallback
		var mat: ObjectData = ObjectManager.find_usable_object(
			ObjectData.Type.STRAW_MAT,
			npc.location.current_region_id,
			npc.npc_id,
			npc.permitted_object_ids
		)
		if mat:
			NPCTravelSystem.begin_travel(npc, mat.poi_id)

func _action_seek_safety(npc: NPCData) -> void:
	# Check for fireplace or campfire at current POI
	if npc.location.current_poi_id != "":
		for fire_type in [ObjectData.Type.FIREPLACE, ObjectData.Type.CAMPFIRE]:
			var fire := ObjectManager.find_usable_object(
				fire_type,
				npc.location.current_region_id,
				npc.npc_id,
				npc.permitted_object_ids
			)
			if fire and fire.poi_id == npc.location.current_poi_id:
				ObjectManager.begin_use(fire.object_id, npc.npc_id)
				NPCNeedActions.feel_safe(npc, fire.get_restore_amount())
				npc.mood = clampf(npc.mood + fire.get_mood_modifier(), -1.0, 1.0)
				ObjectManager.end_use(fire.object_id, npc.npc_id)
				return

	# Travel to home — always has a fireplace
	if npc.home_poi_id != "":
		NPCTravelSystem.begin_travel(npc, npc.home_poi_id)

func _action_socialize(npc: NPCData) -> void:
	# Only socialize at tavern campfire or public table
	if _is_at_poi_type(npc, POIData.Type.TAVERN):
		var partner := _find_social_partner(npc)
		if partner:
			NPCNeedActions.socialize(npc, partner)
			var current_poi := POIManager.get_poi(npc.location.current_poi_id)
			if current_poi:
				POIManager.exit_poi(current_poi.poi_id, npc.npc_id)
				npc.location.current_poi_id = ""
			return

	# Find nearest tavern
	var pois := POIManager.get_pois_by_type(
		npc.location.current_region_id,
		POIData.Type.TAVERN
	)
	for poi in pois:
		if poi.has_capacity():
			NPCTravelSystem.begin_travel(npc, poi.poi_id)
			return

func _action_work(npc: NPCData) -> void:
	var work_object_type := _get_work_object_type(npc)

	if work_object_type == -1:
		# Professions with no work object (Farmer, Hunter, Healer, Labourer).
		# Send them to their profession's POI type to simulate working there.
		_action_work_at_poi(npc)
		return

	# TOOL_RACK is the farmer's work object — hand off to the full tool flow
	if work_object_type == ObjectData.Type.TOOL_RACK:
		_action_work_farmer(npc)
		return

	# Declare once to avoid redeclaration warning in _action_work
	var work_obj: ObjectData = ObjectManager.find_usable_object(
		work_object_type as ObjectData.Type,
		npc.location.current_region_id,
		npc.npc_id,
		npc.permitted_object_ids
	)

	# Already at the POI with this work object — work now
	if work_obj and work_obj.poi_id == npc.location.current_poi_id:
		ObjectManager.begin_use(work_obj.object_id, npc.npc_id)
		npc.profession.do_work(npc)
		npc.profession.is_employed = true
		ObjectManager.end_use(work_obj.object_id, npc.npc_id)
		return

	# Travel to the work object found above
	if work_obj:
		NPCTravelSystem.begin_travel(npc, work_obj.poi_id)
	else:
		# Work object exists in profession but none available locally
		_action_work_at_poi(npc)

# Fallback for professions without a work object.
# Sends the NPC to the correct POI type for their job and marks them employed.
# Farmers go to farms, hunters go to wilderness, etc.
func _action_work_at_poi(npc: NPCData) -> void:
	var target_poi_type := _get_work_poi_type(npc)
	if target_poi_type == -1:
		return

	# Already at the right POI type — do work in place
	if _is_at_poi_type(npc, target_poi_type as POIData.Type):
		npc.profession.do_work(npc)
		npc.profession.is_employed = true
		return

	# Find the nearest POI of this type and travel there
	var pois := POIManager.get_pois_by_type(
		npc.location.current_region_id,
		target_poi_type as POIData.Type
	)
	for poi in pois:
		if poi.has_capacity():
			NPCTravelSystem.begin_travel(npc, poi.poi_id)
			return

# Full farmer work loop: travel to farm → borrow tool → work → return tool.
# Tools are taken from a TOOL_RACK at the farm and returned when done.
# If the NPC already holds a tool, skip straight to working.
func _action_work_farmer(npc: NPCData) -> void:
	var farm_poi_id := _find_work_poi_id(npc, POIData.Type.FARM)
	if farm_poi_id == "":
		return  # No farm in this region — nothing to do

	# If not at the farm yet, travel there first
	if npc.location.current_poi_id != farm_poi_id:
		NPCTravelSystem.begin_travel(npc, farm_poi_id)
		return

	# At the farm. Find the tool rack.
	var rack: ObjectData = ObjectManager.find_usable_object(
		ObjectData.Type.TOOL_RACK,
		npc.location.current_region_id,
		npc.npc_id,
		npc.permitted_object_ids
	)
	if rack == null:
		# No rack found — fall back to plain work-at-poi
		npc.profession.do_work(npc)
		npc.profession.is_employed = true
		return

	# Check if the NPC already has a hoe (picked up on a previous tick)
	var has_hoe: bool = npc.inventory.has_item("item_hoe__mat_iron") or \
						npc.inventory.has_item("item_hoe__mat_wood")

	if not has_hoe:
		# Try to borrow a hoe from the rack
		var took_iron := ObjectManager.take_from_container(
			rack.object_id, "item_hoe", "mat_iron", 1, npc
		)
		if not took_iron:
			# Try the wood tier if iron is unavailable
			ObjectManager.take_from_container(
				rack.object_id, "item_hoe", "mat_wood", 1, npc
			)
		# Equip whichever hoe we now have
		_equip_first_tool(npc)

	# Do the actual farming work
	ObjectManager.begin_use(rack.object_id, npc.npc_id)
	npc.profession.do_work(npc)
	npc.profession.is_employed = true
	ObjectManager.end_use(rack.object_id, npc.npc_id)

	# Return the hoe after one work tick so others can use it
	var returned_iron := ObjectManager.return_to_container(
		rack.object_id, "item_hoe", "mat_iron", 1, npc
	)
	if not returned_iron:
		ObjectManager.return_to_container(
			rack.object_id, "item_hoe", "mat_wood", 1, npc
		)

	# Unequip if the weapon slot still holds a hoe
	_unequip_tool(npc)

# ─── HELPERS ──────────────────────────────────────────────────────────────────

# Tries to take and consume food from a POI's stored_items.
# Returns true if food was found and consumed.
func _take_food_from_poi(npc: NPCData, poi: POIData) -> bool:
	for item_id in poi.stored_items:
		if poi.stored_items[item_id] <= 0:
			continue
		var resolved := ItemResolver.resolve(item_id)
		if resolved == null or resolved.hunger_restore <= 0.0:
			continue
		# Take one unit from POI storage and eat it
		poi.stored_items[item_id] -= 1
		npc.need_hunger = clampf(npc.need_hunger + resolved.hunger_restore, 0.0, 1.0)
		return true
	return false

func _is_at_poi_type(npc: NPCData, poi_type: POIData.Type) -> bool:
	var poi := POIManager.get_poi(npc.location.current_poi_id)
	return poi != null and poi.poi_type == poi_type

func _find_social_partner(npc: NPCData) -> NPCData:
	var poi := POIManager.get_poi(npc.location.current_poi_id)
	if poi == null:
		return null
	for other_id in poi.current_users:
		if other_id != npc.npc_id:
			return NPCManager.get_npc(other_id)
	return null

# Returns the POI type an NPC should work at when they have no work object.
# Used as a fallback for Farmers, Hunters, Healers and Labourers.
func _get_work_poi_type(npc: NPCData) -> int:
	match npc.profession.current_job:
		NPCProfession.Type.FARMER:   return POIData.Type.FARM
		NPCProfession.Type.HUNTER:   return POIData.Type.FARM   # Wilderness later
		NPCProfession.Type.HEALER:   return POIData.Type.HOME   # Treats at home for now
		NPCProfession.Type.LABOURER: return POIData.Type.FARM   # Construction site later
		_:                           return -1

func _get_work_object_type(npc: NPCData) -> int:
	match npc.profession.current_job:
		NPCProfession.Type.FARMER:     return ObjectData.Type.TOOL_RACK
		NPCProfession.Type.BLACKSMITH: return ObjectData.Type.FORGE
		NPCProfession.Type.MERCHANT:   return ObjectData.Type.MARKET_STALL
		NPCProfession.Type.COOK:       return ObjectData.Type.COOKING_POT
		NPCProfession.Type.GUARD:      return ObjectData.Type.MARKET_STALL
		NPCProfession.Type.HEALER:     return -1
		NPCProfession.Type.HUNTER:     return -1
		NPCProfession.Type.LABOURER:   return -1
		_:                             return -1

# Returns the poi_id of the first available POI of the given type in the NPC's region.
func _find_work_poi_id(npc: NPCData, poi_type: POIData.Type) -> String:
	var pois := POIManager.get_pois_by_type(npc.location.current_region_id, poi_type)
	for poi in pois:
		if poi.has_capacity():
			return poi.poi_id
	return ""

# Equips the first tool found in the NPC's inventory into the WEAPON slot.
func _equip_first_tool(npc: NPCData) -> void:
	for resolved_id in npc.inventory.get_all_item_ids():
		var item := ItemResolver.resolve(resolved_id)
		if item and item.category == ItemData.Category.TOOL:
			npc.equipment.equip(resolved_id, npc)
			return

# Unequips any tool currently held in the WEAPON slot.
func _unequip_tool(npc: NPCData) -> void:
	var slot := ItemData.Slot.WEAPON
	var equipped_id: String = npc.equipment.get_equipped(slot)
	if equipped_id == "":
		return
	var item := ItemResolver.resolve(equipped_id)
	if item and item.category == ItemData.Category.TOOL:
		npc.equipment.unequip(slot, npc)
