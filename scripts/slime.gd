extends CharacterBody2D
class_name EnemySlime

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

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

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
@onready var body_rect: ColorRect = get_node_or_null("ColorRect")
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
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var global_p := ProjectSettings.globalize_path(path)
		if global_p != "":
			var img := Image.load_from_file(global_p)
			if img and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null

func _apply_level() -> void:
	var mult: float = LEVEL_MULTIPLIER.get(level, 1.0)
	max_health = int(round(max_health * mult))
	touch_damage = int(round(touch_damage * mult))
	if level == 2:
		_base_color = LEVEL2_COLOR
	elif level >= 3:
		_base_color = LEVEL3_COLOR
		_reward_multiplier = LEVEL3_REWARD_MULTIPLIER
	
	if is_instance_valid(sprite):
		var tex := _get_slime_texture(level)
		if tex:
			sprite.texture = tex
			sprite.visible = true
			if is_instance_valid(body_rect):
				body_rect.visible = false
		elif is_instance_valid(body_rect):
			body_rect.visible = true
			body_rect.color = _base_color
	elif is_instance_valid(body_rect):
		body_rect.color = _base_color

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif level == 2:
		_maybe_random_hop(delta)

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
	var previous_direction := direction
	direction = 1 if target.global_position.x > global_position.x else -1
	if direction != previous_direction:
		_update_ledge_check_side()
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

func _on_hit_received(damage: int, dir: Vector2) -> void:
	health -= damage
	velocity.x = signf(dir.x) * 160.0
	velocity.y = -120.0
	_flash()
	if health <= 0:
		_die()

func _flash() -> void:
	if is_instance_valid(sprite):
		sprite.modulate = Color(2.0, 2.0, 2.0)
	elif is_instance_valid(body_rect):
		body_rect.color = Color(1, 1, 1)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 1.0, 1.0)
	elif is_instance_valid(body_rect):
		body_rect.color = _base_color

func _die() -> void:
	var drop_count: int = int(round(material_drop * _reward_multiplier))
	for i in drop_count:
		_spawn_pickup("material", 1, Vector2(randf_range(-12, 12), -8), _get_drop_material_name())
	if randf() < 0.15:
		_spawn_pickup("gold", 2, Vector2(randf_range(-12, 12), -8))
	queue_free()

func _spawn_pickup(kind: String, amount: int, offset: Vector2, material_name_override: String = "") -> void:
	var p := PICKUP_SCENE.instantiate() as Pickup
	get_parent().add_child(p)
	p.global_position = global_position + offset
	p.setup(kind, amount, material_name_override)

func _get_drop_material_name() -> String:
	if level >= 5:
		return "meat_stock"
	if level >= 4:
		return "noodle"
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

func _on_detection_zone_body_exited(body: Node2D) -> void:
	if body == target:
		_last_known_target_pos = body.global_position
		target = null
		_state = State.SEARCH
		_state_timer = search_duration

func _flip_direction() -> void:
	direction *= -1
	_update_ledge_check_side()
	if is_instance_valid(sprite):
		sprite.flip_h = (direction > 0)

func _update_ledge_check_side() -> void:
	ledge_check.position.x = abs(ledge_check.position.x) * direction
