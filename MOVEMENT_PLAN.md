# Implementation Plan: State Map + Player Movement

Classic grid-based first-person movement in a fully 3D world: whole-cell
steps and 90-degree turns, in the style of Dungeon Master and Eye of the
Beholder.

This plan reflects the current code and distinguishes implemented pieces
from remaining work. Phase numbers are retained; **Phase 3 is the current
focus**. Examples below describe changes to make, not changes already applied.

## Current design and responsibilities

| Component | Responsibility |
| --- | --- |
| `src\grid.gd` (`Grid`) | Direction and tile enums, step vectors, cell size and coordinate conversion |
| `src\level_state.gd` (`LevelState`) | Load the saved blueprint, hold cell and spawn data, answer terrain queries |
| `src\game.gd` | Create one `LevelState`, generate 3D cells and create the player |
| `src\player.gd` | Own logical cell/facing, handle input and move its own node |
| `game.tscn` > `Map` | Parent for generated cells; no separate map script required |
| `map_cell.tscn` / `MapCell` | Display one cell's walls, floor and ceiling |

`LevelState` is a plain `RefCounted` object, not a scene node or autoload.
GDScript defaults to `RefCounted` when no `extends` is specified. Its current
constructor loads the blueprint; this plan keeps that arrangement.

Game and Player share one `LevelState` instance. Player does not need a Game
reference, access to the scene-tree root or a copy of the terrain dictionary.
Keep `Global` out of this.

### Coordinates

- Grid coordinates are `Vector2i(x, z)`: the vector's `.y` is the dungeon's Z.
- `Grid.CELL_SIZE` is `1.0`.
- `Grid.cell_to_world(cell)` returns
  `Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)`.
- Despite its name, this helper produces level-local coordinates. Apply
	them to `position`, not `global_position`. Keep `Map`'s transform identity
	relative to Game so generated cells and the Player child use the same space.
- Player's root stays at Y = 0. Its camera/light parent already has a 0.5
  vertical offset. **Do not add eye height again when snapping or spawning.**

## Phase 0: Conventions and constants

**Implemented** in `src\grid.gd`:

- `class_name Grid`.
- `Grid.Dir`: `NORTH = 0`, `EAST = 1`, `SOUTH = 2`, `WEST = 3`.
- `Grid.Tile`: `FLOOR = 0`, `WALL = 1`, `DOOR = 2`.
- `Grid.CELL_SIZE`, `Grid.STEP` and static `Grid.cell_to_world()`.

North is negative Z. Clockwise turning increases the direction enum; target
yaw is `deg_to_rad(-90.0 * facing)`.

## Phase 1: Input actions

**Implemented.** Reuse the actual action names and bindings:

| Action | Keys |
| --- | --- |
| `move_forward` | W / Up |
| `move_backward` | S / Down |
| `turn_left` | A / Left |
| `turn_right` | D / Right |
| `strafe_left` | Q |
| `strafe_right` | E |

The backward action is singular: `move_backward`.

## Phase 2: Saved levels, state and generated cells

**Basic implementation exists.** Hand-maintained map arrays and hand-placed
3D cells are no longer the intended workflow.

### Authoring and loading

Levels are saved as `res://levels/<filename>.tscn`, currently including
`res://levels/tomb.tscn`. Each blueprint has a Node2D root with:

```text
Level root
├── Layout     TileMapLayer: walls, floors and doors
└── Markers    TileMapLayer: directional player-start tiles
```

Both layers use `levels\levels_tile_set.tres`. Its shared custom data is:

| Field | Meaning |
| --- | --- |
| `tile_type` | `Grid.Tile` value for terrain; `-1` for a spawn marker |
| `is_player_start` | Whether the tile marks the player spawn |
| `player_start_face` | `Grid.Dir` value, 0 through 3 |

There are four spawn-arrow tiles, one per direction. Custom data belongs to
the tile definition, not an individual painted cell. Paint the appropriate
arrow instead of adding Marker2D nodes or per-cell Inspector overrides.

The current flow is:

1. Title passes a level identifier such as `"tomb"` to Game.
2. Game constructs `LevelState.new(level_filename)`.
3. LevelState loads and instantiates the blueprint without adding it to the
   scene tree.
4. `Layout` supplies `data: Dictionary[Vector2i, int]`.
5. `Markers` supplies `player_start` and `player_start_face`. Read marker
   metadata from `markers.get_cell_tile_data()`, not from `layout`.
6. The blueprint root's name supplies `LevelState.name`.
7. Game generates a `MapCell` under `$Map` for each floor or wall cell.

### Runtime data and visuals

`LevelState` currently exposes:

- `name`, `data`, `player_start`, `player_start_face`.
- `is_walkable(cell)`: true for floor; missing cells and doors are blocked.
- `tile_at(cell)`: the stored type, with missing cells treated as walls.

For generated cells, `show_walls = true` means a solid wall cell;
`show_walls = false` leaves floor and ceiling. This is whole-cell terrain,
not neighbour-based edge-wall generation.

Game already creates the player at the marker's visual position and
rotation. Connecting its logical state and shared LevelState is Phase 3.

**Current gaps:** door cells are stored but skipped by the 3D generator.
Doors are not implemented. Blueprint cleanup and load validation remain
outstanding and are covered in Phase 5.

## Phase 3: Player logical state, instant snapping

**In progress.** Player already has `cell`, `facing`, a `level_state`
variable, `teleport()` and `_snap()`. Input handling and state injection
still need wiring. Prove the logic before adding animation.

### 3.1 Define and initialise player state

Add a class name for typed access from Game, and type the level reference:

```gdscript
class_name Player
extends Node3D

var cell: Vector2i
var facing: Grid.Dir
var level_state: LevelState

func teleport(c: Vector2i, f: Grid.Dir) -> void:
	cell = c
	facing = f
	_snap()

func _snap() -> void:
	position = Grid.cell_to_world(cell)
	rotation.y = deg_to_rad(-90.0 * facing)
```

Use local `position` so `teleport()` can run before `add_child()`. The
current `global_position` assignment should be replaced. The existing
`move_speed` variable is unnecessary for instant stepping.

In Game, replace the manual player position/rotation assignments with:

```gdscript
var player_scene := preload("res://player.tscn")
var player := player_scene.instantiate() as Player
player.level_state = level_state
player.teleport(
	level_state.player_start,
	level_state.player_start_face as Grid.Dir
)
add_child(player)
```

Game supplies the already-loaded instance, not a second `LevelState`.
The same spawn now sets both logical coordinates and the visual transform.
Adding Player to Game triggers its `_ready()`, so assign dependencies first.

Player requires a valid LevelState. If it is missing, report the setup error
with `push_error()` and disable movement processing; do not silently create
an empty level. Running `player.tscn` alone with F6 does not provide this
dependency.

### 3.2 Implement steps and turns

Direction comes from `Grid.STEP[facing]`, not the live camera basis.

```gdscript
func _try_step(direction: Vector2i) -> void:
	var target_cell := cell + direction
	if level_state.is_walkable(target_cell):
		cell = target_cell
		_snap()

func _turn(quarter_turns: int) -> void:
	facing = posmod(facing + quarter_turns, 4) as Grid.Dir
	_snap()
```

A blocked step makes no change. Turning changes facing but not the cell.
No physics body or collision shapes are required for these grid checks.

### 3.3 Read one action per press

Use edge-triggered input in `_physics_process()`. An `if`/`elif` chain
ensures simultaneous presses do not produce multiple actions in one tick.

```gdscript
func _physics_process(_delta: float) -> void:
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
```

Do not add held-key repeat, buffering, tweens or a movement state machine
in this phase.

### Phase 3 acceptance

- Spawn cell and facing match the painted marker before the first input.
- Each movement press changes the cell by exactly one cardinal step.
- Holding a key does not keep moving.
- Walls, unmapped cells and currently unsupported doors block movement.
- Strafing and backward movement preserve facing.
- Each turn changes facing by exactly 90 degrees; four turns restore it.
- The visual transform matches logical state after every accepted action.
- Eye height remains 0.5 above the cell floor, with no doubled offset.

## Phase 4: Animation and action state

**Not implemented.** Keep the Phase 3 state/query model and animate the
transform instead of instantly snapping it.

1. Add `IDLE`, `MOVING` and `TURNING` states. Only IDLE accepts input.
2. After validating a step, commit its logical destination, enter MOVING,
   and tween local `position` to `Grid.cell_to_world(cell)`.
3. For turns, commit logical facing, enter TURNING, and tween `rotation:y`
   from the current angle to that angle plus or minus `PI / 2`.
4. On completion, snap exactly to the logical transform and return to IDLE.

Do not tween directly between canonical direction angles at a wrap boundary:
west-to-north must animate a 90-degree turn, not a 270-degree turn.
Normalise to the canonical angle only when the turn finishes.

Export `step_duration` (start around 0.18 seconds) and `turn_duration`
(around 0.16 seconds). Keep only one movement tween active. Use physics-mode
tweens when keeping movement updates on physics ticks.

Blocked moves can simply do nothing. An optional bump animation needs a
busy state such as `BUMPING`; **do not remain IDLE while a bump tween runs**,
or another action can overlap it.

If teleporting during an action, kill its tween, update logical state,
snap and return to IDLE. Do not let an old tween overwrite the new position.

Acceptance: short, smooth steps and turns; no overlapping actions, long-way
turns or accumulated drift. Keep repeat/buffering and camera bob out of this
milestone.

## Phase 5: Level-loading validation and cleanup

**Remaining work.** Spawn wiring is now part of Phase 3 rather than a later
phase. Loading real level files and generating cells already exist.

- Free the temporary blueprint after copying both layers, including on
  validation-failure paths.
- Check required layers and custom-data fields before reading them.
- Validate terrain values and exactly one player-start marker.
- Validate facing is 0 through 3 and the spawn cell is walkable.
- Report errors explicitly and stop before generating a partial world.
  Returning from `_init()` does not cancel `LevelState.new()`; expose load
  validity so Game can refuse an invalid LevelState.
- Do not silently skip unsupported terrain. Until Phase 6, either use
  wall/floor-only test levels or explicitly reject levels containing doors.

Acceptance: malformed or unsupported levels produce a clear error, not an
empty or incomplete game. Temporary blueprint nodes are released.

## Phase 6: Doors and dynamic state

**Later.** Doors occupy a whole cell, not an edge between cells.

- Keep the terrain type in `LevelState.data`.
- Store per-cell open/closed state separately on LevelState.
- Extend `is_walkable()` to consult that state for `Grid.Tile.DOOR`.
- Generate a door visual and update it from the same state. An open door
  cell still has a floor and ceiling.
- Define what happens when closing a door on an occupied cell.

Runtime state belongs to each cell, not the shared TileSet definition.
Keep new gameplay systems out of Player and Global.

## Progress at a glance

| Phase | Deliverable | Current position |
| --- | --- | --- |
| 0 | Grid conventions and coordinate helper | Implemented |
| 1 | Six input actions | Implemented |
| 2 | Painted blueprints, LevelState and generated cells | Basic implementation exists |
| 3 | Logical spawn, instant steps and turns | Current focus |
| 4 | Tweened actions and busy states | Not implemented |
| 5 | Load validation and blueprint cleanup | Outstanding |
| 6 | Whole-cell doors and dynamic state | Later |

## Validation when implementing

After relevant code, scene or resource changes, run from the project root:

```powershell
& 'D:\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'D:\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --quit-after 30
```

Inspect errors and warnings, not just exit codes. The startup check does
not exercise input or confirm rendering.

Run F5 for movement and visual checks. Title currently starts `"tomb"` via
its debug `_ready()` path. Inspect **Remote > Game > Map** for generated
cells and **Remote > Game > Player** for the player, not the Local scene
tree, which shows the saved templates.

Updating this document alone does not require running Godot.
