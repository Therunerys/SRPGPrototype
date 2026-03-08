# npc_need_actions.gd
# Static utility — handles all need restoration actions for NPCs.
# Opposite of NPCNeedDecay — this is how needs go back up.
# Called by the decision loop when an NPC acts to satisfy a need.
# No state lives here — just logic.

class_name NPCNeedActions

# ─── HUNGER ───────────────────────────────────────────────────────────────────

# Attempts to consume the most restorative food item in the NPC's inventory.
# Returns true if food was consumed, false if inventory has no food.
static func consume_food(npc: NPCData) -> bool:
	var best_item_id := _find_best_food(npc)
	if best_item_id == "":
		return false

	var resolved := ItemResolver.resolve(best_item_id)
	if resolved == null:
		return false

	# Remove food from inventory
	npc.inventory.remove_item(best_item_id, 1)

	# Restore hunger — clamped so it never exceeds 1.0
	npc.need_hunger = clampf(npc.need_hunger + resolved.hunger_restore, 0.0, 1.0)

	return true

# ─── REST ─────────────────────────────────────────────────────────────────────

# Sleep now takes restore amount from the bed object quality
# quality parameter removed — caller passes the amount directly
static func sleep(npc: NPCData, restore_amount: float) -> void:
	npc.need_rest = clampf(npc.need_rest + restore_amount, 0.0, 1.0)

# ─── SAFETY ───────────────────────────────────────────────────────────────────

# Restores safety need when NPC reaches a safe location.
# Called when an NPC enters a safe region or building.
static func feel_safe(npc: NPCData, amount: float = 0.1) -> void:
	npc.need_safety = clampf(npc.need_safety + amount, 0.0, 1.0)

# ─── SOCIAL ───────────────────────────────────────────────────────────────────

# Restores social need when an NPC interacts with another.
# Both NPCs benefit from the interaction.
# relationship_score influences how much the interaction helps.
static func socialize(npc_a: NPCData, npc_b: NPCData) -> void:
	# Base social restore from any interaction
	var base_restore := 0.05

	# Relationship score between -1.0 and 1.0
	# Positive relationships restore more, negative restore less
	var score_a: float = npc_a.relationships.get(npc_b.npc_id, 0.0)
	var score_b: float = npc_b.relationships.get(npc_a.npc_id, 0.0)

	npc_a.need_social = clampf(
		npc_a.need_social + base_restore + (score_a * 0.03),
		0.0, 1.0
	)
	npc_b.need_social = clampf(
		npc_b.need_social + base_restore + (score_b * 0.03),
		0.0, 1.0
	)

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

# Finds the resolved_id of the most hunger-restoring food item in inventory.
# Returns empty string if no food is found.
static func _find_best_food(npc: NPCData) -> String:
	var food_items := npc.inventory.get_food_items()
	if food_items.is_empty():
		return ""

	var best_id := ""
	var best_restore := 0.0

	for resolved_id in food_items:
		# Split resolved_id to get item_id and material_id
		var parts: PackedStringArray = resolved_id.split("__")
		var item_id: String = parts[0]
		var material_id: String = parts[1] if parts.size() > 1 else ""
		var resolved := ItemResolver.resolve(item_id, material_id)
		if resolved and resolved.hunger_restore > best_restore:
			best_restore = resolved.hunger_restore
			best_id = resolved_id

	return best_id
