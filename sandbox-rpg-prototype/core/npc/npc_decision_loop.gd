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
	# Only work during work hours and if no need is critical
	var most_urgent_need: float = _get_most_urgent_need(npc)
	if not is_night and most_urgent_need < CRITICAL_THRESHOLD:
		var work_score: float = (
			npc.profession.job_satisfaction * 0.5 +
			npc.trait_ambition * 0.3
		)
		# Only add base work drive if needs are well satisfied
		if most_urgent_need < 0.2:
			work_score += 0.3
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
	# At a food POI — take food from it
	if _is_at_poi_type(npc, POIData.Type.TAVERN) or \
	   _is_at_poi_type(npc, POIData.Type.GRANARY):
		var current_poi := POIManager.get_poi(npc.location.current_poi_id)
		if current_poi and _take_food_from_poi(npc, current_poi):
			# Need satisfied — leave so others can use it
			POIManager.exit_poi(current_poi.poi_id, npc.npc_id)
			npc.location.current_poi_id = ""
			return

	# Try inventory before travelling
	if NPCNeedActions.consume_food(npc):
		return

	# Travel to nearest food POI
	var poi := _find_nearest_poi_for_need(npc, "need_hunger")
	if poi:
		NPCTravelSystem.begin_travel(npc, poi.poi_id)

# Takes the best food item from a POI and consumes it.
func _take_food_from_poi(npc: NPCData, poi: POIData) -> bool:
	var best_id := ""
	var best_restore := 0.0

	for item_id in poi.stored_items:
		if poi.stored_items[item_id] <= 0:
			continue
		var item := ItemDatabase.get_item(item_id)
		if item and item.category == ItemData.Category.FOOD:
			if item.hunger_restore > best_restore:
				best_restore = item.hunger_restore
				best_id = item_id

	if best_id == "":
		return false

	poi.stored_items[best_id] -= 1
	if poi.stored_items[best_id] <= 0:
		poi.stored_items.erase(best_id)

	npc.inventory.add_item(best_id, 1, npc.stat_strength)
	NPCNeedActions.consume_food(npc)
	return true

func _action_sleep(npc: NPCData) -> void:
	# Only sleep at own home
	if npc.location.current_poi_id == npc.home_poi_id:
		NPCNeedActions.sleep(npc)
		return

	# Travel home to sleep
	if npc.home_poi_id != "":
		NPCTravelSystem.begin_travel(npc, npc.home_poi_id)

func _action_seek_safety(npc: NPCData) -> void:
	# Only feel safe at own home
	if npc.location.current_poi_id == npc.home_poi_id:
		NPCNeedActions.feel_safe(npc, 0.15)
		return

	if npc.home_poi_id != "":
		NPCTravelSystem.begin_travel(npc, npc.home_poi_id)

func _action_socialize(npc: NPCData) -> void:
	# Only socialize at tavern
	if _is_at_poi_type(npc, POIData.Type.TAVERN):
		var partner := _find_social_partner(npc)
		if partner:
			NPCNeedActions.socialize(npc, partner)
			# Leave after socializing
			var current_poi := POIManager.get_poi(npc.location.current_poi_id)
			if current_poi:
				POIManager.exit_poi(current_poi.poi_id, npc.npc_id)
				npc.location.current_poi_id = ""
			return

	var poi := _find_nearest_poi_for_need(npc, "need_social")
	if poi:
		NPCTravelSystem.begin_travel(npc, poi.poi_id)

func _action_work(npc: NPCData) -> void:
	var work_poi_type := _get_work_poi_type(npc)
	if work_poi_type == -1:
		return

	# Already at correct work POI — do work
	if _is_at_poi_type(npc, work_poi_type as POIData.Type):
		npc.profession.do_work(npc)
		npc.profession.is_employed = true
		return

	# Find work POI with capacity and travel to it
	var pois := POIManager.get_pois_by_type(
		npc.location.current_region_id,
		work_poi_type as POIData.Type
	)
	for poi in pois:
		if poi.has_capacity():
			NPCTravelSystem.begin_travel(npc, poi.poi_id)
			return

# ─── HELPERS ──────────────────────────────────────────────────────────────────

func _find_nearest_poi_for_need(npc: NPCData, need_name: String) -> POIData:
	# Search current region first
	var local_pois := POIManager.get_pois_for_need(
		npc.location.current_region_id, need_name
	)
	for poi in local_pois:
		if poi.has_capacity():
			return poi

	# Search wider world if nothing local
	var region := RegionManager.get_region(npc.location.current_region_id)
	if region == null:
		return null

	return POIManager.get_nearest_poi(
		_need_to_poi_type(need_name),
		region.world_position
	)

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

func _need_to_poi_type(need_name: String) -> POIData.Type:
	match need_name:
		"need_hunger":  return POIData.Type.TAVERN
		"need_rest":    return POIData.Type.HOME
		"need_safety":  return POIData.Type.HOME
		"need_social":  return POIData.Type.TAVERN
		_:              return POIData.Type.HOME

func _get_work_poi_type(npc: NPCData) -> int:
	match npc.profession.current_job:
		NPCProfession.Type.FARMER:     return POIData.Type.FARM
		NPCProfession.Type.BLACKSMITH: return POIData.Type.BLACKSMITH
		NPCProfession.Type.MERCHANT:   return POIData.Type.MARKET
		NPCProfession.Type.COOK:       return POIData.Type.TAVERN
		NPCProfession.Type.GUARD:      return POIData.Type.MARKET
		NPCProfession.Type.HEALER:     return -1
		NPCProfession.Type.HUNTER:     return -1
		NPCProfession.Type.LABOURER:   return -1
		_:                             return -1
