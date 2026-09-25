class_name Grid
extends RefCounted

enum Dir { NORTH, EAST, SOUTH, WEST }
const CELL_SIZE := 1.0
const STEP := { Dir.NORTH: Vector2i(0, -1), Dir.EAST: Vector2i(1, 0),
								Dir.SOUTH: Vector2i(0, 1),  Dir.WEST: Vector2i(-1, 0) }

static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)

static func dir_to_angle(dir: Dir) -> float:
	match dir:
		Dir.NORTH: return PI / 2.0
		Dir.EAST: return 0.0
		Dir.SOUTH: return -PI / 2.0
		Dir.WEST: return PI
	return 0.0
