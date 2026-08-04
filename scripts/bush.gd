extends Node2D
class_name BushFoliage

@export var bush_type: int = 1 # 1: Large Triple, 2: Medium Round, 3: Tall Leafy, 4: Wild Grass, 5: Berry Bush
@export var custom_scale: Vector2 = Vector2(1.0, 1.0)

@onready var visual_root: Node2D = $VisualRoot

func _ready() -> void:
	z_index = 15 # Render in front of DADA (10) and Slime (5-10) to hide them
	scale = custom_scale
	_build_godot_pixel_bush()

func _build_godot_pixel_bush() -> void:
	if not is_instance_valid(visual_root):
		return

	for child in visual_root.get_children():
		child.queue_free()

	var outline_col := Color(0.06, 0.12, 0.06, 1.0)
	var base_green  := Color(0.20, 0.62, 0.22, 1.0)
	var shadow_green:= Color(0.12, 0.42, 0.14, 1.0)
	var light_green := Color(0.42, 0.82, 0.30, 1.0)
	var berry_red   := Color(0.92, 0.22, 0.25, 1.0)

	if bush_type == 1:
		# 1. 대형 3단 모듬 풀숲 (Large Triple-Lobe Bush: 76x46)
		var outline_rect := ColorRect.new()
		outline_rect.size = Vector2(80.0, 46.0)
		outline_rect.position = Vector2(-40.0, -46.0)
		outline_rect.color = outline_col
		visual_root.add_child(outline_rect)

		var top_outline := ColorRect.new()
		top_outline.size = Vector2(56.0, 10.0)
		top_outline.position = Vector2(-28.0, -54.0)
		top_outline.color = outline_col
		visual_root.add_child(top_outline)

		var shd := ColorRect.new()
		shd.size = Vector2(76.0, 14.0)
		shd.position = Vector2(-38.0, -16.0)
		shd.color = shadow_green
		visual_root.add_child(shd)

		var body_main := ColorRect.new()
		body_main.size = Vector2(76.0, 34.0)
		body_main.position = Vector2(-38.0, -44.0)
		body_main.color = base_green
		visual_root.add_child(body_main)

		var body_top := ColorRect.new()
		body_top.size = Vector2(52.0, 10.0)
		body_top.position = Vector2(-26.0, -52.0)
		body_top.color = base_green
		visual_root.add_child(body_top)

		var hl1 := ColorRect.new()
		hl1.size = Vector2(30.0, 8.0)
		hl1.position = Vector2(-22.0, -50.0)
		hl1.color = light_green
		visual_root.add_child(hl1)

		var hl2 := ColorRect.new()
		hl2.size = Vector2(18.0, 6.0)
		hl2.position = Vector2(12.0, -40.0)
		hl2.color = light_green
		visual_root.add_child(hl2)

	elif bush_type == 2:
		# 2. 중형 둥근 풀숲 (Medium Round Bush: 56x36)
		var outline_rect := ColorRect.new()
		outline_rect.size = Vector2(58.0, 34.0)
		outline_rect.position = Vector2(-29.0, -34.0)
		outline_rect.color = outline_col
		visual_root.add_child(outline_rect)

		var top_outline := ColorRect.new()
		top_outline.size = Vector2(38.0, 8.0)
		top_outline.position = Vector2(-19.0, -40.0)
		top_outline.color = outline_col
		visual_root.add_child(top_outline)

		var shd := ColorRect.new()
		shd.size = Vector2(54.0, 10.0)
		shd.position = Vector2(-27.0, -12.0)
		shd.color = shadow_green
		visual_root.add_child(shd)

		var body_main := ColorRect.new()
		body_main.size = Vector2(54.0, 24.0)
		body_main.position = Vector2(-27.0, -32.0)
		body_main.color = base_green
		visual_root.add_child(body_main)

		var body_top := ColorRect.new()
		body_top.size = Vector2(34.0, 8.0)
		body_top.position = Vector2(-17.0, -38.0)
		body_top.color = base_green
		visual_root.add_child(body_top)

		var hl1 := ColorRect.new()
		hl1.size = Vector2(20.0, 6.0)
		hl1.position = Vector2(-14.0, -36.0)
		hl1.color = light_green
		visual_root.add_child(hl1)

	elif bush_type == 3:
		# 3. 우거진 키 큰 픽셀 풀숲 (Tall Leafy Bush: 48x54)
		var outline_rect := ColorRect.new()
		outline_rect.size = Vector2(50.0, 52.0)
		outline_rect.position = Vector2(-25.0, -52.0)
		outline_rect.color = outline_col
		visual_root.add_child(outline_rect)

		var top_outline := ColorRect.new()
		top_outline.size = Vector2(32.0, 10.0)
		top_outline.position = Vector2(-16.0, -60.0)
		top_outline.color = outline_col
		visual_root.add_child(top_outline)

		var shd := ColorRect.new()
		shd.size = Vector2(46.0, 12.0)
		shd.position = Vector2(-23.0, -14.0)
		shd.color = shadow_green
		visual_root.add_child(shd)

		var body_main := ColorRect.new()
		body_main.size = Vector2(46.0, 42.0)
		body_main.position = Vector2(-23.0, -50.0)
		body_main.color = base_green
		visual_root.add_child(body_main)

		var body_top := ColorRect.new()
		body_top.size = Vector2(28.0, 10.0)
		body_top.position = Vector2(-14.0, -58.0)
		body_top.color = base_green
		visual_root.add_child(body_top)

		var hl1 := ColorRect.new()
		hl1.size = Vector2(18.0, 8.0)
		hl1.position = Vector2(-10.0, -56.0)
		hl1.color = light_green
		visual_root.add_child(hl1)

	elif bush_type == 4:
		# 4. 야생 픽셀 풀더미 (Wild Grass Patch: 44x28)
		var outline_rect := ColorRect.new()
		outline_rect.size = Vector2(46.0, 26.0)
		outline_rect.position = Vector2(-23.0, -26.0)
		outline_rect.color = outline_col
		visual_root.add_child(outline_rect)

		var shd := ColorRect.new()
		shd.size = Vector2(42.0, 8.0)
		shd.position = Vector2(-21.0, -10.0)
		shd.color = shadow_green
		visual_root.add_child(shd)

		var body_main := ColorRect.new()
		body_main.size = Vector2(42.0, 18.0)
		body_main.position = Vector2(-21.0, -24.0)
		body_main.color = base_green
		visual_root.add_child(body_main)

		# 픽셀 풀잎 톱니 세로 깃
		for gx in [-15, -5, 5, 12]:
			var blade := ColorRect.new()
			blade.size = Vector2(4.0, 8.0)
			blade.position = Vector2(float(gx), -30.0)
			blade.color = light_green
			visual_root.add_child(blade)

	else:
		# 5. 열매 풀숲 (Berry Flowering Bush: 64x40 + Red Berries)
		var outline_rect := ColorRect.new()
		outline_rect.size = Vector2(66.0, 38.0)
		outline_rect.position = Vector2(-33.0, -38.0)
		outline_rect.color = outline_col
		visual_root.add_child(outline_rect)

		var shd := ColorRect.new()
		shd.size = Vector2(62.0, 12.0)
		shd.position = Vector2(-31.0, -14.0)
		shd.color = shadow_green
		visual_root.add_child(shd)

		var body_main := ColorRect.new()
		body_main.size = Vector2(62.0, 28.0)
		body_main.position = Vector2(-31.0, -36.0)
		body_main.color = base_green
		visual_root.add_child(body_main)

		var hl1 := ColorRect.new()
		hl1.size = Vector2(24.0, 6.0)
		hl1.position = Vector2(-16.0, -34.0)
		hl1.color = light_green
		visual_root.add_child(hl1)

		# 빨간 픽셀 열매 (Red Pixel Berries)
		var berry_positions: Array[Vector2] = [
			Vector2(-20.0, -26.0),
			Vector2(-8.0, -30.0),
			Vector2(6.0, -24.0),
			Vector2(18.0, -28.0),
			Vector2(-12.0, -16.0),
			Vector2(12.0, -18.0)
		]
		for b_pos in berry_positions:
			var berry := ColorRect.new()
			berry.size = Vector2(5.0, 5.0)
			berry.position = b_pos
			berry.color = berry_red
			visual_root.add_child(berry)
