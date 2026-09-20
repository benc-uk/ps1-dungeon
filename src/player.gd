extends Node3D

const step_duration: float = 0.9
const turn_duration: float = 0.6
const move_speed: float = 1.0

var cell: Vector2i
var facing: Grid.Dir
var level_state: LevelState

enum State { IDLE, MOVING, TURNING }
var state: State = State.IDLE
var movement_tween: Tween

func _ready():
	pass
		
func _physics_process(_delta: float) -> void:
	if state != State.IDLE:
		return
		
	if Input.is_action_just_pressed("move_forward"):
		_try_step(Grid.STEP[facing])
	elif Input.is_action_just_pressed("move_backward"):
		_try_step(-Grid.STEP[facing])
	elif Input.is_action_just_pressed("turn_left"):
		_turn(-1)
	elif Input.is_action_just_pressed("turn_right"):
		_turn(1)	
	elif Input.is_action_just_pressed("strafe_left"):
		_try_step(Grid.STEP[(facing + 3) % 4])
	elif Input.is_action_just_pressed("strafe_right"):
		_try_step(Grid.STEP[(facing + 1) % 4])		
			
func teleport(c: Vector2i, f: Grid.Dir) -> void:
	if movement_tween != null:
		movement_tween.kill()
		movement_tween = null

	cell = c
	facing = f
	state = State.IDLE
	_snap()


func _snap() -> void:
	position = Grid.cell_to_world(cell)
	rotation.y = deg_to_rad(facing * -90.0)
		
func _try_step(direction: Vector2i) -> void:
	if !level_state:
		return
		
	var target_cell := cell + direction

	if not level_state.is_walkable(target_cell):
		return

	cell = target_cell
	state = State.MOVING

	movement_tween = create_tween()
	movement_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	movement_tween.tween_property(
		self,
		"position",
		Grid.cell_to_world(cell),
		step_duration
	)
	movement_tween.finished.connect(_finish_action)
	_play_footstep()
	movement_tween.parallel().tween_callback(_play_footstep).set_delay(
			step_duration * 0.5
	)
	
func _play_footstep() -> void:
		$FootstepSfx.pitch_scale = randf_range(0.8, 1.2)
		$FootstepSfx.play()

func _turn(quarter_turns: int) -> void:
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
		
func _finish_action() -> void:
	_snap()
	movement_tween = null
	state = State.IDLE
