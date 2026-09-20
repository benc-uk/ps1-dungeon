extends OmniLight3D

@export_group("Light Flicker")
@export var flicker_speed: float = 15.0  # Higher = faster crackling
@export var base_energy: float = 1.5     # The average baseline brightness
@export var flicker_intensity: float = 0.4 # How wildly it deviates up and down

var noise: FastNoiseLite
var time_passed: float = 0.0

func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.5
	# Give it a completely random starting seed so other torches don't match
	noise.seed = randi() 

func _process(delta: float) -> void:
	time_passed += delta * flicker_speed
	
	# Get a raw noise value between -1.0 and 1.0
	var raw_noise = noise.get_noise_1d(time_passed)
	var  additive_noise := clampf(0.5 + raw_noise * 1.25, 0.0, 1.0)
	# Apply the noise multiplicatively onto your baseline energy
	light_energy = base_energy + (additive_noise * flicker_intensity)
