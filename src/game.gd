extends Node3D

var world_state: WorldState
var level_filename = "" # Populated when starting a new game or loading a level

# Called when the node enters the scene tree for the first time.
func _ready():
	# Load and parse the level file
	world_state = WorldState.new(level_filename)
	
	if not world_state.loaded_ok:
		push_error("Cannot start game: level '%s' failed to load." % level_filename)
		OS.alert("Cannot start game: level '%s' failed to load." % level_filename, "Level load failed")
		var title_scene := preload("res://title.tscn")
		var title := title_scene.instantiate()
		get_tree().root.add_child.call_deferred(title)
		queue_free()		
		return
				
	print("Building world...")
	var wall_scene = load("res://templates/map_cell.tscn")
	var door_scene = load("res://templates/map_door.tscn")
	var wall_button_scn = load("res://templates/map_button.tscn")
	var torch_scn = load("res://templates/map_torch.tscn")	
	
	for pos in world_state.cells:
		var cell = world_state.cells[pos]
		var inst = wall_scene.instantiate() as MapCell
		
		if cell.type == WorldState.CellType.FLOOR:
			inst.show_walls = false
		
		inst.position = Grid.cell_to_world(pos)
		$Map.add_child(inst)
		
		var feat
		for feat_dir in cell.wall_features:
			feat = world_state.get_feature(cell.wall_features[feat_dir])
			if feat != null && feat is WorldState.ButtonFeature:
				inst = wall_button_scn.instantiate()
				inst.position = Grid.cell_to_world(pos)
				inst.rotate_y(Grid.dir_to_angle(feat_dir))
				$Map.add_child(inst)	
				inst.bind(feat)
				
			# Create torches
			if feat != null && feat is WorldState.TorchFetaure:#
				print("adajhdsdjshdj")
				inst = torch_scn.instantiate()
				inst.position = Grid.cell_to_world(pos)
				$Map.add_child(inst)

		feat = world_state.get_feature(cell.main_feature)
		
		# Create doors
		if feat != null && feat is WorldState.DoorFeature:
			inst = door_scene.instantiate()
			inst.position = Grid.cell_to_world(pos)
			# Check if cell north of door is floor to orient it NS or EW
			if world_state.cells[Vector2i(pos.x, pos.y-1)].type == WorldState.CellType.WALL:
				inst.rotate_y(deg_to_rad(90))
			$Map.add_child(inst)
			inst.bind(feat)
			

	# Instantiate player
	var player_scene = load("res://player.tscn")
	var player = player_scene.instantiate() as Node3D
	player.world_state = world_state
	player.teleport(world_state.player_start, world_state.player_start_face)
	add_child(player)
	print("Player added at: ", world_state.player_start)
