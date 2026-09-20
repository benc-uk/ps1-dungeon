extends Node3D

var level_state: LevelState
var level_filename = "" # Populated when starting a new game or loading a level

# Called when the node enters the scene tree for the first time.
func _ready():
	# Load and parse the level file
	level_state = LevelState.new(level_filename)
	
	if not level_state.loaded_ok:
		push_error("Cannot start game: level '%s' failed to load." % level_filename)
		OS.alert("Cannot start game: level '%s' failed to load." % level_filename, "Level load failed")
		var title_scene := preload("res://title.tscn")
		var title := title_scene.instantiate()
		get_tree().root.add_child.call_deferred(title)
		queue_free()		
		return
				
	print("Parsing...")
	var wall_scene = load("res://map_cell.tscn")
	for cell_pos in level_state.data:
		var tile_type = level_state.data[cell_pos]
		if tile_type == Grid.Tile.FLOOR || tile_type == Grid.Tile.WALL: 
			var wall = wall_scene.instantiate() as MapCell
			if tile_type == Grid.Tile.FLOOR:
				wall.show_walls = false
				
			wall.position = Vector3(
				cell_pos.x * Grid.CELL_SIZE,
				0.0,
				cell_pos.y * Grid.CELL_SIZE
			)
			$Map.add_child(wall)
			

	var player_scene = load("res://player.tscn")
	var player = player_scene.instantiate() as Node3D
	player.level_state = level_state
	player.teleport(
			level_state.player_start,
			level_state.player_start_face
	)
	add_child(player)
				
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
