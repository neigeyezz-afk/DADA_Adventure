extends Node2D
class_name CoinBox
## 무기로 공격하면 즉시 터지며 골드 코인이 쏟아지는 디테일한 픽셀 아트 보상 상자.

@export var coin_count: int = 3
@export var coin_value: int = 10   # 코인 1개당 골드량

@onready var hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox
@onready var body_rect: ColorRect = get_node_or_null("ColorRect") as ColorRect

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")
var _opened: bool = false
var _pixel_container: Node2D

func _ready() -> void:
	if is_instance_valid(hurtbox):
		hurtbox.hit_received.connect(_on_hit)
	
	_build_pixel_art()

func _build_pixel_art() -> void:
	if is_instance_valid(body_rect):
		body_rect.visible = false # 기존 단색 사각형 숨기기

	_pixel_container = Node2D.new()
	_pixel_container.name = "PixelVisuals"
	add_child(_pixel_container)

	_draw_box_graphics()

func _draw_box_graphics() -> void:
	if not is_instance_valid(_pixel_container):
		return
		
	for child in _pixel_container.get_children():
		child.queue_free()

	var border_col := Color(0.32, 0.22, 0.08, 1.0) # 고전 아케이드 브라운 테두리
	var gold_main  := Color(0.94, 0.74, 0.18, 1.0) if not _opened else Color(0.48, 0.36, 0.20, 1.0)
	var gold_light := Color(1.0, 0.90, 0.45, 1.0)  if not _opened else Color(0.60, 0.48, 0.28, 1.0)
	var gold_shadow:= Color(0.72, 0.52, 0.10, 1.0)  if not _opened else Color(0.35, 0.25, 0.12, 1.0)
	var q_mark_col := Color(1.0, 0.98, 0.85, 1.0)  if not _opened else Color(0.38, 0.30, 0.18, 1.0)

	# 1. 외곽 아웃라인 테두리 (36x32)
	var outline := ColorRect.new()
	outline.size = Vector2(36.0, 32.0)
	outline.position = Vector2(-18.0, -32.0)
	outline.color = border_col
	_pixel_container.add_child(outline)

	# 2. 메인 바디
	var body := ColorRect.new()
	body.size = Vector2(32.0, 28.0)
	body.position = Vector2(-16.0, -30.0)
	body.color = gold_main
	_pixel_container.add_child(body)

	# 3. 상단 & 좌측 하이라이트 림
	var hi_top := ColorRect.new()
	hi_top.size = Vector2(32.0, 3.0)
	hi_top.position = Vector2(-16.0, -30.0)
	hi_top.color = gold_light
	_pixel_container.add_child(hi_top)

	var hi_left := ColorRect.new()
	hi_left.size = Vector2(3.0, 28.0)
	hi_left.position = Vector2(-16.0, -30.0)
	hi_left.color = gold_light
	_pixel_container.add_child(hi_left)

	# 4. 하단 & 우측 픽셀 그림자
	var shd_bot := ColorRect.new()
	shd_bot.size = Vector2(32.0, 3.0)
	shd_bot.position = Vector2(-16.0, -5.0)
	shd_bot.color = gold_shadow
	_pixel_container.add_child(shd_bot)

	var shd_right := ColorRect.new()
	shd_right.size = Vector2(3.0, 28.0)
	shd_right.position = Vector2(13.0, -30.0)
	shd_right.color = gold_shadow
	_pixel_container.add_child(shd_right)

	# 5. 모서리 픽셀 금속 벳지 리벳 (4개 코너)
	var rivet_positions := [
		Vector2(-14.0, -28.0), Vector2(11.0, -28.0),
		Vector2(-14.0, -7.0), Vector2(11.0, -7.0)
	]
	for r_pos in rivet_positions:
		var rivet := ColorRect.new()
		rivet.size = Vector2(3.0, 3.0)
		rivet.position = r_pos
		rivet.color = border_col
		_pixel_container.add_child(rivet)

	# 6. 중앙 물음표 '?' 픽셀 아트
	var q_pixels := [
		Vector2(-4.0, -25.0), Vector2(-1.0, -25.0), Vector2(2.0, -25.0),
		Vector2(2.0, -22.0), Vector2(-1.0, -19.0), Vector2(-1.0, -16.0),
		Vector2(-1.0, -11.0)
	]
	for qp in q_pixels:
		var q_dot := ColorRect.new()
		q_dot.size = Vector2(3.0, 3.0)
		q_dot.position = qp
		q_dot.color = q_mark_col
		_pixel_container.add_child(q_dot)

# 다각도 피격 호환성 핸들러 (무기 공격 즉시 오픈)
func receive_hit(_damage: int = 1, _dir: Vector2 = Vector2.ZERO) -> void:
	_on_hit(_damage, _dir)

func take_damage(_amount: int = 1, _pos: Vector2 = Vector2.ZERO) -> void:
	_on_hit(_amount, _pos)

func _on_hit_received(_damage: int = 1, _dir: Vector2 = Vector2.ZERO) -> void:
	_on_hit(_damage, _dir)

func _on_hit(_damage: int = 1, _dir: Vector2 = Vector2.ZERO) -> void:
	if _opened:
		return
	_opened = true
	_draw_box_graphics()
	
	for i in coin_count:
		var p := PICKUP_SCENE.instantiate() as Pickup
		var parent_node := get_parent()
		if parent_node:
			parent_node.add_child(p)
		else:
			add_child(p)
		p.global_position = global_position + Vector2(randf_range(-14, 14), -18)
		p.setup("gold", coin_value)
