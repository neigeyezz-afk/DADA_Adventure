extends Node2D
class_name RockDecor

## ==========================================================
## RockDecor: 곡면과 라운딩 모서리를 적용한 자연스러운 픽셀 아트 바위
## ==========================================================

@export var rock_type: int = 1
@export var custom_scale: Vector2 = Vector2(1.0, 1.0)

@onready var visual_root: Node2D = $VisualRoot

func _ready() -> void:
	z_index = -2 # 배경 지형 뒤쪽 레이어 배치
	if custom_scale != Vector2(1.0, 1.0):
		scale = custom_scale
	_build_pixel_rock()

func _build_pixel_rock() -> void:
	if not is_instance_valid(visual_root):
		return

	for child in visual_root.get_children():
		child.queue_free()

	var outline_col := Color(0.14, 0.12, 0.18, 1.0) # 다크 차콜 테두리
	var rock_base   := Color(0.62, 0.60, 0.66, 1.0) # 슬레이트 퍼플그레이 메인톤
	var rock_light  := Color(0.85, 0.83, 0.88, 1.0) # 상단/좌측 하이라이트톤
	var rock_shadow := Color(0.42, 0.39, 0.46, 1.0) # 하단/우측 그림자톤
	var moss_dark   := Color(0.14, 0.44, 0.16, 1.0) # 이끼/잔디 진한 그린
	var moss_light  := Color(0.32, 0.72, 0.25, 1.0) # 이끼/잔디 연두색 하이라이트

	match rock_type:
		1:
			_build_tall_cliff_rock(outline_col, rock_base, rock_light, rock_shadow)
		2:
			_build_wide_slab_rock(outline_col, rock_base, rock_light, rock_shadow)
		3:
			_build_mossy_boulder(outline_col, rock_base, rock_light, rock_shadow, moss_dark, moss_light)
		_:
			_build_plateau_stone(outline_col, rock_base, rock_light, rock_shadow, moss_dark, moss_light)

# ----------------------------------------------------
# 둥근 모서리를 가진 픽셀 다각형 렌더링 헬퍼
# ----------------------------------------------------
func _add_rounded_polygon(center_pos: Vector2, size: Vector2, corner_radius: float, color: Color) -> void:
	var half := size * 0.5
	var r := minf(corner_radius, minf(half.x, half.y))
	var points := PackedVector2Array()
	var segments := 4
	
	# Top Right Corner
	var c_tr := center_pos + Vector2(half.x - r, -half.y + r)
	for i in range(segments + 1):
		var angle := lerpf(0.0, -PI * 0.5, float(i) / segments)
		points.append(c_tr + Vector2(cos(angle), sin(angle)) * r)
		
	# Top Left Corner
	var c_tl := center_pos + Vector2(-half.x + r, -half.y + r)
	for i in range(segments + 1):
		var angle := lerpf(-PI * 0.5, -PI, float(i) / segments)
		points.append(c_tl + Vector2(cos(angle), sin(angle)) * r)
		
	# Bottom Left Corner
	var c_bl := center_pos + Vector2(-half.x + r, half.y - r)
	for i in range(segments + 1):
		var angle := lerpf(-PI, -PI * 1.5, float(i) / segments)
		points.append(c_bl + Vector2(cos(angle), sin(angle)) * r)
		
	# Bottom Right Corner
	var c_br := center_pos + Vector2(half.x - r, half.y - r)
	for i in range(segments + 1):
		var angle := lerpf(-PI * 1.5, -TAU, float(i) / segments)
		points.append(c_br + Vector2(cos(angle), sin(angle)) * r)

	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	visual_root.add_child(poly)

# ----------------------------------------------------
# Image 1: 곡면이 가미된 봉우리형 바위산
# ----------------------------------------------------
func _build_tall_cliff_rock(out_c: Color, base_c: Color, light_c: Color, shd_c: Color) -> void:
	# 1. 아웃라인 (둥근 피라미드 외곽)
	_add_rounded_polygon(Vector2(0.0, -28.0), Vector2(52.0, 56.0), 10.0, out_c)
	_add_rounded_polygon(Vector2(-2.0, -42.0), Vector2(36.0, 32.0), 8.0, out_c)
	
	# 2. 바위 메인 둥근 바디
	_add_rounded_polygon(Vector2(0.0, -28.0), Vector2(48.0, 52.0), 8.0, base_c)
	_add_rounded_polygon(Vector2(-2.0, -42.0), Vector2(32.0, 28.0), 6.0, base_c)
	
	# 3. 좌측 상단 곡면 하이라이트 (빛받는 입체 곡면)
	_add_rounded_polygon(Vector2(-10.0, -32.0), Vector2(24.0, 44.0), 6.0, light_c)
	_add_rounded_polygon(Vector2(-6.0, -44.0), Vector2(18.0, 18.0), 4.0, Color(0.95, 0.93, 0.98))
	
	# 4. 우측 부드러운 그림자 면
	_add_rounded_polygon(Vector2(12.0, -24.0), Vector2(18.0, 40.0), 6.0, shd_c)

# ----------------------------------------------------
# Image 2: 타원형 곡면 다층 암석판 (Slab Rock)
# ----------------------------------------------------
func _build_wide_slab_rock(out_c: Color, base_c: Color, light_c: Color, shd_c: Color) -> void:
	# 1. 외곽 아웃라인
	_add_rounded_polygon(Vector2(0.0, -14.0), Vector2(64.0, 28.0), 10.0, out_c)
	
	# 2. 메인 바디
	_add_rounded_polygon(Vector2(0.0, -14.0), Vector2(60.0, 24.0), 8.0, base_c)
	
	# 3. 상단 볼록 하이라이트
	_add_rounded_polygon(Vector2(-4.0, -18.0), Vector2(50.0, 14.0), 6.0, light_c)
	
	# 4. 우측/하단 그림자
	_add_rounded_polygon(Vector2(14.0, -12.0), Vector2(24.0, 20.0), 6.0, shd_c)

# ----------------------------------------------------
# Image 3: 둥근 픽셀 바위 (Mossy Boulder)
# ----------------------------------------------------
func _build_mossy_boulder(out_c: Color, base_c: Color, light_c: Color, shd_c: Color, moss_d: Color, moss_l: Color) -> void:
	_add_rounded_polygon(Vector2(0.0, -16.0), Vector2(38.0, 32.0), 12.0, out_c)
	_add_rounded_polygon(Vector2(0.0, -16.0), Vector2(34.0, 28.0), 10.0, base_c)
	_add_rounded_polygon(Vector2(-6.0, -20.0), Vector2(18.0, 18.0), 8.0, light_c)
	_add_rounded_polygon(Vector2(8.0, -14.0), Vector2(14.0, 22.0), 6.0, shd_c)

	# 하단을 둘러싸는 이끼 잔디 싹
	for gx in [-16.0, -10.0, -4.0, 2.0, 8.0, 14.0]:
		var h := randf_range(6.0, 12.0)
		_add_rounded_polygon(Vector2(gx, -h * 0.5), Vector2(6.0, h), 2.0, out_c)
		_add_rounded_polygon(Vector2(gx, -h * 0.5), Vector2(4.0, h - 2.0), 1.0, moss_d)
		_add_rounded_polygon(Vector2(gx, -h + 2.0), Vector2(2.0, 4.0), 1.0, moss_l)

# ----------------------------------------------------
# Image 4: 언덕형 곡면 이끼 암석 (Plateau Mossy Stone)
# ----------------------------------------------------
func _build_plateau_stone(out_c: Color, base_c: Color, light_c: Color, shd_c: Color, moss_d: Color, moss_l: Color) -> void:
	_add_rounded_polygon(Vector2(0.0, -11.0), Vector2(56.0, 22.0), 9.0, out_c)
	_add_rounded_polygon(Vector2(0.0, -11.0), Vector2(52.0, 18.0), 7.0, base_c)
	_add_rounded_polygon(Vector2(-6.0, -14.0), Vector2(38.0, 10.0), 5.0, light_c)
	_add_rounded_polygon(Vector2(14.0, -10.0), Vector2(16.0, 16.0), 5.0, shd_c)

	# 상단 곡면 이끼 코팅
	_add_rounded_polygon(Vector2(-4.0, -18.0), Vector2(36.0, 6.0), 3.0, moss_d)
	_add_rounded_polygon(Vector2(-8.0, -19.0), Vector2(22.0, 4.0), 2.0, moss_l)
