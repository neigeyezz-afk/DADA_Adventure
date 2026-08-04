extends CharacterBody2D
class_name EnemyGolem


@export var speed: float = 40.0
@export var chase_speed: float = 65.0
@export var max_health: int = 8
@export var touch_damage: int = 3
@export var material_drop: int = 2
@export var golem_type: String = "wheat_golem" # wheat_golem, rice_golem, buckwheat_golem

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

enum State { PATROL, IDLE, CHASE }

var direction: int = -1
var target: Node2D = null
var health: int = 0
var _can_touch: bool = true
var _state: State = State.PATROL
var _state_timer: float = 0.0

@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var detection_zone: Area2D = $DetectionZone
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var touch_area: Area2D = $TouchDamage
@onready var visual_root: Node2D = get_node_or_null("VisualRoot")

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")

func _ready() -> void:
	health = max_health
	_build_pixel_golem()
	_apply_golem_style()
	detection_zone.body_entered.connect(_on_detection_zone_body_entered)
	detection_zone.body_exited.connect(_on_detection_zone_body_exited)
	hurtbox.hit_received.connect(_on_hit_received)
	touch_area.body_entered.connect(_on_touch_body)

func _build_pixel_golem() -> void:
	if not is_instance_valid(visual_root):
		return
	for c in visual_root.get_children():
		c.queue_free()
	if golem_type == "tree_golem":
		_build_tree_visual()
	else:
		_build_stone_golem_visual()

# 판타지 게임에 나올 법한 돌 골렘 NPC 픽셀 아트 (다리-몸통-어깨갑옷-팔-머리-발광 눈)
func _build_stone_golem_visual() -> void:
	var outline_col := Color(0.08, 0.06, 0.04, 1.0)
	var stone_dark  := Color(0.42, 0.36, 0.30, 1.0)
	var stone_mid   := Color(0.60, 0.52, 0.42, 1.0)
	var stone_light := Color(0.74, 0.66, 0.54, 1.0)
	var glow_col    := Color(1.0, 0.5, 0.15, 1.0)

	# 1. 다리
	for leg_x in [-14.0, 4.0]:
		var leg_out := ColorRect.new()
		leg_out.size = Vector2(12.0, 12.0)
		leg_out.position = Vector2(leg_x - 1.0, 13.0)
		leg_out.color = outline_col
		visual_root.add_child(leg_out)

		var leg := ColorRect.new()
		leg.size = Vector2(10.0, 10.0)
		leg.position = Vector2(leg_x, 14.0)
		leg.color = stone_dark
		visual_root.add_child(leg)

	# 2. 몸통 외곽 + 본체
	var torso_out := ColorRect.new()
	torso_out.size = Vector2(38.0, 30.0)
	torso_out.position = Vector2(-19.0, -12.0)
	torso_out.color = outline_col
	visual_root.add_child(torso_out)

	var torso := ColorRect.new()
	torso.size = Vector2(34.0, 26.0)
	torso.position = Vector2(-17.0, -10.0)
	torso.color = stone_mid
	visual_root.add_child(torso)

	# 3. 배 하이라이트 & 균열 텍스처
	var belly := ColorRect.new()
	belly.size = Vector2(18.0, 12.0)
	belly.position = Vector2(-9.0, -2.0)
	belly.color = stone_light
	visual_root.add_child(belly)

	var crack_l := ColorRect.new()
	crack_l.size = Vector2(3.0, 10.0)
	crack_l.position = Vector2(-13.0, -6.0)
	crack_l.color = stone_dark
	visual_root.add_child(crack_l)

	var crack_r := ColorRect.new()
	crack_r.size = Vector2(3.0, 8.0)
	crack_r.position = Vector2(9.0, 2.0)
	crack_r.color = stone_dark
	visual_root.add_child(crack_r)

	# 4. 어깨 갑옷 (판타지 NPC 느낌의 팔드론)
	for shoulder_x in [-19.0, 7.0]:
		var pauldron_out := ColorRect.new()
		pauldron_out.size = Vector2(16.0, 11.0)
		pauldron_out.position = Vector2(shoulder_x - 1.0, -15.0)
		pauldron_out.color = outline_col
		visual_root.add_child(pauldron_out)

		var pauldron := ColorRect.new()
		pauldron.size = Vector2(14.0, 9.0)
		pauldron.position = Vector2(shoulder_x, -14.0)
		pauldron.color = stone_dark
		visual_root.add_child(pauldron)

	# 5. 팔
	for arm_x in [-19.0, 13.0]:
		var arm_out := ColorRect.new()
		arm_out.size = Vector2(10.0, 20.0)
		arm_out.position = Vector2(arm_x - 1.0, -5.0)
		arm_out.color = outline_col
		visual_root.add_child(arm_out)

		var arm := ColorRect.new()
		arm.size = Vector2(8.0, 18.0)
		arm.position = Vector2(arm_x, -4.0)
		arm.color = stone_mid
		visual_root.add_child(arm)

	# 6. 머리
	var head_out := ColorRect.new()
	head_out.size = Vector2(22.0, 16.0)
	head_out.position = Vector2(-11.0, -26.0)
	head_out.color = outline_col
	visual_root.add_child(head_out)

	var head := ColorRect.new()
	head.size = Vector2(20.0, 14.0)
	head.position = Vector2(-10.0, -25.0)
	head.color = stone_mid
	visual_root.add_child(head)

	# 7. 발광하는 눈
	for eye_x in [-6.0, 2.0]:
		var eye := ColorRect.new()
		eye.size = Vector2(4.0, 4.0)
		eye.position = Vector2(eye_x, -19.0)
		eye.color = glow_col
		visual_root.add_child(eye)

# 걸어다니는 나무 몬스터 NPC 픽셀 아트 (뿌리발-나무줄기-가지팔-둥근 나뭇잎 수관-얼굴)
func _build_tree_visual() -> void:
	var outline_col := Color(0.10, 0.07, 0.04, 1.0)
	var bark_dark    := Color(0.32, 0.20, 0.10, 1.0)
	var bark_mid     := Color(0.45, 0.29, 0.14, 1.0)
	var leaf_dark    := Color(0.18, 0.42, 0.16, 1.0)
	var leaf_mid     := Color(0.28, 0.56, 0.22, 1.0)
	var leaf_light   := Color(0.42, 0.70, 0.30, 1.0)
	var fruit_col    := Color(0.92, 0.35, 0.25, 1.0)

	# 1. 뿌리 발
	for root_x in [-13.0, 3.0]:
		var root_out := ColorRect.new()
		root_out.size = Vector2(11.0, 11.0)
		root_out.position = Vector2(root_x - 1.0, 14.0)
		root_out.color = outline_col
		visual_root.add_child(root_out)

		var root := ColorRect.new()
		root.size = Vector2(9.0, 9.0)
		root.position = Vector2(root_x, 15.0)
		root.color = bark_dark
		visual_root.add_child(root)

	# 2. 줄기 (몸통)
	var trunk_out := ColorRect.new()
	trunk_out.size = Vector2(20.0, 28.0)
	trunk_out.position = Vector2(-11.0, -12.0)
	trunk_out.color = outline_col
	visual_root.add_child(trunk_out)

	var trunk := ColorRect.new()
	trunk.size = Vector2(16.0, 26.0)
	trunk.position = Vector2(-9.0, -11.0)
	trunk.color = bark_mid
	visual_root.add_child(trunk)

	var trunk_shade := ColorRect.new()
	trunk_shade.size = Vector2(4.0, 26.0)
	trunk_shade.position = Vector2(4.0, -11.0)
	trunk_shade.color = bark_dark
	visual_root.add_child(trunk_shade)

	# 3. 나뭇가지 팔
	for branch_x in [-19.0, 10.0]:
		var branch_out := ColorRect.new()
		branch_out.size = Vector2(11.0, 7.0)
		branch_out.position = Vector2(branch_x - 1.0, -4.0)
		branch_out.color = outline_col
		visual_root.add_child(branch_out)

		var branch := ColorRect.new()
		branch.size = Vector2(9.0, 5.0)
		branch.position = Vector2(branch_x, -3.0)
		branch.color = bark_mid
		visual_root.add_child(branch)

	# 4. 둥근 나뭇잎 수관 (여러 겹 잎사귀 뭉치로 풍성하게)
	var canopy_out := ColorRect.new()
	canopy_out.size = Vector2(38.0, 30.0)
	canopy_out.position = Vector2(-19.0, -42.0)
	canopy_out.color = outline_col
	visual_root.add_child(canopy_out)

	var canopy_positions: Array = [
		[Vector2(-17.0, -34.0), Vector2(16.0, 16.0), leaf_dark],
		[Vector2(-9.0, -40.0), Vector2(20.0, 18.0), leaf_mid],
		[Vector2(3.0, -36.0), Vector2(14.0, 14.0), leaf_mid],
		[Vector2(-6.0, -30.0), Vector2(14.0, 12.0), leaf_light],
	]
	for entry in canopy_positions:
		var blob := ColorRect.new()
		blob.position = entry[0]
		blob.size = entry[1]
		blob.color = entry[2]
		visual_root.add_child(blob)

	# 열매 포인트
	for fruit_pos in [Vector2(-12.0, -28.0), Vector2(8.0, -33.0)]:
		var fruit := ColorRect.new()
		fruit.size = Vector2(4.0, 4.0)
		fruit.position = fruit_pos
		fruit.color = fruit_col
		visual_root.add_child(fruit)

	# 5. 줄기 위 얼굴 (친근한 NPC 표정)
	for eye_x in [-5.0, 2.0]:
		var eye := ColorRect.new()
		eye.size = Vector2(3.0, 4.0)
		eye.position = Vector2(eye_x, -6.0)
		eye.color = outline_col
		visual_root.add_child(eye)

	var mouth := ColorRect.new()
	mouth.size = Vector2(6.0, 2.0)
	mouth.position = Vector2(-3.0, 1.0)
	mouth.color = outline_col
	visual_root.add_child(mouth)

func _apply_golem_style() -> void:
	if not is_instance_valid(visual_root):
		return
	if golem_type == "tree_golem":
		max_health = 10
		touch_damage = 0
		speed = 40.0
		chase_speed = 40.0
		material_drop = 1
		visual_root.modulate = Color(1.0, 1.0, 1.0)
	elif scale.x > 1.5:
		max_health = 8
		touch_damage = 2
		speed = 10.0
		chase_speed = 65.0
		material_drop = 2
		visual_root.modulate = Color(1.0, 0.92, 0.78)
	else:
		max_health = 5
		touch_damage = 2
		speed = 20.0
		chase_speed = 65.0
		material_drop = 1
		visual_root.modulate = Color(1.0, 0.92, 0.78)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	match _state:
		State.CHASE:
			_chase()
		State.IDLE:
			_idle(delta)
		State.PATROL:
			_patrol(delta)

	if is_instance_valid(visual_root):
		visual_root.scale.x = -1.0 if direction < 0 else 1.0

	move_and_slide()

func _patrol(delta: float) -> void:
	if (is_on_floor() and not ledge_check.is_colliding()) or is_on_wall():
		_flip_direction()
		_state = State.IDLE
		_state_timer = 1.0
		velocity.x = 0.0
		return

	velocity.x = direction * speed

func _idle(delta: float) -> void:
	velocity.x = 0.0
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state = State.PATROL

func _chase() -> void:
	if target:
		direction = 1 if target.global_position.x > global_position.x else -1
		ledge_check.position.x = abs(ledge_check.position.x) * direction
		velocity.x = direction * chase_speed

func take_damage(damage: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	var dir := global_position - attacker_pos
	_on_hit_received(damage, dir)

func _on_hit_received(damage: int, dir: Vector2) -> void:
	health -= damage
	velocity.x = signf(dir.x) * 100.0
	velocity.y = -80.0
	if SoundManager:
		SoundManager.play_hit()
	FloatingText.spawn(get_parent(), global_position, "-%d" % damage, Color(1, 0.9, 0.3))
	_flash()
	if health <= 0:
		_die()

func _flash() -> void:
	if is_instance_valid(visual_root):
		visual_root.modulate = Color(1, 1, 1)
	await get_tree().create_timer(0.08).timeout
	_apply_golem_style()

func _die() -> void:
	var drop_name: String = "noodle_dough"
	if golem_type == "tree_golem":
		drop_name = "firewood"

	for i in material_drop:
		_spawn_pickup("material", 1, Vector2(randf_range(-16, 16), -10), drop_name)
	_spawn_pickup("gold", 3, Vector2(randf_range(-12, 12), -10))
	queue_free()

func _spawn_pickup(kind: String, amount: int, offset: Vector2, material_name_override: String = "") -> void:
	var pos := global_position + offset
	call_deferred("_deferred_spawn_pickup", kind, amount, pos, material_name_override)

func _deferred_spawn_pickup(kind: String, amount: int, pos: Vector2, material_name_override: String) -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return
	var p := PICKUP_SCENE.instantiate() as Pickup
	parent_node.add_child(p)
	p.global_position = pos
	p.setup(kind, amount, material_name_override)

func _on_touch_body(body: Node2D) -> void:
	if body is PlayerDADA:
		_try_touch(body as PlayerDADA)

func _try_touch(body: PlayerDADA) -> void:
	if not _can_touch:
		return
	_can_touch = false
	body.take_damage(touch_damage, body.global_position - global_position)
	await get_tree().create_timer(1.0).timeout
	_can_touch = true
	if is_instance_valid(body) and body in touch_area.get_overlapping_bodies():
		_try_touch(body)

func _on_detection_zone_body_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		target = body
		_state = State.CHASE

func _on_detection_zone_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		_state = State.PATROL

func _flip_direction() -> void:
	direction *= -1
	ledge_check.position.x = abs(ledge_check.position.x) * direction
