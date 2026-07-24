extends AnimatableBody2D
class_name MovingPlatform
## 좌우로 계속 왕복 이동하는 발판.
## sync_to_physics(기본 true)가 켜져 있어 위에 탄 캐릭터가 함께 이동한다.

@export var move_range: float = 140.0   # 왕복 이동 폭(전체 이동 거리)
@export var period: float = 4.0         # 왕복 1회에 걸리는 시간(초)

var _base_x: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	_base_x = position.x

func _physics_process(delta: float) -> void:
	_t += delta
	var half_range := move_range / 2.0
	position.x = _base_x + sin(_t * TAU / period) * half_range
