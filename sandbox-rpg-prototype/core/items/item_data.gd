# item_data.gd
# Resource that defines a single item TYPE — not an instance.
# Think of this as the template. "Bread" is a type,
# "Jorin's bread" is an instance of that type in his inventory.
# All items in the game are instances derived from these templates.

class_name ItemData
extends Resource

# ─── CATEGORIES ───────────────────────────────────────────────────────────────
enum Category {
	FOOD,
	CURRENCY,
	CLOTHING,  # Armour and regular clothing
	WEAPON,
	TOOL       # Farming tools, crafting tools — equippable work items
}

# ─── IDENTITY ─────────────────────────────────────────────────────────────────

@export var item_id: String = ""        # Unique identifier e.g. "item_bread"
@export var item_name: String = ""      # Display name e.g. "Bread"
@export var category: Category = Category.FOOD
@export var description: String = ""   # Flavour text, shown in UI later

# ─── PHYSICAL ─────────────────────────────────────────────────────────────────

@export var weight: float = 0.0        # Weight in kg per unit
@export var base_value: float = 0.0    # Base coin value per unit

# Whether multiple units share one inventory slot.
# Coins and food stack. Unique items (weapons, tools) do not.
@export var stackable: bool = true

# ─── FOOD PROPERTIES ──────────────────────────────────────────────────────────
# Only relevant if category is FOOD. Ignored otherwise.

@export var hunger_restore: float = 0.0   # Range: 0.0 to 1.0
@export var thirst_restore: float = 0.0   # Reserved for later

# ─── EQUIPMENT PROPERTIES ─────────────────────────────────────────────────────
# Relevant for CLOTHING, WEAPON, and TOOL categories.

enum Slot {
	NONE,       # Not equippable (food, currency)
	HEAD,
	CHEST,
	LEGS,
	FEET,
	HANDS,
	WEAPON,     # Main hand — weapons and tools like hoe/scythe
	OFFHAND,
	BACK        # Backpacks, seed bags
}

@export var equip_slot: Slot = Slot.NONE

# Stat bonuses applied to the NPC when this item is equipped.
@export var bonus_strength: float = 0.0
@export var bonus_endurance: float = 0.0
@export var bonus_intelligence: float = 0.0
@export var bonus_charisma: float = 0.0

# Extra carry weight granted when equipped (backpacks, seed bags etc).
@export var carry_bonus: float = 0.0

# ─── SETUP ────────────────────────────────────────────────────────────────────

func setup(
	p_id: String,
	p_name: String,
	p_category: Category,
	p_description: String,
	p_weight: float,
	p_value: float,
	p_hunger_restore: float,
	p_thirst_restore: float,
	p_equip_slot: Slot = Slot.NONE,
	p_bonus_strength: float = 0.0,
	p_bonus_endurance: float = 0.0,
	p_bonus_intelligence: float = 0.0,
	p_bonus_charisma: float = 0.0,
	p_carry_bonus: float = 0.0
) -> ItemData:
	item_id            = p_id
	item_name          = p_name
	category           = p_category
	description        = p_description
	weight             = p_weight
	base_value         = p_value
	hunger_restore     = p_hunger_restore
	thirst_restore     = p_thirst_restore
	stackable          = p_equip_slot == Slot.NONE
	equip_slot         = p_equip_slot
	bonus_strength     = p_bonus_strength
	bonus_endurance    = p_bonus_endurance
	bonus_intelligence = p_bonus_intelligence
	bonus_charisma     = p_bonus_charisma
	carry_bonus        = p_carry_bonus
	return self
