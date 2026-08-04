extends Node2D
class_name TreeDecor

@export var tree_type: int = 1 # 1: Round Oak Tree, 2: Triangular Pine Tree

@onready var visual_root: Node2D = $VisualRoot

func _ready() -> void:
	z_index = -1 # Background / midground element
	_build_godot_pixel_tree()

func _build_godot_pixel_tree() -> void:
	if not is_instance_valid(visual_root):
		return

	for child in visual_root.get_children():
		child.queue_free()

	var outline_col := Color(0.08, 0.12, 0.08, 1.0)
	var trunk_col   := Color(0.42, 0.26, 0.15, 1.0)
	var trunk_shd   := Color(0.28, 0.16, 0.08, 1.0)
	var leaf_base   := Color(0.18, 0.54, 0.20, 1.0)
	var leaf_shadow := Color(0.10, 0.36, 0.12, 1.0)
	var leaf_light  := Color(0.38, 0.78, 0.28, 1.0)

	if tree_type == 1:
		# 1. 떡갈나무 (Oak Tree: Canopy height ~110px, trunk height ~45px)
		# A) 나무 기둥 외곽 테두리 (Trunk Outline & Base)
		var trunk_out := ColorRect.new()
		trunk_out.size = Vector2(28.0, 52.0)
		trunk_out.position = Vector2(-14.0, -52.0)
		trunk_out.color = outline_col
		visual_root.add_child(trunk_out)

		# 밑동 뿌리 확장 (Root flared base)
		var root_out := ColorRect.new()
		root_out.size = Vector2(40.0, 14.0)
		root_out.position = Vector2(-20.0, -14.0)
		root_out.color = outline_col
		visual_root.add_child(root_out)

		# B) 기둥 메인 브라운 (Trunk Body)
		var trunk_body := ColorRect.new()
		trunk_body.size = Vector2(20.0, 48.0)
		trunk_body.position = Vector2(-10.0, -50.0)
		trunk_body.color = trunk_col
		visual_root.add_child(trunk_body)

		var root_body := ColorRect.new()
		root_body.size = Vector2(34.0, 10.0)
		root_body.position = Vector2(-17.0, -12.0)
		root_body.color = trunk_col
		visual_root.add_child(root_body)

		# 기둥 나뭇결 그림자 (Bark Shadow)
		var trunk_line := ColorRect.new()
		trunk_line.size = Vector2(6.0, 48.0)
		trunk_line.position = Vector2(4.0, -50.0)
		trunk_line.color = trunk_shd
		visual_root.add_child(trunk_line)

		# C) 풍성한 픽셀 나뭇잎 상단 엽구 (Multi-cluster Round Canopy)
		# 1단 하부 잎 (Bottom Wide Leaves)
		var c1_out := ColorRect.new()
		c1_out.size = Vector2(104.0, 54.0)
		c1_out.position = Vector2(-52.0, -100.0)
		c1_out.color = outline_col
		visual_root.add_child(c1_out)

		var c1_shd := ColorRect.new()
		c1_shd.size = Vector2(96.0, 16.0)
		c1_shd.position = Vector2(-48.0, -64.0)
		c1_shd.color = leaf_shadow
		visual_root.add_child(c1_shd)

		var c1_body := ColorRect.new()
		c1_body.size = Vector2(96.0, 48.0)
		c1_body.position = Vector2(-48.0, -96.0)
		c1_body.color = leaf_base
		visual_root.add_child(c1_body)

		# 2단 중부 잎 (Mid Leaves)
		var c2_out := ColorRect.new()
		c2_out.size = Vector2(84.0, 44.0)
		c2_out.position = Vector2(-42.0, -132.0)
		c2_out.color = outline_col
		visual_root.add_child(c2_out)

		var c2_body := ColorRect.new()
		c2_body.size = Vector2(76.0, 38.0)
		c2_body.position = Vector2(-38.0, -128.0)
		c2_body.color = leaf_base
		visual_root.add_child(c2_body)

		# 3단 상부 잎 (Top Leaves)
		var c3_out := ColorRect.new()
		c3_out.size = Vector2(56.0, 32.0)
		c3_out.position = Vector2(-28.0, -154.0)
		c3_out.color = outline_col
		visual_root.add_child(c3_out)

		var c3_body := ColorRect.new()
		c3_body.size = Vector2(48.0, 26.0)
		c3_body.position = Vector2(-24.0, -150.0)
		c3_body.color = leaf_base
		visual_root.add_child(c3_body)

		# D) 픽셀 나뭇잎 하이라이트 (Leaf Top Highlights)
		var hl1 := ColorRect.new()
		hl1.size = Vector2(36.0, 10.0)
		hl1.position = Vector2(-18.0, -146.0)
		hl1.color = leaf_light
		visual_root.add_child(hl1)

		var hl2 := ColorRect.new()
		hl2.size = Vector2(28.0, 8.0)
		hl2.position = Vector2(-34.0, -122.0)
		hl2.color = leaf_light
		visual_root.add_child(hl2)

		var hl3 := ColorRect.new()
		hl3.size = Vector2(32.0, 8.0)
		hl3.position = Vector2(4.0, -90.0)
		hl3.color = leaf_light
		visual_root.add_child(hl3)

	else:
		# 2. 소나무 (Triangular Pine Tree)
		# 기둥
		var trunk_out := ColorRect.new()
		trunk_out.size = Vector2(22.0, 48.0)
		trunk_out.position = Vector2(-11.0, -48.0)
		trunk_out.color = outline_col
		visual_root.add_child(trunk_out)

		var trunk_body := ColorRect.new()
		trunk_body.size = Vector2(16.0, 44.0)
		trunk_body.position = Vector2(-8.0, -46.0)
		trunk_body.color = trunk_col
		visual_root.add_child(trunk_body)

		# 3단 피라미드 소나무 잎 (3-tier Pine Layers)
		# 하단 대형 층
		var t1_out := ColorRect.new()
		t1_out.size = Vector2(90.0, 36.0)
		t1_out.position = Vector2(-45.0, -80.0)
		t1_out.color = outline_col
		visual_root.add_child(t1_out)

		var t1_body := ColorRect.new()
		t1_body.size = Vector2(82.0, 30.0)
		t1_body.position = Vector2(-41.0, -76.0)
		t1_body.color = leaf_base
		visual_root.add_child(t1_body)

		# 중단 중형 층
		var t2_out := ColorRect.new()
		t2_out.size = Vector2(68.0, 32.0)
		t2_out.position = Vector2(-34.0, -106.0)
		t2_out.color = outline_col
		visual_root.add_child(t2_out)

		var t2_body := ColorRect.new()
		t2_body.size = Vector2(60.0, 26.0)
		t2_body.position = Vector2(-30.0, -102.0)
		t2_body.color = leaf_base
		visual_root.add_child(t2_body)

		# 상단 소형 탑 층
		var t3_out := ColorRect.new()
		t3_out.size = Vector2(44.0, 30.0)
		t3_out.position = Vector2(-22.0, -132.0)
		t3_out.color = outline_col
		visual_root.add_child(t3_out)

		var t3_body := ColorRect.new()
		t3_body.size = Vector2(36.0, 24.0)
		t3_body.position = Vector2(-18.0, -128.0)
		t3_body.color = leaf_base
		visual_root.add_child(t3_body)

		# 하이라이트
		var hl1 := ColorRect.new()
		hl1.size = Vector2(24.0, 6.0)
		hl1.position = Vector2(-12.0, -126.0)
		hl1.color = leaf_light
		visual_root.add_child(hl1)

		var hl2 := ColorRect.new()
		hl2.size = Vector2(36.0, 6.0)
		hl2.position = Vector2(-18.0, -100.0)
		hl2.color = leaf_light
		visual_root.add_child(hl2)
