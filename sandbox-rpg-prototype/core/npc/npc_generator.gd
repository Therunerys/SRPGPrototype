# npc_generator.gd
# Static utility for creating NPCData instances.
# Has no state of its own — just generates and returns NPCData.
# Call from anywhere: NPCGenerator.generate_batch(50)

class_name NPCGenerator

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
# Tweak these ranges to control how NPCs are generated.

const AGE_MIN: int = 16
const AGE_MAX: int = 70

# Trait randomization spread. Keeps traits near centre to avoid
# a world full of extremes. Individual life events shift them over time.
const TRAIT_SPREAD: float = 0.5

# ─── PUBLIC API ───────────────────────────────────────────────────────────────

# Generates a single NPC and registers them with NPCManager.
# Returns the generated NPCData in case the caller needs it.
static func generate_single() -> NPCData:
	var npc := _create_npc_data()
	NPCManager.register_npc(npc)
	return npc

# Generates multiple NPCs at once and registers all of them.
# Use this for world startup or populating a new region.
static func generate_batch(count: int) -> Array[NPCData]:
	var batch: Array[NPCData] = []
	for i in count:
		var npc := _create_npc_data()
		NPCManager.register_npc(npc)
		batch.append(npc)
	print("NPCGenerator: Generated %d NPCs. Total: %d" % [count, NPCManager.get_npc_count()])
	return batch

# ─── INTERNAL ─────────────────────────────────────────────────────────────────

# Builds and returns a single NPCData instance with randomized values.
static func _create_npc_data() -> NPCData:
	var npc := NPCData.new()
	
	npc.npc_id = _generate_id()
	npc.age = randi_range(AGE_MIN, AGE_MAX)
	
	# Pick gender and assign appropriate name
	var is_male: bool = randf() > 0.5
	var first_name: String = _pick_random(
		NPCNames.FIRST_NAMES_MALE if is_male else NPCNames.FIRST_NAMES_FEMALE
	)
	var last_name: String = _pick_random(NPCNames.LAST_NAMES)
	npc.full_name = "%s %s" % [first_name, last_name]
	
	# Randomize traits within a believable central range
	npc.trait_courage    = _random_trait()
	npc.trait_greed      = _random_trait()
	npc.trait_empathy    = _random_trait()
	npc.trait_aggression = _random_trait()
	npc.trait_ambition   = _random_trait()
	
	# Give each NPC a skillset
	npc.skills = NPCSkills.new()
	_give_starting_skills(npc)
	
	# Randomize needs — start mostly satisfied with slight variation
	npc.need_hunger = randf_range(0.7, 1.0)
	npc.need_rest   = randf_range(0.7, 1.0)
	npc.need_safety = randf_range(0.7, 1.0)
	npc.need_social = randf_range(0.7, 1.0)
	
	# Randomize stats
	npc.stat_strength     = randf_range(0.2, 0.8)
	npc.stat_endurance    = randf_range(0.2, 0.8)
	npc.stat_intelligence = randf_range(0.2, 0.8)
	npc.stat_charisma     = randf_range(0.2, 0.8)
	
	# Mood starts neutral with slight randomness
	npc.mood = randf_range(-0.1, 0.1)
	
	# Give each NPC a fresh inventory instance with some starting items
	npc.inventory  = NPCInventory.new()
	npc.equipment  = NPCEquipment.new()
	_give_starting_items(npc)
	
	return npc

# Generates a unique ID using a timestamp and random suffix.
# Example output: "npc_17291038472_k7x"
static func _generate_id() -> String:
	return "npc_%d_%s" % [Time.get_ticks_msec(), _random_suffix(3)]

# Returns a random float between -TRAIT_SPREAD and +TRAIT_SPREAD.
static func _random_trait() -> float:
	return randf_range(-TRAIT_SPREAD, TRAIT_SPREAD)

# Picks a random element from an Array.
static func _pick_random(array: Array) -> String:
	return array[randi() % array.size()]

# Generates a short random alphabetic suffix for IDs.
static func _random_suffix(length: int) -> String:
	const CHARS = "abcdefghijklmnopqrstuvwxyz"
	var result = ""
	for i in length:
		result += CHARS[randi() % CHARS.length()]
	return result

# Gives a newly generated NPC randomized starting skills.
# NPCs start with one slightly elevated skill reflecting their background.
# All other skills start near zero with tiny random variation.
static func _give_starting_skills(npc: NPCData) -> void:
	var all_skills := [
		"combat", "farming", "smithing", "trading",
		"cooking", "hunting", "construction", "medicine"
	]

	# Randomize all skills at a low baseline
	for skill_name in all_skills:
		npc.skills.set(skill_name, randf_range(0.0, 0.1))

	# Give one random skill a head start — this represents background
	var primary: String = all_skills[randi() % all_skills.size()]
	npc.skills.set(primary, randf_range(0.15, 0.35))

# Gives a newly generated NPC a small set of starting items.
static func _give_starting_items(npc: NPCData) -> void:
	# Food and coins have no material
	npc.inventory.add_item("item_bread",       randi_range(1, 3), npc.stat_strength)
	npc.inventory.add_item("item_coin_copper", randi_range(5, 20), npc.stat_strength)

	# Clothing uses cloth material
	npc.inventory.add_item("item_tunic",    1, npc.stat_strength, "mat_cloth")
	npc.inventory.add_item("item_trousers", 1, npc.stat_strength, "mat_cloth")
	npc.inventory.add_item("item_boots",    1, npc.stat_strength, "mat_leather")
	npc.inventory.add_item("item_hood",     1, npc.stat_strength, "mat_cloth")

	# Equip clothing
	npc.equipment.equip("item_tunic",    npc, "mat_cloth")
	npc.equipment.equip("item_trousers", npc, "mat_cloth")
	npc.equipment.equip("item_boots",    npc, "mat_leather")
	npc.equipment.equip("item_hood",     npc, "mat_cloth")
