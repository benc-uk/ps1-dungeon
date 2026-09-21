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
				
	print("Parsing level state...")
	var wall_scene = load("res://templates/map_cell.tscn")
	var door_scene = load("res://templates/map_door.tscn")
	for pos in level_state.cells:
		var cell = level_state.cells[pos]
		var inst = wall_scene.instantiate() as MapCell
		if cell.type == LevelState.CellType.FLOOR:
			inst.show_walls = false
		
		inst.position = Grid.cell_to_world(pos)
		$Map.add_child(inst)	
		
		for feat in cell.features:
			if feat.type == LevelState.FeatureType.DOOR:
				inst = door_scene.instantiate() as MapDoor
				inst.position = Grid.cell_to_world(pos)
				if level_state.cells[Vector2i(pos.x, pos.y-1)].type == LevelState.CellType.WALL:
					inst.rotate_y(deg_to_rad(90))
				$Map.add_child(inst)	

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
