@tool
extends SceneTree
func _init() -> void:
	for path in [
		"res://entities/ring_avatar/ring_avatar.tscn",
		"res://resources/tiles/cave_rock.tres",
		"res://resources/tiles/floor_stone.tres",
		"res://entities/minion/minion.tscn",
		"res://world/starter_dungeon.tscn",
	]:
		var r = load(path)
		print(path, " -> ", r != null)
	quit()
