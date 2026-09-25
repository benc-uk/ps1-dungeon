extends Node3D

func bind(feature: WorldState.Feature):
	feature.state_changed.connect(_on_state_changed)
	_on_state_changed(feature.state)
	
func _on_state_changed(new_state: WorldState.DoorFeature.State) -> void:
	match new_state:
		WorldState.DoorFeature.State.OPEN:
			$Anim.play("open_close")

		WorldState.DoorFeature.State.CLOSED:
			$Anim.play_backwards("open_close")
