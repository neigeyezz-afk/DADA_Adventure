extends AnimatableBody2D
class_name ShrinkingPlatform

## 좌우 길이가 100% -> 30% 로 줄어들었다가 1.5초 정지 후 다시 100%로 복원되는 플랫폼

@export var min_scale_ratio: float = 0.3 # 30% 까지 줄어듦
@export var shrink_duration: float = 1.2 # 줄어드는 시간
@export var pause_duration: float = 1.5 # 줄어든 채 멈춰있는 시간
@export var expand_duration: float = 1.2 # 다시 늘어나는 시간

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _original_width: float = 260.0
var _original_shape: RectangleShape2D = null

func _ready() -> void:
	if is_instance_valid(color_rect):
		_original_width = color_rect.size.x
	elif is_instance_valid(collision_shape) and collision_shape.shape is RectangleShape2D:
		_original_width = (collision_shape.shape as RectangleShape2D).size.x

	# 씬 공유 리소스 충돌 방지용 고유 셰이프 생성
	if is_instance_valid(collision_shape) and collision_shape.shape:
		_original_shape = collision_shape.shape.duplicate() as RectangleShape2D
		collision_shape.shape = _original_shape

	_start_shrink_loop()

func _start_shrink_loop() -> void:
	var tween := create_tween().set_loops()
	
	# 1. 100% -> 30% 로 축소
	tween.tween_method(_set_width_ratio, 1.0, min_scale_ratio, shrink_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. 30% 상태에서 1.5초간 멈춤
	tween.tween_interval(pause_duration)
	
	# 3. 30% -> 100% 로 다시 확장
	tween.tween_method(_set_width_ratio, min_scale_ratio, 1.0, expand_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 4. 100% 상태에서 1.0초간 멈춤 후 반복
	tween.tween_interval(1.0)

func _set_width_ratio(ratio: float) -> void:
	var current_w := _original_width * ratio
	var half_w := current_w * 0.5
	
	if is_instance_valid(color_rect):
		color_rect.offset_left = -half_w
		color_rect.offset_right = half_w
		
	if is_instance_valid(collision_shape) and _original_shape:
		_original_shape.size = Vector2(current_w, _original_shape.size.y)
