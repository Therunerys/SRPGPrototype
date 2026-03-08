# test_world.gd
extends Node

var _tracked_npc: NPCData

func _ready() -> void:
	RegionGenerator.generate_world(3, 5)
	WorldClock.on_hour_passed.connect(_on_hour_passed)

	var villages := RegionManager.get_regions_by_type(RegionData.Type.VILLAGE)
	if not villages.is_empty():
		var village: RegionData = villages[0]
		
		# Move player to this village so NPCs become ACTIVE and PRESENT
		NPCTravelSystem.set_player_position(village.world_position)
		
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

	print("[%s] %s | At: %s | Hunger: %.2f | Rest: %.2f | LOD: %s" % [
		WorldClock.get_timestamp(),
		_tracked_npc.full_name,
		location_name,
		_tracked_npc.need_hunger,
		_tracked_npc.need_rest,
		NPCLocation.LODZone.keys()[_tracked_npc.location.lod_zone]
	])
