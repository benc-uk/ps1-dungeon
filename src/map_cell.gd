class_name MapCell
extends Node3D

@export var show_walls: bool = true

func _ready():
	_update_wall_visibility()

func _update_wall_visibility():
	$Node3D/Walls.visible = show_walls
