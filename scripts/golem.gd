extends CharacterBody2D
class_name EnemyGolem

const FloatingText = preload("res://scripts/floating_text.gd")

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
@onready var body_rect: ColorRect = $ColorRect

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")

func _ready() -> void:
	health = max_health
	_apply_golem_style()
	detection_zone.body_entered.connect(_on_detection_zone_body_entered)
	detection_zone.body_exited.connect(_on_detection_zone_body_exited)
	hurtbox.hit_received.connect(_on_hit_received)
	touch_area.body_entered.connect(_on_touch_body)

func _apply_golem_style() -> void:
	match golem_type:
		"rice_golem":
			max_health = 9
			body_rect.color = Color(0.9, 0.9, 0.85) # Rice white/beige
		"buckwheat_golem":
			max_health = 9
			body_rect.color = Color(0.5, 0.4, 0.3) # Dark buckwheat
		_:
			body_rect.color = Color(0.85, 0.7, 0.45) # Wheat tan/orange

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
	body_rect.color = Color(1, 1, 1)
	await get_tree().create_timer(0.08).timeout
	_apply_golem_style()

func _die() -> void:
	var drop_name: String = "noodle"
	match golem_type:
		"rice_golem":
			drop_name = "noodle"
		"buckwheat_golem":
			drop_name = "noodle"
		_:
			drop_name = "noodle"

	for i in material_drop:
		_spawn_pickup("material", 1, Vector2(randf_range(-16, 16), -10), drop_name)
	_spawn_pickup("gold", 3, Vector2(randf_range(-12, 12), -10))
	queue_free()

func _spawn_pickup(kind: String, amount: int, offset: Vector2, material_name_override: String = "") -> void:
	var p := PICKUP_SCENE.instantiate() as Pickup
	get_parent().add_child(p)
	p.global_position = global_position + offset
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
