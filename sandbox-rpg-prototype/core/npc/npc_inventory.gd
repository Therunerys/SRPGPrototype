# npc_inventory.gd
# Resource — represents a single NPC's inventory.
# Stores items as stacks using resolved_id as key.
# resolved_id is either a plain item_id (food, coins)
# or a combined id like "item_sword_mat_iron" for material items.

class_name NPCInventory
extends Resource

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

const BASE_CARRY_WEIGHT: float = 10.0
const STRENGTH_MULTIPLIER: float = 15.0

# ─── STATE ────────────────────────────────────────────────────────────────────

# Maps resolved_id (String) → quantity (int)
# Example: { "item_bread": 3, "item_sword_mat_iron": 1 }
@export var stacks: Dictionary = {}

# Bonus carry weight from equipped items (backpack etc).
# Updated by NPCEquipment when gear changes.
@export var equipment_carry_bonus: float = 0.0

# ─── WEIGHT ───────────────────────────────────────────────────────────────────

func get_max_weight(strength: float) -> float:
	return BASE_CARRY_WEIGHT + (strength * STRENGTH_MULTIPLIER) + equipment_carry_bonus

func get_current_weight() -> float:
	var total := 0.0
	for resolved_id in stacks:
		var resolved := _resolve_from_id(resolved_id)
		if resolved:
			total += resolved.weight * stacks[resolved_id]
	return total

func would_exceed_weight(resolved: ResolvedItem, quantity: int, strength: float) -> bool:
	return (get_current_weight() + resolved.weight * quantity) > get_max_weight(strength)

# ─── ADD / REMOVE ─────────────────────────────────────────────────────────────

func add_item(item_id: String, quantity: int, strength: float, material_id: String = "") -> bool:
	if quantity <= 0:
		push_warning("NPCInventory: Tried to add invalid quantity %d of %s." % [quantity, item_id])
		return false

	var resolved := ItemResolver.resolve(item_id, material_id)
	if resolved == null:
		return false

	if would_exceed_weight(resolved, quantity, strength):
		return false

	if stacks.has(resolved.resolved_id):
		stacks[resolved.resolved_id] += quantity
	else:
		stacks[resolved.resolved_id] = quantity

	return true

func remove_item(resolved_id: String, quantity: int) -> bool:
	if quantity <= 0:
		push_warning("NPCInventory: Tried to remove invalid quantity %d of %s." % [quantity, resolved_id])
		return false

	if not stacks.has(resolved_id) or stacks[resolved_id] < quantity:
		return false

	stacks[resolved_id] -= quantity
	if stacks[resolved_id] <= 0:
		stacks.erase(resolved_id)

	return true

# ─── QUERIES ──────────────────────────────────────────────────────────────────

func get_quantity(resolved_id: String) -> int:
	return stacks.get(resolved_id, 0)

func has_item(resolved_id: String) -> bool:
	return stacks.get(resolved_id, 0) > 0

func get_food_items() -> Array:
	var food := []
	for resolved_id in stacks:
		var resolved := _resolve_from_id(resolved_id)
		if resolved and resolved.category == ItemData.Category.FOOD:
			food.append(resolved_id)
	return food

func get_total_value() -> float:
	var total := 0.0
	for resolved_id in stacks:
		var resolved := _resolve_from_id(resolved_id)
		if resolved:
			total += resolved.value * stacks[resolved_id]
	return total

func get_summary() -> String:
	if stacks.is_empty():
		return "Empty"
	var parts := []
	for resolved_id in stacks:
		var resolved := _resolve_from_id(resolved_id)
		if resolved:
			parts.append("%dx %s" % [stacks[resolved_id], resolved.display_name])
	return ", ".join(parts)

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

# Splits a resolved_id back into item_id and material_id then resolves it.
func _resolve_from_id(resolved_id: String) -> ResolvedItem:
	var parts := resolved_id.split("__")
	var item_id := parts[0]
	var material_id := parts[1] if parts.size() > 1 else ""
	return ItemResolver.resolve(item_id, material_id)
