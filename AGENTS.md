# Agent instructions

## Project

This is **PS1 Dungeon**, an early-stage first-person dungeon crawler built
with **Godot 4.7**, GDScript and the **GL Compatibility** renderer.
The intended look is deliberately retro: low-resolution textures,
nearest-neighbour filtering and simple geometry.

- Use Godot 4.7 APIs and documentation. Do not introduce Godot 3 syntax,
  classes or shader built-ins.
- Keep the Compatibility renderer and existing Jolt physics configuration
  unless the task explicitly requires changing them.
- Prefer small, understandable, native Godot solutions. Do not introduce
  plugins, dependencies, frameworks or general-purpose systems unnecessarily.
- The developer knows software development but is learning Godot. Explain
  non-obvious engine concepts briefly and relate them to the actual project.
- Treat conceptual questions as discussion, not permission to modify files.
  Respect explicit requests to make no change.

## Current structure

Read the current files before editing. This prototype is evolving quickly;
do not assume previously discussed features have been implemented.

| Path                               | Responsibility                                                  |
| ---------------------------------- | --------------------------------------------------------------- |
| `project.godot`                    | Project settings, main scene, autoloads and input actions       |
| `title.tscn`, `src\title.gd`       | Entry scene, level selection and creation of the game scene     |
| `game.tscn`, `src\game.gd`         | Game root, manually placed map cells and player instance        |
| `map_cell.tscn`, `src\map_cell.gd` | Reusable cell containing walls, floor and ceiling               |
| `player.tscn`, `src\player.gd`     | First-person camera, lights and basic forward/backward movement |
| `src\light_flicker.gd`             | Noise-driven torch light animation                              |
| `src\global.gd`                    | `Global` autoload, currently an empty `Node` script             |
| `materials`, `textures`, `fonts`   | Shared materials and source assets                              |

Important current behaviour:

- The main-scene UID in `project.godot` resolves to `title.tscn`.
  Its `_ready()` currently starts a debug game immediately, bypassing normal
  interaction with the title menu.
- The title script assigns `level_filename` and `level_name` to the new game
  instance before adding it to the scene tree. `game.gd` currently only logs
  those values; the listed level scene paths are placeholders.
- The dungeon currently uses manually placed `map_cell.tscn` instances.
  Loading a 2D map and generating cells is a planned direction, not an
  existing map loader to extend.
- Cells have a one-unit footprint, with floor at Y = 0 and ceiling at Y = 1.
  Walls use a `BoxMesh`; floor and ceiling use `PlaneMesh` resources.
  `src\map_cell.gd` is an `@tool` script: `show_walls` updates wall visibility
  both in the editor and at runtime. Its setter waits for node readiness;
  `_ready()` applies values assigned while the scene was being instantiated.
- `Player` is currently a `Node3D`, not a `CharacterBody3D`. Movement directly
  updates its position. There are no player or map-cell collision shapes.
  Do not claim collision handling already exists.
- The current `player.gd` applies continuous, held-key translation derived
  from the live camera basis. This is placeholder movement, not the intended
  model. The target design is grid based (see "Movement and controls").
- Existing input actions are `move_forward` and `move_backwards`, mapped to
  W/Up and S/Down respectively. Reuse these names. Turn and strafe actions
  (for example `turn_left`, `turn_right`, `strafe_left`, `strafe_right`) do
  not exist yet and should be added when grid movement is implemented.
- There is currently no low-resolution render target, dithering shader or
  colour-quantisation pass. Nearest texture filtering is already configured.

## Godot implementation rules

- Godot owns the game loop. Use `_ready()` for scene setup,
  `_physics_process(delta)` for movement and physics, and `_process(delta)`
  for frame-based visual updates. Do not manually drive other nodes'
  lifecycle callbacks.
- Use saved scenes as reusable templates: load or preload a `PackedScene`,
  call `instantiate()`, configure it, then add it to the appropriate parent.
- Keep responsibilities local: player behaviour in the player script,
  cell behaviour in the cell script and level coordination in the game.
  Do not turn the `Global` autoload into a container for unrelated logic.
- Use exported properties for values designers need to edit in the Inspector.
  Prefer explicit types for new GDScript where practical, without reformatting
  or rewriting unrelated existing code.
- Use tabs for GDScript indentation, `snake_case` for variables and functions,
  and `PascalCase` for node and class names.
- Preserve scene node paths used by scripts, such as `$Node3D/Walls`.
  Update scripts, scene references and signal connections together when
  renaming or restructuring nodes.
- Inspect the containing scene as well as the referenced scene before changing
  a reusable resource. Instance property overrides and shared materials matter.
  Use per-instance overrides or duplicate resources when a change must not
  affect every instance.
- If adding collision, keep it consistent with walkability. Hiding a wall mesh
  does not disable a collision shape.
- Surface load, parse and invalid-data errors explicitly. Avoid silent
  fallbacks that leave an apparently successful but incomplete level.

## Movement and controls

The intended feel is a classic grid crawler in the style of Dungeon Master
and Eye of the Beholder: the player occupies one cell, steps a whole cell at
a time and turns in 90 degree increments, inside a fully 3D world.

- Separate logical state from visual state. Keep the truth as an integer cell
  coordinate (`Vector2i`) and a facing enum of four directions. Animate the
  node's `position` and `rotation` toward that logical target; do not treat
  the live transform as the source of truth.
- Represent facing as an integer and turn with modulo arithmetic. Derive the
  step vector and target yaw from the logical facing, computed before any
  turn animation, not from the current (possibly mid-turn) `basis`.
- Drive movement with a small state machine (idle, moving, turning). Accept
  input only while idle, using edge-triggered `is_action_just_pressed`, so one
  key press produces exactly one step or turn. Snap exactly to the integer
  target when each step or turn finishes to avoid drift.
- Keep step and turn durations short (roughly 150 to 220 ms). A `Tween` on
  `position` and `rotation.y` is idiomatic; ease turns rather than animating
  them linearly. When interpolating angles manually, use `lerp_angle` and
  target `deg_to_rad(facing * -90)` to avoid wrap-around glitches.
- Staying a `Node3D` with scripted transforms is appropriate; grid movement
  does not need `CharacterBody3D` or physics. Reserve physics for things that
  genuinely need it, such as projectiles or an optional free-look mode.
- Decide walkability from map data, not collision shapes. Query the map for
  whether the target cell is enterable; on a blocked move, ignore the input or
  play a small bump nudge. This needs a grid data source (a 2D array or a map
  resource) that answers an `is_walkable(cell)` style query.
- Keep responsibilities local: the player script owns facing, current cell,
  the state machine and its own animation; map or level code owns grid data
  and walkability. Do not push this into the `Global` autoload.

## Visual direction and scope

- Preserve nearest-neighbour filtering and the existing retro aesthetic.
  Do not add smoothing, modern lighting effects or new post-processing
  without a task that calls for them.
- Simple boxes are acceptable at the current scale. Do not introduce custom
  exposed-face meshing, chunking or a separate node for every quad merely as
  speculative optimisation. Measure a problem before adding that complexity.
- If retro post-processing is requested, use an approach supported by the
  Compatibility renderer. Do not assume Forward+ or compute-shader features
  are available.
- For PS1-style output, low render resolution, colour quantisation and ordered
  dithering are separate choices. Apply pixel-scale dithering before
  nearest-neighbour upscaling, not as high-resolution animated noise.

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

There is currently no checked-in automated test suite or external build system.
Do not invent an npm, .NET or other unrelated build step.

With a Godot 4.7 executable available as `godot`, run these from the project
root after relevant code, scene or resource changes:

```powershell
godot --headless --path . --editor --import
godot --headless --path . --quit-after 30
```

Use the installed executable's actual name or path if it is not on `PATH`.
Inspect output for script, resource and scene errors, not just the exit code.
The second command is a startup smoke check, not a complete gameplay test.
Distinguish pre-existing errors from errors introduced by the change.

Use **F5** to run the project and **F6** to run the scene being edited.
For visual, input or UI changes, also run with graphics enabled and inspect the
affected behaviour. Remember that the current debug startup bypasses the menu.
Headless execution alone cannot confirm rendering or user interaction.

Keep documentation-only work to documentation. Do not launch or rewrite the
project merely to validate prose. State any validation limitations honestly.
