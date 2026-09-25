class_name WorldState

var loaded_ok: bool = false
var name = ""

var player_start: Vector2i = Vector2i.ZERO
var player_start_face = -1
var cells: Dictionary[Vector2i, Cell] = {}
var features: Dictionary[StringName, Feature] = {}

enum CellType { FLOOR, WALL }
enum FeatureType { DOOR, BUTTON, SWITCH, FLOORPLATE, PIT_TRAP }

enum FeatureAction {
	OPEN,
	CLOSE,
	TOGGLE,
	ACTIVATE,
	DEACTIVATE,
	TRIGGER,
	RESET,
}

class FeatureActionLink:
	var target_id: StringName
	var target: Feature
	var action: FeatureAction
	
class Feature:
	extends RefCounted
	signal state_changed
	signal activated
	var id: StringName
	var action_links: Array[FeatureActionLink] = []
	
	func blocks_move() -> bool:
		return false
		
	func _init(i: StringName) -> void:
		id = i

	func apply_action(action: FeatureAction) -> void:
		print("Im ", self.id, " applied this action: ", FeatureAction.find_key(action))
		push_error("Feature '%s' does not support action %s." % [id, action])
		
	func interact():
		for action_link in action_links:

			if action_link.target == null:
				push_error("Feature '%s' targets unknown feature '%s'." % [id, action_link.target_id])
				continue

			action_link.target.apply_action(action_link.action)
		
class TorchFetaure:
	extends Feature
	
class ButtonFeature:
	extends Feature
	
	func interact():
		activated.emit()
		super()
	
class DoorFeature:
	extends Feature
	
	enum State { CLOSED, OPEN, LOCKED }
	var state: State = State.CLOSED
	
	func apply_action(action: FeatureAction) -> void:
		match action:
			FeatureAction.OPEN: open()
			FeatureAction.CLOSE: close()
			FeatureAction.TOGGLE:
				if state == State.OPEN:
					close()
				else:
					open()
				
	func blocks_move() -> bool:
		return state != State.OPEN
		
	func open() -> void:
		if state == State.LOCKED:
			return

		if state != State.OPEN:
			state_changed.emit(State.OPEN)
			
		state = State.OPEN

	func close() -> void:
		state = State.CLOSED
		state_changed.emit(state)

# ============================
class Cell:
	var type: CellType = CellType.WALL
	var wall_features: Dictionary[Grid.Dir, StringName] = {}
	var main_feature: StringName = &""
	var blocks_move: bool = true

	func _init(t: CellType):
		self.type = t
		self.blocks_move = true if t == CellType.WALL else false

# ============================
func _init(filename: String):
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
			var door_id := StringName("door_%d_%d" % [pos.x, pos.y])
			var door := DoorFeature.new(door_id)
			_register_feature(door)
			cell.main_feature = door.id
		
		# !! HACK TO TEST BUTTONS
		if pos.x == 1 && pos.y == 6: 
			var btn := ButtonFeature.new("btn1")
			_register_feature(btn)
			cell.wall_features[Grid.Dir.EAST] = btn.id
			btn.action_links.append(_new_action_link("door_2_5", FeatureAction.TOGGLE))
			
		# !! HACK TO TEST TORCHS
		if pos.x == 1 && pos.y == 3: 
			var t := TorchFetaure.new("t1")
			_register_feature(t)
			cell.wall_features[Grid.Dir.WEST] = t.id
		if pos.x == 5 && pos.y == 6: 
			var t := TorchFetaure.new("t2")
			_register_feature(t)
			cell.wall_features[Grid.Dir.WEST] = t.id
			
		cells[pos] = cell

	# Record player start pos and facing
	for cell_pos in markers.get_used_cells():
		var tile_data = markers.get_cell_tile_data(cell_pos)
		if tile_data.get_custom_data("is_player_start"):
			player_start = cell_pos
			player_start_face = tile_data.get_custom_data("player_start_face")
			
	print("Parsed %d cells" % cells.size())
	
	blueprint.free()
	_resolve_action_links()
	loaded_ok = true

func _register_feature(feature: Feature) -> bool:
	if feature.id == &"":
		push_error("Cannot register a feature with an empty ID.")
		return false

	if features.has(feature.id):
		push_error("Duplicate feature ID: %s" % feature.id)
		return false

	features[feature.id] = feature
	return true

func _resolve_action_links() -> void:
	for feat in features.values():
		for link in feat.action_links:
			link.target = get_feature(link.target_id)
			if link.target == null:
				push_error("Feature '%s' targets unknown feature '%s'." % [feat.id, link.target_id])

func interact_feature(feature_id: StringName):
	var feat := features.get(feature_id) as Feature

	if feat == null:
		push_error("Cannot interact with unknown feature: %s" % feature_id)
		return

	feat.interact()

func _new_action_link(target_id: StringName, action: FeatureAction) -> FeatureActionLink:
	var link = FeatureActionLink.new()
	link.target_id = target_id
	link.action = action
	return link
	
func get_feature(feature_id: StringName) -> Feature:
	return features.get(feature_id)

#func get_main_feature(cell_pos: Vector2i) -> Feature:
	#var feature_id := cells[cell_pos].main_feature
	#return features.get(feature_id)
#
#func get_wall_feature(cell_pos: Vector2i, dir: Grid.Dir) -> Feature:
	#var cell := cells[cell_pos]
	#if not cell.wall_features.has(dir):
		#return null
	#return features.get(cell.wall_features[dir])
	
func is_walkable(cell: Vector2i) -> bool:
	var c := cells.get(cell) as Cell
	if c == null: return false
	if c.blocks_move: return false
	var feat = get_feature(c.main_feature)
	if feat != null and feat.blocks_move(): return false
	return true
