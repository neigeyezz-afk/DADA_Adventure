extends CharacterBody2D
class_name EnemyMole

const FloatingText = preload("res://scripts/floating_text.gd")

@export var max_health: int = 8
@export var touch_damage: int = 2
@export var mole_type: String = "potato_mole" # potato_mole, konjac_mole

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

enum State { BURROWED, EMERGING, SURFACE, BURROWING }

var health: int = 0
var _can_touch: bool = true
var _state: State = State.BURROWED
var _timer: float = 0.0

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var touch_area: Area2D = $TouchDamage
@onready var body_rect: ColorRect = $ColorRect

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")

func _ready() -> void:
	if mole_type == "konjac_mole":
		max_health = 10
		touch_damage = 3
		body_rect.color = Color(0.4, 0.45, 0.5) # Konjac grey
	else:
		max_health = 8
		touch_damage = 2
		body_rect.color = Color(0.65, 0.45, 0.25) # Potato brown
	
	health = max_health
	hurtbox.hit_received.connect(_on_hit_received)
	touch_area.body_entered.connect(_on_touch_body)
	_timer = randf_range(1.0, 2.5)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0

	_timer -= delta
	match _state:
		State.BURROWED:
			body_rect.visible = false
			hurtbox.monitoring = false
			hurtbox.monitorable = false
			if _timer <= 0.0:
				_state = State.EMERGING
				_timer = 0.4
		State.EMERGING:
			body_rect.visible = true
			body_rect.scale.y = 0.3
			if _timer <= 0.0:
				_state = State.SURFACE
				_timer = 2.0
				hurtbox.monitoring = true
				hurtbox.monitorable = true
				body_rect.scale.y = 1.0
		State.SURFACE:
			body_rect.visible = true
			body_rect.scale.y = 1.0
			hurtbox.monitoring = true
			hurtbox.monitorable = true
			if _timer <= 0.0:
				_state = State.BURROWING
				_timer = 0.4
		State.BURROWING:
			body_rect.scale.y = 0.3
			if _timer <= 0.0:
				_state = State.BURROWED
				_timer = randf_range(1.5, 3.5)

	move_and_slide()

func _on_hit_received(damage: int, _dir: Vector2) -> void:
	if _state != State.SURFACE:
		return
	health -= damage
	if SoundManager:
		SoundManager.play_hit()
	FloatingText.spawn(get_parent(), global_position, "-%d" % damage, Color(1, 0.9, 0.3))
	_flash()
	if health <= 0:
		_die()

func _flash() -> void:
	body_rect.color = Color(1, 1, 1)
	await get_tree().create_timer(0.08).timeout
	if mole_type == "konjac_mole":
		body_rect.color = Color(0.4, 0.45, 0.5)
	else:
		body_rect.color = Color(0.65, 0.45, 0.25)

func _die() -> void:
	var drop_mat: String = "noodle" if mole_type == "konjac_mole" else "water"
	_spawn_pickup("material", 2, Vector2(randf_range(-12, 12), -10), drop_mat)
	_spawn_pickup("gold", 5, Vector2(randf_range(-10, 10), -10))
	queue_free()

func _spawn_pickup(kind: String, amount: int, offset: Vector2, material_name_override: String = "") -> void:
	var p := PICKUP_SCENE.instantiate() as Pickup
	get_parent().add_child(p)
	p.global_position = global_position + offset
	p.setup(kind, amount, material_name_override)

func _on_touch_body(body: Node2D) -> void:
	if body is PlayerDADA and _state == State.SURFACE:
		_try_touch(body as PlayerDADA)

func _try_touch(body: PlayerDADA) -> void:
	if not _can_touch or _state != State.SURFACE:
		return
	_can_touch = false
	body.take_damage(touch_damage, body.global_position - global_position)
	await get_tree().create_timer(0.8).timeout
	_can_touch = true
