extends CharacterBody2D
class_name KingSlime

## ==========================================================
## KingSlime: Stage 3 보스형 대형 슬라임
## ==========================================================

@export var max_health: int = 20
@export var speed: float = 20.0
@export var chase_speed: float = 130.0
@export var touch_damage: int = 5

var health: int = 20
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var target: PlayerDADA = null
var _can_touch: bool = true
var _base_color: Color = Color(0.15, 0.48, 0.92)
var _jump_cooldown: float = 2.5
var _motion_phase: int = 0
var _motion_timer: float = 0.0
const MOTION_FRAME_TIME: float = 0.16

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var touch_area: Area2D = $TouchArea
@onready var detection_zone: Area2D = $DetectionZone

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	hurtbox.hit_received.connect(_on_hit_received)
	touch_area.body_entered.connect(_on_touch_body)
	detection_zone.body_entered.connect(_on_detection_entered)
	detection_zone.body_exited.connect(_on_detection_exited)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if target and is_instance_valid(target):
		var dir_x := signf(target.global_position.x - global_position.x)
		velocity.x = dir_x * chase_speed
	else:
		velocity.x = 0.0

	_motion_timer += delta
	if _motion_timer >= MOTION_FRAME_TIME:
		_motion_timer = 0.0
		_motion_phase = (_motion_phase + 1) % 4
		_apply_squish(_motion_phase)

	move_and_slide()

func _apply_squish(phase: int) -> void:
	var pivot := get_node_or_null("VisualPivot") as Node2D
	if not pivot:
		return
	match phase:
		0:
			pivot.scale = Vector2(1.0, 1.0)
		1:
			pivot.scale = Vector2(1.15, 0.85)
		2:
			pivot.scale = Vector2(1.0, 1.0)
		3:
			pivot.scale = Vector2(0.88, 1.12)

func take_damage(damage: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	var dir := global_position - attacker_pos
	_on_hit_received(damage, dir)

func _on_hit_received(damage: int, _dir: Vector2) -> void:
	health -= damage
	if SoundManager:
		SoundManager.play_hit()
	FloatingText.spawn(get_parent(), global_position, "-%d BOSS" % damage, Color(1, 0.4, 0.2))
	_flash()
	if health <= 0:
		_die()

func _flash() -> void:
	var body_node := get_node_or_null("VisualPivot/BodyRect") as ColorRect
	if body_node:
		body_node.color = Color(1, 1, 1)
		await get_tree().create_timer(0.1).timeout
		body_node.color = _base_color

func _die() -> void:
	if SoundManager:
		SoundManager.play_chest_open()
	FloatingText.spawn(get_parent(), global_position, "BOSS DEFEATED!", Color(1.0, 0.85, 0.1))
	
	# 대량 골드 드롭 (80 골드)
	for i in range(8):
		_spawn_pickup("gold", 10, Vector2(randf_range(-30, 30), -20))

	# Stage 1 랜덤 드롭 재료 10개 드롭
	var stage1_mats := ["water", "oil", "veg_stock", "seafood_stock", "bone_stock", "noodle_dough", "firewood", "potato_dough", "konjac_dough"]
	for i in range(10):
		var rand_mat: String = stage1_mats[randi() % stage1_mats.size()]
		_spawn_pickup("material", 1, Vector2(randf_range(-35, 35), -25), rand_mat)

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
	if body is PlayerDADA and _can_touch:
		_can_touch = false
		(body as PlayerDADA).take_damage(touch_damage, body.global_position - global_position)
		await get_tree().create_timer(0.8).timeout
		_can_touch = true

func _on_detection_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		target = body

func _on_detection_exited(body: Node2D) -> void:
	if body == target:
		target = null
