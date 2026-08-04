extends Area2D
class_name Ladder

@export var height: float = 160.0:
	set(val):
		height = val
		_update_ladder_shape_and_visuals()

@export var is_vine: bool = true:
	set(val):
		is_vine = val
		_update_ladder_shape_and_visuals()

@export var is_broken_top: bool = false:
	set(val):
		is_broken_top = val
		_update_ladder_shape_and_visuals()

@export var is_single_strand: bool = false:
	set(val):
		is_single_strand = val
		_update_ladder_shape_and_visuals()

# 밑에서부터 위로 일정 비율(예: 0.6 = 60%)만큼 외줄/사다리를 지우는 속성
@export var bottom_cut_ratio: float = 0.0:
	set(val):
		bottom_cut_ratio = clampf(val, 0.0, 0.9)
		_update_ladder_shape_and_visuals()

# 좌우 pendulum 수평 스윙 덩쿨 기믹
@export var is_swinging: bool = false

# 등반 중 절반 이상 올라가면 예고 없이 끊어지는 함정 외줄 (플레이어가 추락 + 피격)
@export var can_snap: bool = false
var has_snapped: bool = false
var _swing_time: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_container: Node2D = $VisualContainer

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player collision layer (DADA)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_ladder_shape_and_visuals()

# 외줄이 끊어질 때 호출 - 더 이상 등반 불가능한 시든 덩쿨로 전환
func trigger_snap() -> void:
	if has_snapped:
		return
	has_snapped = true
	monitoring = false
	monitorable = false
	if is_instance_valid(visual_container):
		visual_container.modulate = Color(0.5, 0.38, 0.16, 1.0)

func _physics_process(delta: float) -> void:
	if is_swinging:
		_swing_time += delta
		rotation_degrees = sin(_swing_time * 2.5) * 18.0

	# 사다리 영역 내 플레이어가 위치해 있으면 지속적으로 사다리 탑승 가능 상태 유지
	for body in get_overlapping_bodies():
		if body is PlayerDADA:
			body.set_on_ladder(true, self)

func _update_ladder_shape_and_visuals() -> void:
	if not is_inside_tree():
		return

	var active_height := height * (1.0 - bottom_cut_ratio)

	if is_instance_valid(collision_shape):
		var shape := RectangleShape2D.new()
		# 발판 상단 표면 너머(+24px)까지 튀어나오도록 감지 영역 대폭 확충
		shape.size = Vector2(50.0, active_height + 90.0)
		collision_shape.shape = shape
		collision_shape.position = Vector2(0.0, -height + (active_height * 0.5) - 25.0)

	if is_instance_valid(visual_container):
		for child in visual_container.get_children():
			child.queue_free()

		var vine_stem   := Color(0.20, 0.64, 0.22, 1.0)
		var vine_rung   := Color(0.28, 0.72, 0.26, 1.0)
		var leaf_light  := Color(0.46, 0.86, 0.32, 1.0)
		var dead_yellow := Color(0.76, 0.65, 0.22, 1.0) # 시든 탁한 노란색
		var dead_dark   := Color(0.48, 0.38, 0.12, 1.0)

		# 발판 두께 윗부분 너머로 24px 튀어나오는 연장 높이 (-height - 36.0)
		var top_reach_y := -height - 36.0

		if is_single_strand:
			# ----------------------------------------------------
			# 외줄 덩쿨 픽셀 그래픽 (Single-Strand Climbing Vine)
			# ----------------------------------------------------
			var total_len := height + 36.0
			var active_len := total_len * (1.0 - bottom_cut_ratio)

			var main_rope := ColorRect.new()
			main_rope.size = Vector2(8.0, active_len)
			main_rope.position = Vector2(-4.0, top_reach_y)
			main_rope.color = vine_stem
			visual_container.add_child(main_rope)

			var leaf_count := int(active_len / 14.0)
			for i in range(leaf_count):
				var curr_y := top_reach_y + (i * 14.0) + 4.0
				var leaf := ColorRect.new()
				leaf.size = Vector2(8.0, 5.0)
				var side := -1.0 if (i % 2 == 0) else 1.0
				leaf.position = Vector2(side * 6.0 - 4.0, curr_y)
				leaf.color = leaf_light
				visual_container.add_child(leaf)
		elif is_vine:
			# ----------------------------------------------------
			# 이중 덩쿨 사다리 픽셀 그래픽 (Double Vine Ladder)
			# ----------------------------------------------------
			if is_broken_top:
				# 1) 좌측 줄기 (상단 65px 시든 탁한 노란색)
				var left_rail_good := ColorRect.new()
				left_rail_good.size = Vector2(5.0, height - 65.0 + 36.0)
				left_rail_good.position = Vector2(-12.0, -height + 65.0)
				left_rail_good.color = vine_stem
				visual_container.add_child(left_rail_good)

				var left_rail_dead := ColorRect.new()
				left_rail_dead.size = Vector2(5.0, 65.0)
				left_rail_dead.position = Vector2(-12.0, top_reach_y)
				left_rail_dead.color = dead_yellow
				visual_container.add_child(left_rail_dead)

				# 2) 우측 줄기 (상단 70px 구간은 파손되어 완전히 잘림/지워짐!)
				var right_rail := ColorRect.new()
				right_rail.size = Vector2(5.0, height - 70.0)
				right_rail.position = Vector2(7.0, -height + 70.0)
				right_rail.color = vine_stem
				visual_container.add_child(right_rail)

				# 우측 줄기 잘린 끊김 마디 (Dead severed stub)
				var right_stub := ColorRect.new()
				right_stub.size = Vector2(5.0, 10.0)
				right_stub.position = Vector2(7.0, -height + 60.0)
				right_stub.color = dead_dark
				visual_container.add_child(right_stub)

				# 3) 마디 디딤대 렌더링
				var step_count := int((height + 36.0) / 16.0)
				for i in range(step_count):
					var curr_y := top_reach_y + (i * 16.0) + 6.0
					var is_in_broken_zone := (curr_y < -height + 65.0)

					if is_in_broken_zone:
						var dead_rung := ColorRect.new()
						dead_rung.size = Vector2(7.0, 4.0)
						dead_rung.position = Vector2(-12.0, curr_y)
						dead_rung.color = dead_yellow
						visual_container.add_child(dead_rung)
					else:
						var rung := ColorRect.new()
						rung.size = Vector2(16.0, 5.0)
						rung.position = Vector2(-8.0, curr_y)
						rung.color = vine_rung
						visual_container.add_child(rung)

						var leaf_l := ColorRect.new()
						leaf_l.size = Vector2(6.0, 4.0)
						leaf_l.position = Vector2(-17.0, curr_y - 2.0)
						leaf_l.color = leaf_light
						visual_container.add_child(leaf_l)

						var leaf_r := ColorRect.new()
						leaf_r.size = Vector2(6.0, 4.0)
						leaf_r.position = Vector2(11.0, curr_y + 2.0)
						leaf_r.color = leaf_light
						visual_container.add_child(leaf_r)
			else:
				# 정상 덩쿨 사다리 (Normal Double Vine)
				var left_rail := ColorRect.new()
				left_rail.size = Vector2(5.0, height + 36.0)
				left_rail.position = Vector2(-12.0, top_reach_y)
				left_rail.color = vine_stem
				visual_container.add_child(left_rail)

				var right_rail := ColorRect.new()
				right_rail.size = Vector2(5.0, height + 36.0)
				right_rail.position = Vector2(7.0, top_reach_y)
				right_rail.color = vine_stem
				visual_container.add_child(right_rail)

				var step_count := int((height + 36.0) / 16.0)
				for i in range(step_count):
					var curr_y := top_reach_y + (i * 16.0) + 6.0
					var rung := ColorRect.new()
					rung.size = Vector2(16.0, 5.0)
					rung.position = Vector2(-8.0, curr_y)
					rung.color = vine_rung
					visual_container.add_child(rung)

					var leaf_l := ColorRect.new()
					leaf_l.size = Vector2(6.0, 4.0)
					leaf_l.position = Vector2(-17.0, curr_y - 2.0)
					leaf_l.color = leaf_light
					visual_container.add_child(leaf_l)

					var leaf_r := ColorRect.new()
					leaf_r.size = Vector2(6.0, 4.0)
					leaf_r.position = Vector2(11.0, curr_y + 2.0)
					leaf_r.color = leaf_light
					visual_container.add_child(leaf_r)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		body.set_on_ladder(true, self)

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerDADA:
		body.set_on_ladder(false, self)
