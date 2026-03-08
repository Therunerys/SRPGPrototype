# npc_data.gd
# Resource that holds all data for a single NPC.
# Contains no logic — it is a pure data container (the "character sheet").
# Attach this to any NPC node or store it in NPCManager.

class_name NPCData
extends Resource

# ─── IDENTITY ─────────────────────────────────────────────────────────────────

@export var npc_id: String = ""          # Unique identifier (assigned at creation)
@export var full_name: String = ""
@export var age: int = 0
@export var faction_id: String = ""      # References a Faction resource by ID
@export var home_region_id: String = ""  # Region the NPC was born/lives in

# ─── TRAITS ───────────────────────────────────────────────────────────────────
# Personality values. Range: -1.0 (low) to 1.0 (high).
# These shift slowly over time based on life events (see emotional_log).

@export var trait_courage: float = 0.0      # High = brave, Low = cowardly
@export var trait_greed: float = 0.0        # High = materialistic, Low = selfless
@export var trait_empathy: float = 0.0      # High = compassionate, Low = callous
@export var trait_aggression: float = 0.0   # High = violent, Low = passive
@export var trait_ambition: float = 0.0     # High = driven, Low = content

# ─── NEEDS ────────────────────────────────────────────────────────────────────
# Current fulfilment level for each need. Range: 0.0 (starving) to 1.0 (satisfied).
# Needs decay over time and must be met through actions.

@export var need_hunger: float = 1.0     # Drops if NPC hasn't eaten
@export var need_rest: float = 1.0       # Drops if NPC hasn't slept
@export var need_safety: float = 1.0     # Drops if NPC is in danger
@export var need_social: float = 1.0     # Drops if NPC is isolated

# ─── STATS ────────────────────────────────────────────────────────────────────
# Capability values that affect how well actions are performed.
# Range: 0.0 (terrible) to 1.0 (exceptional). Set at creation, change rarely.

@export var stat_strength: float = 0.5
@export var stat_endurance: float = 0.5
@export var stat_intelligence: float = 0.5
@export var stat_charisma: float = 0.5

# ─── SKILLS ───────────────────────────────────────────────────────────────────
# What this NPC is good at. Initialized by NPCGenerator.
@export var skills: NPCSkills

# ─── EMOTIONAL STATE ──────────────────────────────────────────────────────────
# Current mood influences decision-making and dialogue.
# mood: -1.0 (miserable) to 1.0 (elated)

@export var mood: float = 0.0

# Log of significant life events. Each entry is a Dictionary:
# { "event": "spouse_died", "timestamp": 1040, "weight": -0.8 }
# "weight" represents how positive or negative the event was.
# This log is used to shift traits and mood over time.
@export var emotional_log: Array[Dictionary] = []

# ─── RELATIONSHIPS ────────────────────────────────────────────────────────────
# Maps another NPC's npc_id to a relationship score.
# Range: -1.0 (enemy) to 1.0 (loved one).
# Example: { "npc_042": 0.9, "npc_017": -0.6 }
@export var relationships: Dictionary = {}

# ─── INVENTORY ────────────────────────────────────────────────────────────────
# Each NPC carries their own inventory instance.
# Initialized by NPCGenerator when the NPC is created.
@export var inventory: NPCInventory

# ─── EQUIPMENT ────────────────────────────────────────────────────────────────
# What the NPC currently has equipped.
# Initialized by NPCGenerator when the NPC is created.
@export var equipment: NPCEquipment

# ─── PROFESSION ───────────────────────────────────────────────────────────────
# What this NPC does for a living.
# Initialized by NPCGenerator when the NPC is created.
@export var profession: NPCProfession

# ─── LOCATION ─────────────────────────────────────────────────────────────────
@export var location: NPCLocation

# The POI this NPC calls home. They will always return here to sleep.
# Assigned at generation by RegionGenerator. Never changes unless
# the NPC moves regions (migration system, future feature).
@export var home_poi_id: String = ""
