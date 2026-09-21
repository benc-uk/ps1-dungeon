class_name LevelState

var loaded_ok: bool = false
var name = ""

var player_start: Vector2i = Vector2i.ZERO
var player_start_face = -1

enum CellType { FLOOR, WALL }
enum FeatureType { DOOR, BUTTON, SWITCH }
enum FeatureLoc { ALL, N, S, E, W, FLOOR }
##enum CellItems { POTION }
##enum CellActors { GOBLIN }

class Feature:
	var type: FeatureType
	var loc: FeatureLoc
	var active: bool
	
	func _init(t: FeatureType):
		self.type = t
	
class Cell:
	var type: CellType = CellType.WALL
	var features: Array[Feature] = []
	var blocks_move: bool = true

	func _init(t: CellType):
		self.type = t
		self.blocks_move = true if t == CellType.WALL else false

var cells: Dictionary[Vector2i, Cell] = {}

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
	
	for pos in layout.get_used_cells():
		var tile_data = layout.get_cell_tile_data(pos)
		var tile_type = tile_data.get_custom_data("tile_type")
		var cell
		if tile_type == 0: cell = Cell.new(CellType.FLOOR)
		if tile_type == 1: cell = Cell.new(CellType.WALL)
		if tile_type == 2: 
			cell = Cell.new(CellType.FLOOR)
			var door = Feature.new(FeatureType.DOOR)
			cell.features.append(door)
			cell.blocks_move = true
		cells[pos] = cell
	
	for cell_pos in markers.get_used_cells():
		var tile_data = markers.get_cell_tile_data(cell_pos)
		if tile_data.get_custom_data("is_player_start"):
			player_start = cell_pos
			player_start_face = tile_data.get_custom_data("player_start_face")
			
	print("Parsed %d cells" % cells.size())
	
	blueprint.free()
	loaded_ok = true

func is_walkable(cell: Vector2i) -> bool:
		return !cells[cell].blocks_move

func tile_at(cell: Vector2i) -> int:
		return cells.get(cell, Cell)
		
