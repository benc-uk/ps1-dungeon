extends Node

func _ready():
	var cur_image := preload("res://misc/cursor.png").get_image()
	cur_image.resize(64, 64, Image.INTERPOLATE_NEAREST)

	var cursor := ImageTexture.create_from_image(cur_image)
	Input.set_custom_mouse_cursor(
		cursor,
		Input.CURSOR_ARROW,
		Vector2(2, 2)
	)
