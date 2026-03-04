# item_database.gd
# Autoload — central registry of every item type and material in the game.

extends Node

var _items: Dictionary = {}
var _materials: Dictionary = {}

func _ready() -> void:
	_register_all_materials()
	_register_all_items()

# ─── MATERIALS ────────────────────────────────────────────────────────────────

func _register_all_materials() -> void:
	_register_material(MaterialData.new().setup(
		"mat_cloth", "Cloth",
		0.5, 0.8, 0.8, 0.5,
		["CLOTHING"]
	))

	_register_material(MaterialData.new().setup(
		"mat_leather", "Leather",
		0.8, 1.0, 1.0, 0.8,
		["CLOTHING", "WEAPON"]
	))

	_register_material(MaterialData.new().setup(
		"mat_wood", "Wooden",
		1.0, 0.8, 0.9, 0.7,
		["WEAPON", "CLOTHING"]
	))

	_register_material(MaterialData.new().setup(
		"mat_iron", "Iron",
		1.5, 2.0, 1.8, 1.5,
		["WEAPON", "CLOTHING"]
	))

	_register_material(MaterialData.new().setup(
		"mat_steel", "Steel",
		1.3, 3.5, 2.5, 2.0,
		["WEAPON", "CLOTHING"]
	))

	print("ItemDatabase: Registered %d materials." % _materials.size())

func _register_material(material: MaterialData) -> void:
	if material.material_id == "":
		push_error("ItemDatabase: Tried to register a material with no ID.")
		return
	if _materials.has(material.material_id):
		push_warning("ItemDatabase: Material %s already registered." % material.material_id)
		return
	_materials[material.material_id] = material

# ─── ITEMS ────────────────────────────────────────────────────────────────────
# Items are now material-agnostic base templates.
# Stats here represent the baseline before material multipliers.

func _register_all_items() -> void:
	# ── Food ──────────────────────────────────────────────────────────────────
	_register(ItemData.new().setup(
		"item_bread", "Bread", ItemData.Category.FOOD,
		"A simple loaf of bread.",
		0.5, 2.0, 0.3, 0.0
	))
	_register(ItemData.new().setup(
		"item_dried_meat", "Dried Meat", ItemData.Category.FOOD,
		"Salted and dried. Lasts long on the road.",
		0.3, 5.0, 0.5, 0.0
	))
	_register(ItemData.new().setup(
		"item_apple", "Apple", ItemData.Category.FOOD,
		"A fresh apple. Sweet and crisp.",
		0.2, 1.0, 0.15, 0.05
	))
	_register(ItemData.new().setup(
		"item_ale", "Ale", ItemData.Category.FOOD,
		"A mug of ale. Warm and filling.",
		0.5, 3.0, 0.1, 0.2
	))

	# ── Currency ───────────────────────────────────────────────────────────────
	_register(ItemData.new().setup(
		"item_coin_copper", "Copper Coin", ItemData.Category.CURRENCY,
		"The most common coin.", 0.01, 1.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_coin_silver", "Silver Coin", ItemData.Category.CURRENCY,
		"Worth ten copper.", 0.01, 10.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_coin_gold", "Gold Coin", ItemData.Category.CURRENCY,
		"Worth one hundred copper.", 0.01, 100.0, 0.0, 0.0
	))

	# ── Clothing base templates ────────────────────────────────────────────────
	_register(ItemData.new().setup(
		"item_tunic", "Tunic", ItemData.Category.CLOTHING,
		"A basic upper body garment.",
		1.0, 3.0, 0.0, 0.0,
		ItemData.Slot.CHEST, 0.0, 0.05, 0.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_trousers", "Trousers", ItemData.Category.CLOTHING,
		"Standard lower body garment.",
		0.8, 2.0, 0.0, 0.0,
		ItemData.Slot.LEGS, 0.0, 0.03, 0.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_boots", "Boots", ItemData.Category.CLOTHING,
		"Sturdy footwear.",
		0.9, 4.0, 0.0, 0.0,
		ItemData.Slot.FEET, 0.0, 0.03, 0.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_hood", "Hood", ItemData.Category.CLOTHING,
		"A simple head covering.",
		0.3, 2.0, 0.0, 0.0,
		ItemData.Slot.HEAD, 0.0, 0.02, 0.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_helmet", "Helmet", ItemData.Category.CLOTHING,
		"Protective head armour.",
		2.0, 20.0, 0.0, 0.0,
		ItemData.Slot.HEAD, 0.0, 0.15, 0.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_armour", "Armour", ItemData.Category.CLOTHING,
		"Protective chest piece.",
		3.5, 25.0, 0.0, 0.0,
		ItemData.Slot.CHEST, 0.05, 0.1, 0.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_backpack", "Backpack", ItemData.Category.CLOTHING,
		"Allows carrying significantly more.",
		1.5, 15.0, 0.0, 0.0,
		ItemData.Slot.BACK, 0.0, 0.0, 0.0, 0.0, 10.0
	))

	# ── Weapon base templates ──────────────────────────────────────────────────
	_register(ItemData.new().setup(
		"item_sword", "Sword", ItemData.Category.WEAPON,
		"A reliable one handed blade.",
		1.5, 30.0, 0.0, 0.0,
		ItemData.Slot.WEAPON, 0.1, 0.0, 0.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_shield", "Shield", ItemData.Category.WEAPON,
		"A defensive offhand item.",
		2.5, 15.0, 0.0, 0.0,
		ItemData.Slot.OFFHAND, 0.0, 0.1, 0.0, 0.0, 0.0
	))
	_register(ItemData.new().setup(
		"item_knife", "Knife", ItemData.Category.WEAPON,
		"A short utility blade.",
		0.5, 8.0, 0.0, 0.0,
		ItemData.Slot.OFFHAND, 0.05, 0.0, 0.0, 0.0, 0.0
	))

	print("ItemDatabase: Registered %d items." % _items.size())

# ─── REGISTRATION ─────────────────────────────────────────────────────────────

func _register(item: ItemData) -> void:
	if item.item_id == "":
		push_error("ItemDatabase: Tried to register item with no ID.")
		return
	if _items.has(item.item_id):
		push_warning("ItemDatabase: Item %s already registered." % item.item_id)
		return
	_items[item.item_id] = item

# ─── LOOKUP ───────────────────────────────────────────────────────────────────

func get_item(item_id: String) -> ItemData:
	return _items.get(item_id, null)

func get_material(material_id: String) -> MaterialData:
	return _materials.get(material_id, null)

func get_all_items() -> Array:
	return _items.values()

func get_all_materials() -> Array:
	return _materials.values()

func get_items_by_category(category: ItemData.Category) -> Array:
	return _items.values().filter(
		func(item): return item.category == category
	)
