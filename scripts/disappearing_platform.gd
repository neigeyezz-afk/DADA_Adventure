extends StaticBody2D
class_name DisappearingPlatform

## 플레이어가 3초 이상 밟고 있으면 플랫폼이 경고 흔들림 후 사라져 플레이어를 추락시키고 1 데미지를 입히는 붕괴 발판

@export var trigger_delay: float = 3.0 # 붕괴 트리거 3초
@export var respawn_delay: float = 4.0 # 4초 후 재출현

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _detect_area: Area2D
var _player_ref: PlayerDADA = null
var _stand_time: float = 0.0
var _is_crumbling: bool = false

func _ready() -> void:
	_detect_area = Area2D.new()
	_detect_area.collision_layer = 0
	_detect_area.collision_mask = 2 # Player layer
	
	var detect_shape := CollisionShape2D.new()
	var plat_w: float = 260.0
	if is_instance_valid(color_rect):
		plat_w = color_rect.size.x
	elif is_instance_valid(collision_shape) and collision_shape.shape is RectangleShape2D:
		plat_w = (collision_shape.shape as RectangleShape2D).size.x
		
	var shape := RectangleShape2D.new()
	shape.size = Vector2(plat_w - 10.0, 16.0)
	detect_shape.shape = shape
	detect_shape.position = Vector2(0.0, -20.0)
	_detect_area.add_child(detect_shape)
	add_child(_detect_area)

	_detect_area.body_entered.connect(_on_body_entered)
	_detect_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		_player_ref = body as PlayerDADA

func _on_body_exited(body: Node2D) -> void:
	if body == _player_ref:
		_player_ref = null
		if not _is_crumbling:
			_stand_time = 0.0

func _physics_process(delta: float) -> void:
	if is_instance_valid(_player_ref) and not _is_crumbling:
		_stand_time += delta
		if _stand_time >= trigger_delay:
			_crumble_and_disappear()

func _crumble_and_disappear() -> void:
	_is_crumbling = true
	
	# 경고 진동 연출 (0.4초)
	var tw := create_tween()
	for i in range(8):
		var offset_x := randf_range(-4.0, 4.0)
		tw.tween_property(self, "position:x", position.x + offset_x, 0.05)
	tw.tween_callback(func():
		# 1. 플레이어에게 1 데미지 부여 및 추락 처리
		if is_instance_valid(_player_ref):
			_player_ref.take_damage(1, global_position)
			
		# 2. 충돌 끄기 & 비주얼 숨기기
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred("disabled", true)
		if is_instance_valid(color_rect):
			color_rect.visible = false
			
		# 3. 재출현 타이머 설정
		get_tree().create_timer(respawn_delay).timeout.connect(_respawn_platform)
	)

func _respawn_platform() -> void:
	_is_crumbling = false
	_stand_time = 0.0
	_player_ref = null
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", false)
	if is_instance_valid(color_rect):
		color_rect.visible = true
		color_rect.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(color_rect, "modulate:a", 1.0, 0.3)
