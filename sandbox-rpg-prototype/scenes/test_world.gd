# test_world.gd
extends Node

func _ready() -> void:
	RegionGenerator.generate_world(3, 5)

	var all := NPCManager.get_all_npcs()
	for i in 5:
		var npc: NPCData = all[i]
		print("%s | Age: %d" % [npc.full_name, npc.age])
		var summary := npc.skills.get_summary()
		for skill_name in summary:
			print("  %s: %s (%.2f)" % [
				skill_name.capitalize(),
				summary[skill_name],
				npc.skills.get_value(skill_name)
			])
		print("---")
