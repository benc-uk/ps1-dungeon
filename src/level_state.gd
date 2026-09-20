class_name LevelState

var loaded_ok: bool = false
var name = ""
var data: Dictionary[Vector2i, int] = {}
var player_start: Vector2i = Vector2i.ZERO
var player_start_face = -1

func _init(filename: String) -> void:
	var path := "res://levels/%s.tscn" % filename
	print("Loading level data: ", path)
	var level_scene := load(path) as PackedScene
	if level_scene == null:
		push_error("Could not load level: %s" % path)
		return
		
	var blueprint := level_scene.instantiate()
	var layout := blueprint.get_node("Layout") as TileMapLayer
	var markers := blueprint.get_node("Markers") as TileMapLayer
	name = blueprint.name
	
	for cell_pos in layout.get_used_cells():
		var tile_data = layout.get_cell_tile_data(cell_pos)
		var tile_type = tile_data.get_custom_data("tile_type")
		data[cell_pos] = tile_type
	
	for cell_pos in markers.get_used_cells():
		var tile_data = markers.get_cell_tile_data(cell_pos)
		if tile_data.get_custom_data("is_player_start"):
			player_start = cell_pos
			player_start_face = tile_data.get_custom_data("player_start_face")
			
	blueprint.free()
	loaded_ok = true

func is_walkable(cell: Vector2i) -> bool:
		return data.has(cell) and data[cell] == Grid.Tile.FLOOR

func tile_at(cell: Vector2i) -> int:
		return data.get(cell, Grid.Tile.WALL)
		
