extends Node2D
class_name SkyCloud

@export var float_speed: float = 15.0
@onready var visual_root: Node2D = $VisualRoot

func _ready() -> void:
	z_index = -5 # Sky background
	_build_godot_pixel_cloud()

func _process(delta: float) -> void:
	position.x += float_speed * delta
	if position.x > 7000.0:
		position.x = -200.0

func _build_godot_pixel_cloud() -> void:
	if not is_instance_valid(visual_root):
		return

	for child in visual_root.get_children():
		child.queue_free()

	var outline_col := Color(0.12, 0.22, 0.36, 1.0) # 외곽 픽셀 테두리
	var cloud_white := Color(0.96, 0.98, 1.00, 1.0) # 클라우드 화이트
	var shadow_cyan := Color(0.74, 0.85, 0.95, 1.0) # 하단 그림자 블루
	var shine_white  := Color(1.00, 1.00, 1.00, 1.0) # 상단 광택 하이라이트

	# 픽셀 구름 형태 구성 (Width 120, Height 50)
	# A) 블랙/다크블루 외곽 테두리 블록
	var out1 := ColorRect.new()
	out1.size = Vector2(124.0, 38.0)
	out1.position = Vector2(-62.0, -19.0)
	out1.color = outline_col
	visual_root.add_child(out1)

	var out2 := ColorRect.new()
	out2.size = Vector2(84.0, 24.0)
	out2.position = Vector2(-42.0, -31.0)
	out2.color = outline_col
	visual_root.add_child(out2)

	var out3 := ColorRect.new()
	out3.size = Vector2(52.0, 18.0)
	out3.position = Vector2(6.0, -37.0)
	out3.color = outline_col
	visual_root.add_child(out3)

	# B) 하단 그림자 픽셀 (Bottom Shadow)
	var shd := ColorRect.new()
	shd.size = Vector2(116.0, 10.0)
	shd.position = Vector2(-58.0, 7.0)
	shd.color = shadow_cyan
	visual_root.add_child(shd)

	# C) 구름 메인 화이트 바디 (Main Cloud Body)
	var body1 := ColorRect.new()
	body1.size = Vector2(116.0, 30.0)
	body1.position = Vector2(-58.0, -15.0)
	body1.color = cloud_white
	visual_root.add_child(body1)

	var body2 := ColorRect.new()
	body2.size = Vector2(76.0, 18.0)
	body2.position = Vector2(-38.0, -27.0)
	body2.color = cloud_white
	visual_root.add_child(body2)

	var body3 := ColorRect.new()
	body3.size = Vector2(44.0, 14.0)
	body3.position = Vector2(10.0, -33.0)
	body3.color = cloud_white
	visual_root.add_child(body3)

	# D) 상단 하이라이트 픽셀 (Top Shine Highlight)
	var shine1 := ColorRect.new()
	shine1.size = Vector2(36.0, 4.0)
	shine1.position = Vector2(-34.0, -26.0)
	shine1.color = shine_white
	visual_root.add_child(shine1)

	var shine2 := ColorRect.new()
	shine2.size = Vector2(24.0, 4.0)
	shine2.position = Vector2(14.0, -32.0)
	shine2.color = shine_white
	visual_root.add_child(shine2)
