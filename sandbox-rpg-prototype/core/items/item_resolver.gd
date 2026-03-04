# item_resolver.gd
# Static utility — combines a base ItemData with a MaterialData
# to produce a ResolvedItem with final stats.
# Use this whenever you need the actual stats of an item an NPC carries.

class_name ItemResolver

# Returns a ResolvedItem combining the given item and material.
# If material_id is empty, base item stats are used unchanged.
static func resolve(item_id: String, material_id: String = "") -> ResolvedItem:
	var item := ItemDatabase.get_item(item_id)
	if item == null:
		push_error("ItemResolver: Item %s not found." % item_id)
		return null

	var resolved := ResolvedItem.new()
	resolved.item_id  = item_id
	resolved.category = item.category
	resolved.equip_slot = item.equip_slot
	resolved.stackable = item.stackable
	resolved.hunger_restore = item.hunger_restore
	resolved.thirst_restore = item.thirst_restore

	# If no material provided, use base stats directly
	if material_id == "":
		resolved.material_id  = ""
		resolved.resolved_id  = item_id
		resolved.display_name = item.item_name
		resolved.weight       = item.weight
		resolved.value        = item.base_value
		resolved.bonus_strength    = item.bonus_strength
		resolved.bonus_endurance   = item.bonus_endurance
		resolved.bonus_intelligence = item.bonus_intelligence
		resolved.bonus_charisma    = item.bonus_charisma
		resolved.carry_bonus       = item.carry_bonus
		return resolved

	var material := ItemDatabase.get_material(material_id)
	if material == null:
		push_error("ItemResolver: Material %s not found." % material_id)
		return null

	# Verify material is compatible with this item category
	var category_name: String = ItemData.Category.keys()[item.category]
	if not material.compatible_categories.has(category_name):
		push_error("ItemResolver: Material %s is not compatible with category %s." % [
			material_id, category_name
		])
		return null

	resolved.material_id  = material_id
	resolved.resolved_id  = "%s_%s" % [item_id, material_id]
	resolved.display_name = "%s %s" % [material.material_name, item.item_name]

	# Apply material multipliers to base stats
	resolved.weight = item.weight * material.weight_multiplier
	resolved.value  = item.base_value * material.value_multiplier

	# Stat bonuses scaled by material multipliers
	resolved.bonus_strength    = item.bonus_strength    * material.strength_multiplier
	resolved.bonus_endurance   = item.bonus_endurance   * material.endurance_multiplier
	resolved.bonus_intelligence = item.bonus_intelligence
	resolved.bonus_charisma    = item.bonus_charisma
	resolved.carry_bonus       = item.carry_bonus

	return resolved
