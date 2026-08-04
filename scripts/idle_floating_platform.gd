extends AnimatableBody2D
class_name IdleFloatingPlatform

## 정지되어 있는 플랫폼들에 미세한 둥둥 뜨는 픽셀 호버링 모션을 부여하는 애니메이터

@export var float_amplitude: float = 6.0 # 호버링 폭 (±6px)
@export var float_speed: float = 2.0 # 호버링 속도
@export var phase_offset: float = 0.0 # 각 발판별 비동기 위동차

var _base_y: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_base_y = position.y
	if phase_offset == 0.0:
		phase_offset = randf_range(0.0, TAU)

func _physics_process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin((_time * float_speed) + phase_offset) * float_amplitude
