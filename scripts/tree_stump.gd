extends StaticBody2D
class_name TreeStump

## 플레이어가 밟고 올라갈 수 있는 잘린 나무 밑둥 오브젝트

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_root: Node2D = $VisualRoot

func _ready() -> void:
	_build_stump_visuals()

func _build_stump_visuals() -> void:
	if not is_instance_valid(visual_root):
		return
		
	for child in visual_root.get_children():
		child.queue_free()

	var bark_outline := Color(0.18, 0.12, 0.08, 1.0) # 다크 브라운 바크 테두리
	var bark_base    := Color(0.42, 0.26, 0.15, 1.0) # 메인 나무 껍질
	var bark_dark    := Color(0.30, 0.18, 0.10, 1.0) # 바크 텍스처 그림자
	var wood_ring    := Color(0.78, 0.60, 0.40, 1.0) # 상단 나무 단면 연한 우드톤
	var ring_inner   := Color(0.68, 0.50, 0.30, 1.0) # 나이테 다크 링
	var moss_green   := Color(0.25, 0.65, 0.22, 1.0) # 밑둥 이끼

	# 1. 외곽 아웃라인 (바닥 기둥 48x36)
	var outline := ColorRect.new()
	outline.size = Vector2(52.0, 38.0)
	outline.position = Vector2(-26.0, -38.0)
	outline.color = bark_outline
	visual_root.add_child(outline)

	# 2. 나무 껍질 바디
	var trunk := ColorRect.new()
	trunk.size = Vector2(48.0, 34.0)
	trunk.position = Vector2(-24.0, -36.0)
	trunk.color = bark_base
	visual_root.add_child(trunk)

	# 바크 텍스처 결 (세로 줄무늬)
	for x_off in [-16.0, -4.0, 8.0]:
		var stripe := ColorRect.new()
		stripe.size = Vector2(4.0, 24.0)
		stripe.position = Vector2(x_off, -30.0)
		stripe.color = bark_dark
		visual_root.add_child(stripe)

	# 3. 상단 나무 잘린 단면 타원 (Top Wood Cut Surface)
	var top_cut := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(12):
		var angle := lerpf(0.0, TAU, float(i) / 12.0)
		points.append(Vector2(cos(angle) * 23.0, -36.0 + sin(angle) * 7.0))
	top_cut.polygon = points
	top_cut.color = wood_ring
	visual_root.add_child(top_cut)

	# 나이테 링 (Tree Ring Detail)
	var inner_ring := Polygon2D.new()
	var ring_points := PackedVector2Array()
	for i in range(10):
		var angle := lerpf(0.0, TAU, float(i) / 10.0)
		ring_points.append(Vector2(cos(angle) * 14.0, -36.0 + sin(angle) * 4.0))
	inner_ring.polygon = ring_points
	inner_ring.color = ring_inner
	visual_root.add_child(inner_ring)

	# 4. 밑둥 바닥 이끼 (Bottom Moss Coat)
	for mx in [-24.0, -14.0, 2.0, 14.0]:
		var moss := ColorRect.new()
		moss.size = Vector2(8.0, 6.0)
		moss.position = Vector2(mx, -6.0)
		moss.color = moss_green
		visual_root.add_child(moss)

	# 5. 충돌체 설정 (상단 표면 밟기 가능)
	if is_instance_valid(collision_shape):
		var shape := RectangleShape2D.new()
		shape.size = Vector2(48.0, 36.0)
		collision_shape.shape = shape
		collision_shape.position = Vector2(0.0, -18.0)
