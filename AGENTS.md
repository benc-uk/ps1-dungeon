# Agent instructions

## Project

This is **Dungeoneer '95**, an early first-person grid crawler built with
**Godot 4.7**, GDScript and the **GL Compatibility** renderer. The current
project uses a 320x240 viewport, integer scaling, nearest-neighbour texture
filtering and a PS1-style output shader.

- Use Godot 4.7 APIs and documentation. Do not introduce Godot 3 syntax,
  classes or shader built-ins.
- Keep the Compatibility renderer and existing Jolt physics configuration
  unless the task explicitly requires changing them.
- Prefer small, understandable, native Godot solutions. Do not introduce
  plugins, dependencies, frameworks or general-purpose systems unnecessarily.
- The developer knows software development but is learning Godot. Explain
  non-obvious engine concepts briefly and relate them to this project.
- Treat conceptual questions as discussion, not permission to modify files.
  Respect explicit requests to make no change.

## Current project structure

This is a snapshot, not a substitute for reading the files before changing
them. The prototype is evolving quickly; confirm current scene paths,
properties, node names and behaviour in code.

| Path | Responsibility |
| --- | --- |
| `project.godot` | Godot 4.7 project settings, title main scene, `Global` autoload, input actions, 320x240 viewport, GL Compatibility and Jolt Physics |
| `title.tscn`, `src\title.gd` | Title menu; New Game starts the `"tomb"` level, and the music toggle controls title music |
| `game.tscn`, `src\game.gd` | Runtime game root, generated `Map`, music, post-process shader and pause HUD |
| `levels\*.tscn`, `levels\levels_tile_set.tres` | Authored level blueprints using `Layout` and `Markers` `TileMapLayer` nodes and shared tile custom data |
| `src\world_state.gd` | `WorldState` data model; parses a level blueprint into cells, features and player start data, and answers walkability queries |
| `src\grid.gd` | Cardinal directions, step vectors and cell-to-world conversion |
| `templates\map_cell.tscn`, `src\map_cell.gd` | Generated cell visuals; `show_walls` controls the wall mesh |
| `templates\map_door.tscn`, `src\map_door.gd` | Door visual bound to a `WorldState.DoorFeature` |
| `templates\map_button.tscn`, `templates\map_torch.tscn` | Wall-feature visuals |
| `player.tscn`, `src\player.gd` | Player node, camera and lights; grid movement, turning, interaction and footstep audio |
| `misc\ps1_output.gdshader` | PS1-style output shader used by the game scene |
| `src\global.gd` | `Global` autoload; creates and installs a resized custom mouse cursor |

## Current behaviour and architecture

- `project.godot` starts at `title.tscn`. The title currently presents its
  menu; `_ready()` focuses New Game rather than starting a debug game.
- `src\title.gd` starts `"tomb"` when New Game is selected. It assigns
  `level_filename` to a new Game instance before adding it to the scene tree.
- `Game` constructs one `WorldState`, creates map and feature visuals from its
  cells, then injects that same state into Player and calls `teleport()` before
  adding Player to the tree.
- A level blueprint is a `Node2D` with `Layout` and `Markers` `TileMapLayer`
  children. The shared TileSet defines `tile_type`, `is_player_start` and
  `player_start_face` custom data. `WorldState` parses those layers; do not
  assume the authored map is a hand-placed collection of 3D cells.
- `WorldState` is a plain reference-counted data object, not a scene node or
  autoload. It owns the parsed map cells and feature objects. Player currently
  owns its logical position and facing as well as its movement animation.
- `WorldState` includes door features and supports button-to-feature action
  links. It also contains hard-coded button and torch placements used for
  testing; treat them as test code, not a general level-authoring mechanism.
- Player is a `Node3D`, not a `CharacterBody3D`. It moves by tweening its
  transform and checks `WorldState.is_walkable()` before stepping. Do not
  assume player movement uses collision shapes or physics.
- Movement and turn actions are edge-triggered. A single action can be
  buffered while the player is moving or turning. Current durations are
  0.9 seconds per step and 0.6 seconds per turn; do not assume the shorter
  durations described in older planning notes.
- The right controller stick adjusts the camera container's head-look angles.
- The game scene applies `misc\ps1_output.gdshader`; the title scene contains
  the shader surface but its post-process layer is hidden.
- The pause input currently toggles the pause HUD and a local flag. Inspect
  `src\game.gd` before assuming the SceneTree or Player is actually paused.
- `Global` handles cursor setup only. Keep unrelated game state out of it.

Input actions currently declared in `project.godot` include:

| Action | Keyboard |
| --- | --- |
| `move_forward` | W / Up |
| `move_backward` | S / Down |
| `turn_left` | A / Left |
| `turn_right` | D / Right |
| `strafe_left` | Q |
| `strafe_right` | E |
| `interact` | Space |
| `pause` | Escape |

The actions also have controller bindings. Reuse the current action names;
in particular, the movement action is `move_backward`, not
`move_backwards`.

## Godot implementation rules

- Godot owns the game loop. Use `_ready()` for scene setup,
  `_physics_process(delta)` for movement and physics, and `_process(delta)`
  for frame-based visual updates. Do not manually drive other nodes'
  lifecycle callbacks.
- Use saved scenes as reusable templates: load or preload a `PackedScene`,
  call `instantiate()`, configure it, then add it to the appropriate parent.
- Keep responsibilities local: Player behaviour in the player script, cell
  behaviour in the cell script, level coordination in Game and map data and
  feature state in `WorldState`.
- Use exported properties for values designers need to edit in the Inspector.
  Prefer explicit types for new GDScript where practical, without reformatting
  or rewriting unrelated existing code.
- Use tabs for GDScript indentation, `snake_case` for variables and functions,
  and `PascalCase` for node and class names.
- Preserve scene node paths used by scripts. Update scripts, scene references
  and signal connections together when renaming or restructuring nodes.
- Inspect the containing scene as well as the referenced scene before changing
  a reusable resource. Instance property overrides and shared materials matter.
  Use per-instance overrides or duplicate resources when a change must not
  affect every instance.
- If adding collision, keep it consistent with walkability. Hiding a wall mesh
  does not disable a collision shape.
- Surface load, parse and invalid-data errors explicitly. Avoid silent
  fallbacks that leave an apparently successful but incomplete level.

## Grid movement

- Grid coordinates are `Vector2i(x, z)`, represented by `Vector2i(x, y)` in
  GDScript. North is negative Z. Use `Grid.STEP`, `Grid.cell_to_world()` and
  the logical direction rather than deriving gameplay movement from the
  camera's interpolating transform.
- Keep player logical position and facing separate from its animated
  transform. The current Player script uses `pos`, `facing`, a current cell
  reference and a movement state; `WorldState` owns map cells and features.
- Check `WorldState.is_walkable()` for movement. Missing cells and blocked
  cells must not become enterable because a visual wall is hidden.
- Preserve the current tween/state behaviour when changing movement. Input is
  buffered while an action is active, so do not describe or implement it as
  idle-only without intentionally changing that behaviour.
- Player is intentionally a `Node3D`; grid movement does not require
  `CharacterBody3D` or physics. Use physics only for features that genuinely
  need it.
- The current camera-container look is a separate controller-stick behaviour.
  Do not let it change the logical grid facing.

## Visual direction and scope

- Preserve nearest-neighbour filtering, integer viewport scaling, the
  Compatibility renderer and the existing retro visual direction.
- The current project already has a low-resolution viewport and a PS1-style
  output shader. Inspect `misc\ps1_output.gdshader` and its scene usage before
  adding or changing post-processing.
- Keep shaders compatible with Godot's Compatibility renderer. Do not assume
  Forward+ or compute-shader features are available.
- Simple geometry is appropriate at the current scale. Do not introduce
  custom exposed-face meshing, chunking or a separate node for every quad
  merely as speculative optimisation. Measure a problem before adding that
  complexity.

## Safe editing

- Make focused changes and preserve unrelated work and editor-authored layout.
  Do not fix unrelated prototype gaps or remove debugging behaviour silently.
- Preserve resource UIDs, script `.uid` sidecars, scene instance overrides and
  asset import settings. Let Godot generate new UIDs rather than inventing them.
- Prefer resource moves through the editor when available. Otherwise update
  all affected paths and references, then let Godot reimport and check them.
- Use `res://` resource paths in game code, not machine-specific filesystem
  paths. Keep names and path casing exact for cross-platform exports.
- Never hand-edit or add generated `.godot` cache contents to source control.
- Do not rewrite whole `.tscn`, `.tres` or `project.godot` files for small edits.
  Preserve unrelated settings and Godot's serialised resource structure.

## Validation

There is currently no checked-in automated test suite or external build
system. Do not invent an npm, .NET or other unrelated build step.

With a Godot 4.7 executable available, run these from the project root after
relevant code, scene or resource changes:

```powershell
godot --headless --path . --editor --import
godot --headless --path . --quit-after 30
```

Use the installed executable's actual name or path if it is not on `PATH`.
Inspect output for script, resource and scene errors, not just the exit code.
The second command is a startup smoke check, not a complete gameplay test.
Distinguish pre-existing errors from errors introduced by the change.

Use **F5** to run the project and **F6** to run the scene being edited. For
visual, input or UI changes, also run with graphics enabled and inspect the
affected behaviour. Headless execution alone cannot confirm rendering or
user interaction.

Keep documentation-only work to documentation. Do not launch or rewrite the
project merely to validate prose. State any validation limitations honestly.
