@tool
extends Node3D
class_name MapCell

@export var show_walls: bool = true:
	set(value):
		show_walls = value
		if is_node_ready():
			_update_wall_visibility()

func _ready() -> void:
	_update_wall_visibility()

func _update_wall_visibility() -> void:
	$Node3D/Walls.visible = show_walls
