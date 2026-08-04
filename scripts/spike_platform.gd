extends StaticBody2D
class_name SpikePlatform

## 플레이어가 3초 이상 밟고 있으면 바닥에서 진한 갈색 가시가 올라와 2초마다 1 데미지를 주는 플랫폼

@export var trigger_delay: float = 3.0 # 가시 돌출 대기 시간 (3초)
@export var damage_interval: float = 2.0 # 데미지 간격 (2초)
@export var spike_height: float = 16.0 # 플레이어 키의 1/3 (약 16px)

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _detect_area: Area2D
var _spike_visual: Node2D
var _player_ref: PlayerDADA = null
var _stand_time: float = 0.0
var _spikes_active: bool = false
var _damage_timer: float = 0.0

func _ready() -> void:
	# 플레이어 감지용 Area2D 서브 노드 자동 생성
	_detect_area = Area2D.new()
	_detect_area.collision_layer = 0
	_detect_area.collision_mask = 2 # Player layer
	
	var detect_shape := CollisionShape2D.new()
	var plat_w: float = 460.0
	if is_instance_valid(color_rect):
		plat_w = color_rect.size.x
	elif is_instance_valid(collision_shape) and collision_shape.shape is RectangleShape2D:
		plat_w = (collision_shape.shape as RectangleShape2D).size.x
		
	var shape := RectangleShape2D.new()
	shape.size = Vector2(plat_w - 10.0, 16.0)
	detect_shape.shape = shape
	detect_shape.position = Vector2(0.0, -20.0) # 플랫폼 상단 표면 바로 위
	_detect_area.add_child(detect_shape)
	add_child(_detect_area)

	_detect_area.body_entered.connect(_on_body_entered)
	_detect_area.body_exited.connect(_on_body_exited)

	# 가시 그래픽 연출용 비주얼 컨테이너
	_spike_visual = Node2D.new()
	_spike_visual.visible = false
	_spike_visual.position = Vector2(0.0, -12.0)
	add_child(_spike_visual)
	_draw_spikes(plat_w)

func _draw_spikes(plat_w: float) -> void:
	var spike_col := Color(0.35, 0.20, 0.10, 1.0) # 진한 갈색 가시
	var spike_tip := Color(0.50, 0.32, 0.15, 1.0)
	var count := int(plat_w / 18.0)
	var start_x := -plat_w * 0.5 + 9.0
	
	for i in range(count):
		var px := start_x + (i * 18.0)
		var polygon := Polygon2D.new()
		polygon.polygon = PackedVector2Array([
			Vector2(px - 7.0, 0.0),
			Vector2(px, -spike_height),
			Vector2(px + 7.0, 0.0)
		])
		polygon.color = spike_col
		_spike_visual.add_child(polygon)
		
		# 가시 끝 하이라이트 픽셀
		var tip := ColorRect.new()
		tip.size = Vector2(2.0, 3.0)
		tip.position = Vector2(px - 1.0, -spike_height)
		tip.color = spike_tip
		_spike_visual.add_child(tip)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		_player_ref = body as PlayerDADA

func _on_body_exited(body: Node2D) -> void:
	if body == _player_ref:
		_player_ref = null
		_stand_time = 0.0

func _physics_process(delta: float) -> void:
	if is_instance_valid(_player_ref):
		if not _spikes_active:
			_stand_time += delta
			if _stand_time >= trigger_delay:
				_raise_spikes()
		else:
			# 가시가 솟아오른 상태에서 2초마다 1 데미지 부여
			_damage_timer += delta
			if _damage_timer >= damage_interval:
				_damage_timer = 0.0
				_player_ref.take_damage(1, global_position)
	else:
		if _spikes_active and _stand_time > 0.0:
			_lower_spikes()

func _raise_spikes() -> void:
	_spikes_active = true
	_damage_timer = damage_interval # 솟아오르자마자 첫 데미지 즉시 발동
	_spike_visual.visible = true
	_spike_visual.position.y = 0.0
	var tw := create_tween()
	tw.tween_property(_spike_visual, "position:y", -12.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _lower_spikes() -> void:
	_spikes_active = false
	_stand_time = 0.0
	var tw := create_tween()
	tw.tween_property(_spike_visual, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _spike_visual.visible = false)
