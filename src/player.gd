extends Node3D

const step_duration: float = 0.9
const turn_duration: float = 0.6
const move_speed: float = 1.0 

const look_max_yaw: float = deg_to_rad(18.0)
const look_max_pitch: float = deg_to_rad(12.0)
const look_deadzone: float = 0.2
const look_return_speed: float = 8.0

var pos: Vector2i
var cell: WorldState.Cell = null
var facing: Grid.Dir
var world_state: WorldState

enum State { IDLE, MOVING, TURNING }
var state: State = State.IDLE
var movement_tween: Tween
var buffered_action: StringName = &""

func _ready():
	pass
		
func _physics_process(delta: float):
	_update_head_look(delta)

	if state != State.IDLE:
		var action := _read_action()
		if action != &"": buffered_action = action
		return 

	var action := _read_action()
	if action != &"":
		_do_action(action)

func _read_action() -> StringName:
	if Input.is_action_just_pressed("move_forward"): return &"move_forward"
	if Input.is_action_just_pressed("move_backward"): return &"move_backward"
	if Input.is_action_just_pressed("turn_left"): return &"turn_left"
	if Input.is_action_just_pressed("turn_right"): return &"turn_right"
	if Input.is_action_just_pressed("strafe_left"): return &"strafe_left"
	if Input.is_action_just_pressed("strafe_right"): return &"strafe_right"
	if Input.is_action_just_pressed("interact"): return &"interact"
	return &""

func _do_action(action: StringName):
	match action:
		&"move_forward": _try_step(Grid.STEP[facing])
		&"move_backward": _try_step(-Grid.STEP[facing])
		&"turn_left": _turn(-1)
		&"turn_right": _turn(1)
		&"strafe_left": _try_step(Grid.STEP[(facing + 3) % 4])
		&"strafe_right": _try_step(Grid.STEP[(facing + 1) % 4])
		&"interact": _interact()
		
func _update_head_look(delta: float):
	var look_x := _apply_deadzone(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), look_deadzone)
	var look_y := _apply_deadzone(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y), look_deadzone)

	# Absolute offset from the stick: a centred stick targets zero, so the
	# head eases back to the default orientation on its own.
	var target_yaw := -look_x * look_max_yaw
	var target_pitch := -look_y * look_max_pitch

	# Frame-rate independent smoothing toward the target angles.
	var weight := 1.0 - exp(-look_return_speed * delta)
	$Container.rotation.y = lerp_angle($Container.rotation.y, target_yaw, weight)
	$Container.rotation.x = lerp($Container.rotation.x, target_pitch, weight)

func _apply_deadzone(value: float, deadzone: float) -> float:
	if absf(value) < deadzone:
		return 0.0
	# Rescale so motion starts from zero at the deadzone edge, no sudden jump.
	return signf(value) * (absf(value) - deadzone) / (1.0 - deadzone)

func teleport(p: Vector2i, f: Grid.Dir):
	if movement_tween != null:
		movement_tween.kill()
		movement_tween = null

	pos = p
	facing = f
	cell = world_state.cells[pos]
	state = State.IDLE
	_snap()

func _snap():
	position = Grid.cell_to_world(pos)
	rotation.y = deg_to_rad(facing * -90.0)
	#print("SNAP TO", pos, " ", facing as Grid.Dir)
		
func _try_step(direction: Vector2i):
	if !world_state:
		return
		
	var target_pos := pos + direction

	if not world_state.is_walkable(target_pos):
		return

	pos = target_pos
	cell = world_state.cells[target_pos]
	state = State.MOVING

	movement_tween = create_tween()
	movement_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	movement_tween.tween_property(
		self,
		"position",
		Grid.cell_to_world(pos),
		step_duration
	)
	movement_tween.finished.connect(_finish_action)
	_play_footstep()
	movement_tween.parallel().tween_callback(_play_footstep).set_delay(step_duration * 0.5)
	
func _play_footstep():
		$FootstepSfx.pitch_scale = randf_range(0.8, 1.2)
		$FootstepSfx.play()

func _turn(quarter_turns: int):
	var target_yaw := rotation.y - quarter_turns * PI / 2.0

	facing = posmod(facing + quarter_turns, 4) as Grid.Dir
	state = State.TURNING

	movement_tween = create_tween()
	movement_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(
		self,
		"rotation:y",
		target_yaw,
		turn_duration
	)
	movement_tween.finished.connect(_finish_action)
		
func _interact():
	if not cell.wall_features.has(facing):
		return
			
	var feature: WorldState.Feature = world_state.get_feature(cell.wall_features[facing])
	if feature != null:
		world_state.interact_feature(feature.id)
	
func _finish_action():
	_snap()
	movement_tween = null
	state = State.IDLE
	if buffered_action != &"":
		var next := buffered_action
		buffered_action = &""
		_do_action(next)
