extends CharacterBody2D
class_name EnemySlime

const FloatingText = preload("res://scripts/floating_text.gd")

@export var speed: float = 56.0
@export var chase_speed: float = 98.0
@export var max_health: int = 3
@export var touch_damage: int = 1
@export var material_drop: int = 1

@export_range(1, 3, 1) var level: int = 1
const LEVEL_MULTIPLIER: Dictionary = {1: 1.0, 2: 2.0, 3: 3.0}
const LEVEL2_COLOR: Color = Color(0.2, 0.85, 0.3)
const LEVEL3_COLOR: Color = Color(0.85, 0.1, 0.1)
const LEVEL3_REWARD_MULTIPLIER: float = 1.5

@export var level2_hop_height_ratio: float = 0.5
@export var level2_hop_interval_min: float = 1.5
@export var level2_hop_interval_max: float = 4.0

@export var idle_chance: float = 0.35
@export var idle_duration_min: float = 0.4
@export var idle_duration_max: float = 1.1
@export var early_turn_chance: float = 0.25
@export var early_turn_interval_min: float = 1.0
@export var early_turn_interval_max: float = 2.5
@export var search_duration: float = 1.5

@export var can_climb: bool = true
@export var jump_velocity: float = -520.0

@export var visual_skin: String = "slime" # "slime" 또는 "flower" (외형만 위장하는 몬스터용)
@export var is_flower_monster: bool = false

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _mouth_open: float = 0.0
var _mouth_open_target: float = 0.0

enum State { PATROL, IDLE, CHASE, SEARCH }

var direction: int = -1
var target: Node2D = null
var health: int = 0
var _can_touch: bool = true
var _base_color: Color = Color(1, 1, 0)

var _state: State = State.PATROL
var _state_timer: float = 0.0
var _early_turn_timer: float = 0.0
var _last_known_target_pos: Vector2 = Vector2.ZERO
var _speed_variance: float = 1.0
var _reward_multiplier: float = 1.0
var _hop_timer: float = 0.0

@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var detection_zone: Area2D = $DetectionZone
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var touch_area: Area2D = $TouchDamage
@onready var body_rect: ColorRect = (get_node_or_null("VisualPivot/BodyRect") if get_node_or_null("VisualPivot/BodyRect") else get_node_or_null("ColorRect")) as ColorRect
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")

func _ready() -> void:
	_apply_level()
	health = max_health
	detection_zone.body_entered.connect(_on_detection_zone_body_entered)
	detection_zone.body_exited.connect(_on_detection_zone_body_exited)
	hurtbox.hit_received.connect(_on_hit_received)
	touch_area.body_entered.connect(_on_touch_body)
	_update_ledge_check_side()
	_update_facing_visuals()
	_speed_variance = randf_range(0.85, 1.15)
	_reset_early_turn_timer()
	if level == 2:
		_hop_timer = randf_range(level2_hop_interval_min, level2_hop_interval_max)

func _get_slime_texture(lvl: int) -> Texture2D:
	var path := "res://assets/sprites/slime_lv1_2_skyblue.png"
	if lvl == 3:
		path = "res://assets/sprites/slime_lv3_blue.png"
	elif lvl >= 4:
		path = "res://assets/sprites/slime_lv4_ivory.png"
	if FileAccess.file_exists(path):
		var global_p := ProjectSettings.globalize_path(path)
		if global_p != "":
			var img := Image.load_from_file(global_p)
			if img and not img.is_empty():
				return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null

func _apply_level() -> void:
	if visual_skin == "flower":
		if is_flower_monster:
			max_health = 2
			touch_damage = 3
			speed = 66.0
			chase_speed = 120.0
		else:
			max_health = 1
			touch_damage = 1
			speed = 56.0
		_build_flower_skin()
		return

	var rim_color := Color(0.15, 0.65, 0.25, 1)

	if level == 1:
		max_health = 2
		touch_damage = 1
		speed = 56.0
		chase_speed = 98.0
		_base_color = Color(0.35, 0.78, 0.95, 1) # 스카이블루 슬라임 (소)
		rim_color = Color(0.2, 0.58, 0.78, 1)
	elif level == 2:
		max_health = 2
		touch_damage = 2
		speed = 56.0
		chase_speed = 98.0
		_base_color = Color(0.2, 0.85, 0.3, 1) # 스카이블루 슬라임 (중 - 호핑)
		rim_color = Color(0.1, 0.65, 0.2, 1)
	elif level == 3:
		max_health = 3
		touch_damage = 1
		speed = 98.0
		chase_speed = 130.0
		_base_color = Color(0.25, 0.82, 0.35, 1) # 그린 슬라임 (추적)
		rim_color = Color(0.15, 0.65, 0.25, 1)
	elif level == 4:
		max_health = 3
		touch_damage = 2
		speed = 130.0
		chase_speed = 150.0
		_base_color = Color(0.12, 0.35, 0.88, 1) # 블루 슬라임 (고속)
		rim_color = Color(0.08, 0.22, 0.68, 1)
	elif level >= 5:
		max_health = 4
		touch_damage = 2
		speed = 110.0
		chase_speed = 130.0
		_base_color = Color(0.96, 0.95, 0.90, 1) # 아이보리 슬라임 (육수)
		rim_color = Color(0.85, 0.82, 0.75, 1)
	
	if is_instance_valid(sprite):
		sprite.visible = false
	if is_instance_valid(body_rect):
		body_rect.visible = true
		body_rect.color = _base_color
		var bottom_rim := body_rect.get_node_or_null("BottomRim") as ColorRect
		if bottom_rim:
			bottom_rim.color = rim_color

# 슬라임을 Flower1(하늘색 꽃)과 같은 외형으로 위장시키는 스킨 (능력치는 그대로 슬라임)
func _build_flower_skin() -> void:
	var pivot := get_node_or_null("VisualPivot") as Node2D
	if not is_instance_valid(pivot):
		return
	for c in pivot.get_children():
		c.queue_free()
	if is_instance_valid(sprite):
		sprite.visible = false
	if is_instance_valid(body_rect):
		body_rect.visible = false

	var petal_color  := Color(0.25, 0.65, 0.95, 1.0) # Sky Blue - Flower1(flower_type=1)과 동일
	var center_color := Color(1.0, 0.85, 0.20, 1.0)
	var stem_color   := Color(0.25, 0.65, 0.22, 1.0)
	var outline_col  := Color(0.10, 0.14, 0.18, 1.0)
	var leaf_color   := Color(0.18, 0.52, 0.16, 1.0)

	var stem_out := ColorRect.new()
	stem_out.size = Vector2(6.0, 16.0)
	stem_out.position = Vector2(-3.0, 0.0)
	stem_out.color = outline_col
	pivot.add_child(stem_out)

	var stem_body := ColorRect.new()
	stem_body.size = Vector2(3.0, 14.0)
	stem_body.position = Vector2(-1.5, 1.0)
	stem_body.color = stem_color
	pivot.add_child(stem_body)

	var leaf_l := ColorRect.new()
	leaf_l.size = Vector2(6.0, 4.0)
	leaf_l.position = Vector2(-8.0, 8.0)
	leaf_l.color = leaf_color
	pivot.add_child(leaf_l)

	var leaf_r := ColorRect.new()
	leaf_r.size = Vector2(6.0, 4.0)
	leaf_r.position = Vector2(2.0, 5.0)
	leaf_r.color = leaf_color
	pivot.add_child(leaf_r)

	var py := -14.0
	var petal_positions: Array[Vector2] = [
		Vector2(-4.0, py - 9.0),
		Vector2(-4.0, py + 3.0),
		Vector2(-10.0, py - 3.0),
		Vector2(2.0, py - 3.0),
		Vector2(-8.0, py - 7.0),
		Vector2(0.0, py - 7.0),
		Vector2(-8.0, py + 1.0),
		Vector2(0.0, py + 1.0),
	]
	for p_pos in petal_positions:
		var p_out := ColorRect.new()
		p_out.size = Vector2(8.0, 8.0)
		p_out.position = p_pos + Vector2(-1.0, -1.0)
		p_out.color = outline_col
		pivot.add_child(p_out)
	for p_pos in petal_positions:
		var p_body := ColorRect.new()
		p_body.size = Vector2(6.0, 6.0)
		p_body.position = p_pos
		p_body.color = petal_color
		pivot.add_child(p_body)

	var center_out := ColorRect.new()
	center_out.size = Vector2(10.0, 10.0)
	center_out.position = Vector2(-5.0, py - 5.0)
	center_out.color = outline_col
	pivot.add_child(center_out)

	var center_box := ColorRect.new()
	center_box.size = Vector2(8.0, 8.0)
	center_box.position = Vector2(-4.0, py - 4.0)
	center_box.color = center_color
	pivot.add_child(center_box)

	var shine := ColorRect.new()
	shine.size = Vector2(3.0, 3.0)
	shine.position = Vector2(-2.5, py - 2.5)
	shine.color = Color(1.0, 1.0, 1.0, 0.85)
	pivot.add_child(shine)

	var mouth := ColorRect.new()
	mouth.name = "FlowerMouth"
	mouth.size = Vector2(18.0, 4.0)
	mouth.position = Vector2(-9.0, py + 10.0)
	mouth.color = Color(0.16, 0.12, 0.06, 1.0)
	mouth.visible = false
	pivot.add_child(mouth)

var _motion_phase: int = 0
var _motion_timer: float = 0.0
const MOTION_FRAME_TIME: float = 0.14

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif level == 2:
		_maybe_random_hop(delta)

	if is_flower_monster:
		_update_flower_mouth(delta)

	match _state:
		State.CHASE:
			_chase()
		State.SEARCH:
			_search(delta)
		State.IDLE:
			_idle(delta)
		State.PATROL:
			_patrol(delta)

	move_and_slide()
	_update_forward_motion_animation(delta)

func _update_flower_mouth(delta: float) -> void:
	_mouth_open = clamp(lerp(_mouth_open, _mouth_open_target, delta * 6.0), 0.0, 1.0)

	var mouth := get_node_or_null("VisualPivot/FlowerMouth") as ColorRect
	if not is_instance_valid(mouth):
		return

	var width := 18.0 + 14.0 * _mouth_open
	var height := 4.0 + 5.0 * _mouth_open
	mouth.size = Vector2(width, height)
	mouth.position = Vector2(-width * 0.5, -10.0 + 8.0 * _mouth_open)
	mouth.visible = _mouth_open > 0.05

func _update_forward_motion_animation(delta: float) -> void:
	var pivot := get_node_or_null("VisualPivot") as Node2D
	if not is_instance_valid(pivot):
		return

	var is_moving: bool = abs(velocity.x) > 5.0
	if not is_moving or not is_on_floor():
		_motion_phase = 0
		_motion_timer = 0.0
		# (1) 정지 상태 (Idle)
		pivot.scale = Vector2(1.0, 1.0)
		pivot.position = Vector2.ZERO
		return

	_motion_timer += delta
	if _motion_timer >= MOTION_FRAME_TIME:
		_motion_timer -= MOTION_FRAME_TIME
		_motion_phase = (_motion_phase + 1) % 4

	match _motion_phase:
		0:
			# (1) 정지 상태
			pivot.scale = Vector2(1.0, 1.0)
			pivot.position = Vector2.ZERO
		1:
			# (2) 앞으로 이동 모션 1 (압축 & 웅크리기)
			pivot.scale = Vector2(1.18, 0.82)
			pivot.position = Vector2(direction * 2.0, 3.0)
		2:
			# (3) 앞으로 이동 모션 2 (더 큰 움직임: 공중 늘어남 & 전방 도약)
			pivot.scale = Vector2(0.82, 1.28)
			pivot.position = Vector2(direction * 7.0, -6.0)
		3:
			# (4) 다시 정지 상태 (착지 후 복원)
			pivot.scale = Vector2(1.10, 0.90)
			pivot.position = Vector2(direction * 3.0, 1.5)

func _patrol(delta: float) -> void:
	if (is_on_floor() and not ledge_check.is_colliding()) or is_on_wall():
		_flip_direction()
		if randf() < idle_chance:
			_state = State.IDLE
			_state_timer = randf_range(idle_duration_min, idle_duration_max)
			velocity.x = 0.0
			return
	else:
		_early_turn_timer -= delta
		if _early_turn_timer <= 0.0:
			_reset_early_turn_timer()
			if randf() < early_turn_chance:
				_flip_direction()

	velocity.x = direction * speed * _speed_variance

func _idle(delta: float) -> void:
	velocity.x = 0.0
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state = State.PATROL
		_reset_early_turn_timer()

func _chase() -> void:
	if not is_instance_valid(target):
		_state = State.SEARCH
		_state_timer = search_duration
		_mouth_open_target = 0.0
		return

	var previous_direction := direction
	direction = 1 if target.global_position.x > global_position.x else -1
	if direction != previous_direction:
		_update_ledge_check_side()
		_update_facing_visuals()

	if is_flower_monster and _mouth_open < 0.5:
		velocity.x = 0.0
	else:
		velocity.x = direction * chase_speed

	_last_known_target_pos = target.global_position
	_try_climb(target.global_position.y)

func _search(delta: float) -> void:
	var to_last := _last_known_target_pos.x - global_position.x
	if absf(to_last) < 8.0:
		velocity.x = 0.0
		_state_timer -= delta
		if _state_timer <= 0.0:
			_state = State.PATROL
			_reset_early_turn_timer()
		return

	var previous_direction := direction
	direction = 1 if to_last > 0 else -1
	if direction != previous_direction:
		_update_ledge_check_side()
		_update_facing_visuals()
	velocity.x = direction * speed * _speed_variance
	_try_climb(_last_known_target_pos.y)

func _try_climb(target_y: float) -> void:
	if can_climb and is_on_floor() and is_on_wall() and target_y < global_position.y - 16.0:
		velocity.y = jump_velocity

func _maybe_random_hop(delta: float) -> void:
	_hop_timer -= delta
	if _hop_timer <= 0.0:
		_hop_timer = randf_range(level2_hop_interval_min, level2_hop_interval_max)
		var body_height: float = (collision_shape.shape as RectangleShape2D).size.y
		var hop_height: float = body_height * level2_hop_height_ratio
		velocity.y = -sqrt(2.0 * gravity * hop_height)

func _reset_early_turn_timer() -> void:
	_early_turn_timer = randf_range(early_turn_interval_min, early_turn_interval_max)

func take_damage(damage: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	var dir := global_position - attacker_pos
	_on_hit_received(damage, dir)

func _on_hit_received(damage: int, dir: Vector2) -> void:
	health -= damage
	velocity.x = signf(dir.x) * 160.0
	velocity.y = -120.0
	if SoundManager:
		SoundManager.play_hit()
	FloatingText.spawn(get_parent(), global_position, "-%d" % damage, Color(1, 0.9, 0.3))
	_flash()
	if health <= 0:
		_die()

func _flash() -> void:
	var pivot := get_node_or_null("VisualPivot") as Node2D
	if is_instance_valid(sprite):
		sprite.modulate = Color(2.0, 2.0, 2.0)
	elif is_instance_valid(body_rect):
		body_rect.color = Color(1, 1, 1)
	elif is_instance_valid(pivot):
		pivot.modulate = Color(2.0, 2.0, 2.0)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 1.0, 1.0)
	elif is_instance_valid(body_rect):
		body_rect.color = _base_color
	elif is_instance_valid(pivot):
		pivot.modulate = Color(1.0, 1.0, 1.0)

func _die() -> void:
	var drop_count: int = int(round(material_drop * _reward_multiplier))
	for i in drop_count:
		_spawn_pickup("material", 1, Vector2(randf_range(-12, 12), -8), _get_drop_material_name())
	if randf() < 0.15:
		_spawn_pickup("gold", 2, Vector2(randf_range(-12, 12), -8))
	queue_free()

func _spawn_pickup(kind: String, amount: int, offset: Vector2, material_name_override: String = "") -> void:
	var pos := global_position + offset
	call_deferred("_deferred_create_pickup", kind, amount, pos, material_name_override)

func _deferred_create_pickup(kind: String, amount: int, pos: Vector2, material_name_override: String) -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return
	var p := PICKUP_SCENE.instantiate() as Pickup
	parent_node.add_child(p)
	p.global_position = pos
	p.setup(kind, amount, material_name_override)

func _get_drop_material_name() -> String:
	if visual_skin == "flower":
		return "oil"
	if level == 3:
		return "veg_stock"
	if level == 4:
		return "seafood_stock"
	if level >= 5:
		return "bone_stock"
	return "water"

func _on_touch_body(body: Node2D) -> void:
	if body is PlayerDADA:
		_try_touch(body as PlayerDADA)

func _try_touch(body: PlayerDADA) -> void:
	if not _can_touch:
		return
	_can_touch = false
	body.take_damage(touch_damage, body.global_position - global_position)
	await get_tree().create_timer(0.8).timeout
	_can_touch = true
	if is_instance_valid(body) and body in touch_area.get_overlapping_bodies():
		_try_touch(body)

func _on_detection_zone_body_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		target = body
		_state = State.CHASE
		if is_flower_monster:
			_mouth_open_target = 1.0

func _on_detection_zone_body_exited(body: Node2D) -> void:
	if body == target:
		_last_known_target_pos = body.global_position
		target = null
		_state = State.SEARCH
		_state_timer = search_duration
		if is_flower_monster:
			_mouth_open_target = 0.0

func _flip_direction() -> void:
	direction *= -1
	_update_ledge_check_side()
	_update_facing_visuals()

func _update_facing_visuals() -> void:
	var eye_l := get_node_or_null("VisualPivot/BodyRect/EyeLeft") as ColorRect
	var eye_r := get_node_or_null("VisualPivot/BodyRect/EyeRight") as ColorRect
	var shine := get_node_or_null("VisualPivot/BodyRect/ShineBlock") as ColorRect
	var blush_l := get_node_or_null("VisualPivot/BodyRect/BlushLeft") as ColorRect
	var blush_r := get_node_or_null("VisualPivot/BodyRect/BlushRight") as ColorRect

	if direction > 0:
		# 👉 오른쪽 (Right) 이동: 눈 및 볼터치를 오른쪽 방향으로 배치
		if eye_l: eye_l.position.x = 15.0
		if eye_r: eye_r.position.x = 23.0
		if shine: shine.position.x = 4.0
		if blush_l: blush_l.position.x = 11.0
		if blush_r: blush_r.position.x = 25.0
	else:
		# 👈 왼쪽 (Left) 이동: 눈 및 볼터치를 왼쪽 방향으로 배치
		if eye_l: eye_l.position.x = 6.0
		if eye_r: eye_r.position.x = 14.0
		if shine: shine.position.x = 20.0
		if blush_l: blush_l.position.x = 4.0
		if blush_r: blush_r.position.x = 17.0

func _update_ledge_check_side() -> void:
	ledge_check.position.x = abs(ledge_check.position.x) * direction
