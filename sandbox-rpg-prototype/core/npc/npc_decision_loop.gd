# npc_decision_loop.gd
# Autoload — drives autonomous NPC decision making.
# Every NPC periodically evaluates their situation and decides what to do.
# Uses a weighted scoring system influenced by needs, traits and profession.
# INACTIVE NPCs decide hourly, ACTIVE NPCs decide every minute.
# This is the brain of the simulation — it ties every other system together.

extends Node

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

# Needs below this threshold are considered critical.
# Critical needs override work and social decisions.
const CRITICAL_THRESHOLD: float = 0.3

# Needs above this threshold are considered satisfied.
# Satisfied needs are ignored in scoring.
const SATISFIED_THRESHOLD: float = 0.75

# How much traits amplify need scores.
# Higher values make traits more influential.
const TRAIT_INFLUENCE: float = 0.4

# ─── SETUP ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	WorldClock.on_minute_passed.connect(_on_minute_passed)
	WorldClock.on_hour_passed.connect(_on_hour_passed)

# ─── CLOCK HOOKS ──────────────────────────────────────────────────────────────

func _on_minute_passed() -> void:
	for npc in NPCManager.get_all_npcs():
		if npc.location.lod_zone == NPCLocation.LODZone.ACTIVE:
			if not npc.location.is_travelling():
				_make_decision(npc)

func _on_hour_passed() -> void:
	for npc in NPCManager.get_all_npcs():
		if npc.location.lod_zone == NPCLocation.LODZone.INACTIVE:
			if not npc.location.is_travelling():
				_make_decision(npc)
			# Also update job satisfaction hourly
			npc.profession.update_satisfaction()

# ─── DECISION MAKING ──────────────────────────────────────────────────────────

# Core decision function — evaluates all possible actions and picks the best.
func _make_decision(npc: NPCData) -> void:
	if npc.full_name != "Dara Harwick":
		return
	# Temporary debug
	print("  Decision for %s | hunger: %.2f" % [npc.full_name, npc.need_hunger])
	
	if npc.need_hunger <= CRITICAL_THRESHOLD:
		print("  → hunger critical, trying to eat")
		if NPCNeedActions.consume_food(npc):
			print("  → ate from inventory")
			return

	var scores := _calculate_scores(npc)
	print("  → scores: %s" % str(scores))

	var best_action := ""
	var best_score := 0.0
	for action in scores:
		if scores[action] > best_score:
			best_score = scores[action]
			best_action = action

	print("  → best action: %s (%.2f)" % [best_action, best_score])
	if best_action != "":
		_execute_action(npc, best_action)

# ─── SCORING ──────────────────────────────────────────────────────────────────

# Returns a Dictionary mapping action names to scores.
# Higher score = higher priority.
func _calculate_scores(npc: NPCData) -> Dictionary:
	var scores := {}

	# ── Hunger ────────────────────────────────────────────────────────────────
	if npc.need_hunger < SATISFIED_THRESHOLD:
		var urgency: float = 1.0 - npc.need_hunger
		var trait_mod: float = 1.0 + (npc.trait_greed * TRAIT_INFLUENCE)
		scores["eat"] = urgency * trait_mod

	# ── Rest ──────────────────────────────────────────────────────────────────
	if npc.need_rest < SATISFIED_THRESHOLD:
		var urgency: float = 1.0 - npc.need_rest
		# Ambitious NPCs deprioritise rest
		var trait_mod: float = 1.0 - (npc.trait_ambition * TRAIT_INFLUENCE)
		scores["sleep"] = urgency * trait_mod

	# ── Safety ────────────────────────────────────────────────────────────────
	if npc.need_safety < SATISFIED_THRESHOLD:
		var urgency: float = 1.0 - npc.need_safety
		# Cowardly NPCs (low courage) prioritise safety more
		var trait_mod: float = 1.0 + (-npc.trait_courage * TRAIT_INFLUENCE)
		scores["seek_safety"] = urgency * trait_mod

	# ── Social ────────────────────────────────────────────────────────────────
	if npc.need_social < SATISFIED_THRESHOLD:
		var urgency: float = 1.0 - npc.need_social
		var trait_mod: float = 1.0 + (npc.trait_empathy * TRAIT_INFLUENCE)
		scores["socialize"] = urgency * trait_mod

	# ── Work ──────────────────────────────────────────────────────────────────
	# Work score is based on job satisfaction and ambition
	# Only score work if needs are not critical
	var most_urgent_need: float = _get_most_urgent_need(npc)
	if most_urgent_need < CRITICAL_THRESHOLD:
		var work_score: float = (
			npc.profession.job_satisfaction * 0.6 +
			npc.trait_ambition * 0.4 +
			0.3 # Base work drive — NPCs default to working
		)
		scores["work"] = clampf(work_score, 0.0, 1.0)

	return scores

# Returns the urgency value of the most critical need.
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
		"eat":        _action_eat(npc)
		"sleep":      _action_sleep(npc)
		"seek_safety": _action_seek_safety(npc)
		"socialize":  _action_socialize(npc)
		"work":       _action_work(npc)

# ─── ACTIONS ──────────────────────────────────────────────────────────────────

func _action_eat(npc: NPCData) -> void:
	# Already at a food POI — try to take food from it
	if _is_at_poi_type(npc, POIData.Type.TAVERN) or \
	   _is_at_poi_type(npc, POIData.Type.GRANARY):
		var poi := POIManager.get_poi(npc.location.current_poi_id)
		if poi and _take_food_from_poi(npc, poi):
			return

	# Try eating from inventory first
	if NPCNeedActions.consume_food(npc):
		return

	# Nothing in inventory — travel to nearest food source
	var poi := _find_nearest_poi_for_need(npc, "need_hunger")
	if poi:
		NPCTravelSystem.begin_travel(npc, poi.poi_id)

# Takes one food item from a POI into NPC inventory and consumes it.
func _take_food_from_poi(npc: NPCData, poi: POIData) -> bool:
	# Find best food in POI storage
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

	# Transfer one unit from POI to NPC inventory
	poi.stored_items[best_id] -= 1
	if poi.stored_items[best_id] <= 0:
		poi.stored_items.erase(best_id)

	# Add to inventory and consume immediately
	npc.inventory.add_item(best_id, 1, npc.stat_strength)
	NPCNeedActions.consume_food(npc)
	return true

func _action_sleep(npc: NPCData) -> void:
	# Check if already at a home
	if _is_at_poi_type(npc, POIData.Type.HOME):
		NPCNeedActions.sleep(npc)
		return

	# Travel to nearest home
	var poi := _find_nearest_poi_for_need(npc, "need_rest")
	if poi:
		NPCTravelSystem.begin_travel(npc, poi.poi_id)

func _action_seek_safety(npc: NPCData) -> void:
	# Home is the safest place
	if _is_at_poi_type(npc, POIData.Type.HOME):
		NPCNeedActions.feel_safe(npc, 0.15)
		return

	var poi := _find_nearest_poi_for_need(npc, "need_safety")
	if poi:
		NPCTravelSystem.begin_travel(npc, poi.poi_id)

func _action_socialize(npc: NPCData) -> void:
	# Tavern is the best place to socialize
	if _is_at_poi_type(npc, POIData.Type.TAVERN):
		# Find another NPC at the same tavern to socialize with
		var partner := _find_social_partner(npc)
		if partner:
			NPCNeedActions.socialize(npc, partner)
			return

	var poi := _find_nearest_poi_for_need(npc, "need_social")
	if poi:
		NPCTravelSystem.begin_travel(npc, poi.poi_id)

func _action_work(npc: NPCData) -> void:
	# Find the correct work POI for this NPC's current job
	var work_poi_type := _get_work_poi_type(npc)
	if work_poi_type == -1:
		return

	if _is_at_poi_type(npc, work_poi_type as POIData.Type):
		# Already at work — perform work action
		npc.profession.do_work(npc)
		npc.profession.is_employed = true
		return

	# Travel to work
	var pois := POIManager.get_pois_by_type(
		npc.location.current_region_id,
		work_poi_type as POIData.Type
	)
	if not pois.is_empty():
		NPCTravelSystem.begin_travel(npc, pois[0].poi_id)

# ─── HELPERS ──────────────────────────────────────────────────────────────────

# Finds the nearest POI that satisfies a given need.
# Searches current region first, then neighbouring regions.
func _find_nearest_poi_for_need(npc: NPCData, need_name: String) -> POIData:
	# Search current region first
	var local_pois := POIManager.get_pois_for_need(
		npc.location.current_region_id, need_name
	)
	if not local_pois.is_empty():
		# Pick POI with available capacity
		for poi in local_pois:
			if poi.has_capacity():
				return poi

	# Search all regions if nothing local found
	var region := RegionManager.get_region(npc.location.current_region_id)
	if region == null:
		return null

	return POIManager.get_nearest_poi(
		_need_to_poi_type(need_name),
		region.world_position
	)

# Returns true if the NPC is currently at a POI of a given type.
func _is_at_poi_type(npc: NPCData, poi_type: POIData.Type) -> bool:
	var poi := POIManager.get_poi(npc.location.current_poi_id)
	return poi != null and poi.poi_type == poi_type

# Returns a social partner NPC at the same POI, or null if none found.
func _find_social_partner(npc: NPCData) -> NPCData:
	var poi := POIManager.get_poi(npc.location.current_poi_id)
	if poi == null:
		return null
	for other_id in poi.current_users:
		if other_id != npc.npc_id:
			return NPCManager.get_npc(other_id)
	return null

# Maps a need name to the POI type that satisfies it.
func _need_to_poi_type(need_name: String) -> POIData.Type:
	match need_name:
		"need_hunger":  return POIData.Type.TAVERN
		"need_rest":    return POIData.Type.HOME
		"need_safety":  return POIData.Type.HOME
		"need_social":  return POIData.Type.TAVERN
		_:              return POIData.Type.HOME

# Returns the POI type where this NPC should work, or -1 if none.
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
