# npc_equipment.gd
# Resource — represents what an NPC currently has equipped.
# Each slot holds a resolved_id string or "" if unoccupied.
# Attached directly to NPCData.

class_name NPCEquipment
extends Resource

# ─── SLOTS ────────────────────────────────────────────────────────────────────

@export var slot_head: String    = ""
@export var slot_chest: String   = ""
@export var slot_legs: String    = ""
@export var slot_feet: String    = ""
@export var slot_hands: String   = ""
@export var slot_weapon: String  = ""
@export var slot_offhand: String = ""
@export var slot_back: String    = ""

# ─── EQUIP / UNEQUIP ──────────────────────────────────────────────────────────

func equip(item_id: String, npc: NPCData, material_id: String = "") -> bool:
	var resolved := ItemResolver.resolve(item_id, material_id)
	if resolved == null:
		return false

	if resolved.equip_slot == ItemData.Slot.NONE:
		push_warning("NPCEquipment: Item %s is not equippable." % item_id)
		return false

	if not npc.inventory.has_item(resolved.resolved_id):
		push_warning("NPCEquipment: NPC does not have %s in inventory." % resolved.resolved_id)
		return false

	# Unequip whatever is currently in that slot
	var current := get_slot(resolved.equip_slot)
	if current != "":
		unequip(resolved.equip_slot, npc)

	npc.inventory.remove_item(resolved.resolved_id, 1)
	_set_slot(resolved.equip_slot, resolved.resolved_id)
	_apply_bonuses(resolved, npc, true)

	return true

func unequip(slot: ItemData.Slot, npc: NPCData) -> bool:
	var resolved_id := get_slot(slot)
	if resolved_id == "":
		return false

	var resolved := _resolve_from_id(resolved_id)
	if resolved == null:
		return false

	_apply_bonuses(resolved, npc, false)
	_set_slot(slot, "")

	var parts := resolved_id.split("_mat_")
	var item_id := parts[0]
	var material_id := "mat_" + parts[1] if parts.size() > 1 else ""
	npc.inventory.add_item(item_id, 1, npc.stat_strength, material_id)

	return true

# ─── QUERIES ──────────────────────────────────────────────────────────────────

func get_slot(slot: ItemData.Slot) -> String:
	match slot:
		ItemData.Slot.HEAD:    return slot_head
		ItemData.Slot.CHEST:   return slot_chest
		ItemData.Slot.LEGS:    return slot_legs
		ItemData.Slot.FEET:    return slot_feet
		ItemData.Slot.HANDS:   return slot_hands
		ItemData.Slot.WEAPON:  return slot_weapon
		ItemData.Slot.OFFHAND: return slot_offhand
		ItemData.Slot.BACK:    return slot_back
	return ""

func get_all_equipped() -> Array[String]:
	var equipped: Array[String] = []
	for slot_value in [slot_head, slot_chest, slot_legs, slot_feet,
					   slot_hands, slot_weapon, slot_offhand, slot_back]:
		if slot_value != "":
			equipped.append(slot_value)
	return equipped

func get_equipped_weight() -> float:
	var total := 0.0
	for resolved_id in get_all_equipped():
		var resolved := _resolve_from_id(resolved_id)
		if resolved:
			total += resolved.weight
	return total

func get_summary() -> String:
	var parts: Array[String] = []
	if slot_head    != "": parts.append("Head: %s"    % _resolved_name(slot_head))
	if slot_chest   != "": parts.append("Chest: %s"   % _resolved_name(slot_chest))
	if slot_legs    != "": parts.append("Legs: %s"    % _resolved_name(slot_legs))
	if slot_feet    != "": parts.append("Feet: %s"    % _resolved_name(slot_feet))
	if slot_hands   != "": parts.append("Hands: %s"   % _resolved_name(slot_hands))
	if slot_weapon  != "": parts.append("Weapon: %s"  % _resolved_name(slot_weapon))
	if slot_offhand != "": parts.append("Offhand: %s" % _resolved_name(slot_offhand))
	if slot_back    != "": parts.append("Back: %s"    % _resolved_name(slot_back))
	return ", ".join(parts) if not parts.is_empty() else "Nothing equipped"

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

func _set_slot(slot: ItemData.Slot, resolved_id: String) -> void:
	match slot:
		ItemData.Slot.HEAD:    slot_head    = resolved_id
		ItemData.Slot.CHEST:   slot_chest   = resolved_id
		ItemData.Slot.LEGS:    slot_legs    = resolved_id
		ItemData.Slot.FEET:    slot_feet    = resolved_id
		ItemData.Slot.HANDS:   slot_hands   = resolved_id
		ItemData.Slot.WEAPON:  slot_weapon  = resolved_id
		ItemData.Slot.OFFHAND: slot_offhand = resolved_id
		ItemData.Slot.BACK:    slot_back    = resolved_id

func _apply_bonuses(resolved: ResolvedItem, npc: NPCData, add: bool) -> void:
	var multiplier := 1.0 if add else -1.0
	npc.stat_strength     = clampf(npc.stat_strength     + resolved.bonus_strength     * multiplier, 0.0, 1.0)
	npc.stat_endurance    = clampf(npc.stat_endurance    + resolved.bonus_endurance    * multiplier, 0.0, 1.0)
	npc.stat_intelligence = clampf(npc.stat_intelligence + resolved.bonus_intelligence * multiplier, 0.0, 1.0)
	npc.stat_charisma     = clampf(npc.stat_charisma     + resolved.bonus_charisma     * multiplier, 0.0, 1.0)
	npc.inventory.equipment_carry_bonus = clampf(
		npc.inventory.equipment_carry_bonus + resolved.carry_bonus * multiplier,
		0.0, INF
	)

func _resolve_from_id(resolved_id: String) -> ResolvedItem:
	var parts := resolved_id.split("_mat_")
	var item_id := parts[0]
	# Re-add the "mat_" prefix that was lost during the split
	var material_id := "mat_" + parts[1] if parts.size() > 1 else ""
	return ItemResolver.resolve(item_id, material_id)

func _resolved_name(resolved_id: String) -> String:
	var resolved := _resolve_from_id(resolved_id)
	return resolved.display_name if resolved else "Unknown"
