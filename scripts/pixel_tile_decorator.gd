@tool
extends Node
class_name PixelTileDecorator

# When true, decoration runs automatically in the editor. Disable to avoid
# editor-time modifications that overwrite manual scene edits.
@export var decorate_in_editor: bool = false

## 레퍼런스 및 고전 픽셀 플랫포머 스타일을 연구하여,
## 지면(Floor)의 땅 속 디테일 질감(자갈/암석/지층)과 다채로운 풀 표정을 절차적으로 렌더링합니다.

func _ready() -> void:
	# Skip editor-time decoration unless explicitly enabled by the user.
	if Engine.is_editor_hint():
		if not decorate_in_editor:
			return

	call_deferred("_decorate_all_floors_and_platforms")

func _decorate_all_floors_and_platforms() -> void:
	var root := get_parent()
	if not root:
		return

	for node in root.get_children():
		if node is StaticBody2D and node.name.begins_with("Floor"):
			_decorate_floor(node)
		elif (node is StaticBody2D or node is AnimatableBody2D) and node.name.begins_with("Platform"):
			_decorate_platform(node)

func _decorate_floor(floor_node: StaticBody2D) -> void:
	var color_rect := floor_node.get_node_or_null("ColorRect") as ColorRect
	if not color_rect:
		return
		
	# 기존 자식 노드 정리 (중복 생성 방지)
	for c in color_rect.get_children():
		if c.name != "GrassTrim" and c.name != "SubterraneanDarkness":
			c.queue_free()

	# 1. 상단 토양 메인 브라운
	color_rect.color = Color(0.48, 0.32, 0.18, 1.0)
	var floor_w := color_rect.size.x
	var floor_h := color_rect.size.y

	# 2. 지하 지층 레이어 (Subterranean Layers)
	var mid_strata := ColorRect.new()
	mid_strata.name = "MidStrata"
	mid_strata.size = Vector2(floor_w, 120.0)
	mid_strata.position = Vector2(0.0, 40.0)
	mid_strata.color = Color(0.38, 0.24, 0.13, 1.0)
	color_rect.add_child(mid_strata)

	var deep_dark := color_rect.get_node_or_null("SubterraneanDarkness") as ColorRect
	if deep_dark:
		deep_dark.color = Color(0.22, 0.14, 0.08, 1.0)
		deep_dark.position.y = 160.0
		deep_dark.size = Vector2(floor_w, max(0.0, floor_h - 160.0))

	# 3. 땅 속 디테일 자갈/암석 픽셀 파티클 (Soil Pebbles & Rocks)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(floor_w) + int(floor_node.position.x)
	
	# 자갈 및 미네랄 암석 블록 흩뿌리기
	var rock_colors: Array[Color] = [
		Color(0.58, 0.42, 0.26, 1.0), # 밝은 자갈
		Color(0.30, 0.18, 0.10, 1.0), # 짙은 자갈
		Color(0.68, 0.50, 0.30, 1.0), # 석회석/점토
		Color(0.18, 0.10, 0.06, 1.0)  # 암석 조각
	]
	
	var pebble_count := int(floor_w / 45.0)
	for i in range(pebble_count):
		var p_x := rng.randf_range(10.0, floor_w - 20.0)
		var p_y := rng.randf_range(24.0, min(350.0, floor_h - 20.0))
		var pw := rng.randf_range(6.0, 14.0)
		var ph := rng.randf_range(5.0, 10.0)
		
		var pebble := ColorRect.new()
		pebble.name = "Pebble_%d" % i
		pebble.size = Vector2(pw, ph)
		pebble.position = Vector2(p_x, p_y)
		pebble.color = rock_colors[rng.randi() % rock_colors.size()]
		color_rect.add_child(pebble)

	# 4. 상단 잔디 트림 & 다채로운 돌출 풀 (Grass Trim & Hanging Tufts)
	var grass_trim := color_rect.get_node_or_null("GrassTrim") as ColorRect
	if grass_trim:
		grass_trim.color = Color(0.28, 0.72, 0.22, 1.0)
		grass_trim.size = Vector2(floor_w, 14.0)

		# 최상단 하이라이트 픽셀 선
		var top_edge := grass_trim.get_node_or_null("TopEdge") as ColorRect
		if not top_edge:
			top_edge = ColorRect.new()
			top_edge.name = "TopEdge"
			grass_trim.add_child(top_edge)
		top_edge.size = Vector2(floor_w, 3.0)
		top_edge.position = Vector2(0.0, 0.0)
		top_edge.color = Color(0.52, 0.90, 0.38, 1.0)

		# 잔디 하단 그림자 림
		var shadow_rim := grass_trim.get_node_or_null("ShadowRim") as ColorRect
		if not shadow_rim:
			shadow_rim = ColorRect.new()
			shadow_rim.name = "ShadowRim"
			grass_trim.add_child(shadow_rim)
		shadow_rim.size = Vector2(floor_w, 4.0)
		shadow_rim.position = Vector2(0.0, 14.0)
		shadow_rim.color = Color(0.16, 0.45, 0.12, 1.0)

		# 5. 불규칙 수직 돌출 픽셀 잔디 (Hanging Grass Tufts)
		var tuft_count := int(floor_w / 32.0)
		for i in range(tuft_count):
			var tx := float(i * 32 + (rng.randi() % 12))
			var th := rng.randf_range(4.0, 9.0)
			var tuft := ColorRect.new()
			tuft.name = "Tuft_%d" % i
			tuft.size = Vector2(6.0, th)
			tuft.position = Vector2(tx, 14.0)
			tuft.color = Color(0.22, 0.60, 0.18, 1.0)
			grass_trim.add_child(tuft)

		# 6. 지면 위 다채로운 풀포기 배치 (Surface Grass Tufts)
		for i in range(tuft_count):
			if rng.randf() > 0.4:
				var gx := float(i * 32 + (rng.randi() % 16))
				var grass_blade := ColorRect.new()
				grass_blade.name = "Blade_%d" % i
				grass_blade.size = Vector2(4.0, 6.0)
				grass_blade.position = Vector2(gx, -6.0)
				grass_blade.color = Color(0.45, 0.88, 0.32, 1.0)
				grass_trim.add_child(grass_blade)

func _decorate_platform(plat_node: Node2D) -> void:
	var color_rect := plat_node.get_node_or_null("ColorRect") as ColorRect
	if not color_rect:
		return
		
	color_rect.color = Color(0.46, 0.32, 0.18, 1.0)
	var plat_w := color_rect.size.x
	var plat_h := color_rect.size.y
	
	# 발판 상단 잔디
	var top_grass := color_rect.get_node_or_null("TopGrass") as ColorRect
	if not top_grass:
		top_grass = ColorRect.new()
		top_grass.name = "TopGrass"
		color_rect.add_child(top_grass)
	top_grass.size = Vector2(plat_w, 6.0)
	top_grass.position = Vector2(0.0, 0.0)
	top_grass.color = Color(0.32, 0.78, 0.24, 1.0)

	var top_rim := top_grass.get_node_or_null("TopRim") as ColorRect
	if not top_rim:
		top_rim = ColorRect.new()
		top_rim.name = "TopRim"
		top_grass.add_child(top_rim)
	top_rim.size = Vector2(plat_w, 2.0)
	top_rim.position = Vector2(0.0, 0.0)
	top_rim.color = Color(0.52, 0.90, 0.40, 1.0)

	# 발판 밑 돌출 잔디 (Hanging tufts for platforms)
	var tuft_count := int(plat_w / 28.0)
	for i in range(tuft_count):
		var tuft := top_grass.get_node_or_null("PlatTuft_%d" % i) as ColorRect
		if not tuft:
			tuft = ColorRect.new()
			tuft.name = "PlatTuft_%d" % i
			top_grass.add_child(tuft)
		tuft.size = Vector2(5.0, 4.0)
		tuft.position = Vector2(i * 28.0 + 8.0, 6.0)
		tuft.color = Color(0.20, 0.55, 0.16, 1.0)

	# 발판 하단 테두리
	var bot_border := color_rect.get_node_or_null("BotBorder") as ColorRect
	if not bot_border:
		bot_border = ColorRect.new()
		bot_border.name = "BotBorder"
		color_rect.add_child(bot_border)
	bot_border.size = Vector2(plat_w, 3.0)
	bot_border.position = Vector2(0.0, plat_h - 3.0)
	bot_border.color = Color(0.18, 0.10, 0.05, 1.0)
