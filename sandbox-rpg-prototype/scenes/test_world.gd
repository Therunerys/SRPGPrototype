# test_world.gd
extends Node

var _tracked_npc: NPCData

func _ready() -> void:
	RegionGenerator.generate_world(3, 5)
	WorldClock.on_hour_passed.connect(_on_hour_passed)

	# Track first NPC in a village
	var villages := RegionManager.get_regions_by_type(RegionData.Type.VILLAGE)
	if not villages.is_empty():
		var village: RegionData = villages[0]
		if not village.resident_ids.is_empty():
			_tracked_npc = NPCManager.get_npc(village.resident_ids[0])
			print("Tracking: %s (%s)" % [
				_tracked_npc.full_name,
				_tracked_npc.profession.get_primary_name()
			])

func _on_hour_passed() -> void:
	if _tracked_npc == null:
		return

	var poi := POIManager.get_poi(_tracked_npc.location.current_poi_id)
	var location_name := poi.poi_name if poi else "Travelling"

	print("[%s] %s | At: %s | Hunger: %.2f | Rest: %.2f | Safety: %.2f | Travelling: %s" % [
		WorldClock.get_timestamp(),
		_tracked_npc.full_name,
		location_name,
		_tracked_npc.need_hunger,
		_tracked_npc.need_rest,
		_tracked_npc.need_safety,
		str(_tracked_npc.location.is_travelling())
	])
