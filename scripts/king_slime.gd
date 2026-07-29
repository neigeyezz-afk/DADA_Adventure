extends CharacterBody2D
class_name KingSlime

const FloatingText = preload("res://scripts/floating_text.gd")
## ==========================================================
## KingSlime: Stage 3 보스형 대형 슬라임
## ==========================================================

@export var max_health: int = 40
@export var speed: float = 80.0
@export var chase_speed: float = 130.0
@export var touch_damage: int = 2

var health: int = 40
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var target: PlayerDADA = null
var _can_touch: bool = true
var _base_color: Color = Color(0.9, 0.2, 0.3)
var _jump_cooldown: float = 2.5

@onready var body_rect: ColorRect = $ColorRect
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
	body_rect.color = _base_color

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if target:
		var dir := 1 if target.global_position.x > global_position.x else -1
		velocity.x = dir * chase_speed
		
		# 보스 점프 강하 공격
		_jump_cooldown -= delta
		if _jump_cooldown <= 0.0 and is_on_floor():
			_jump_cooldown = randf_range(2.0, 3.5)
			velocity.y = -420.0
	else:
		velocity.x = 0.0

	move_and_slide()

func _on_hit_received(damage: int, dir: Vector2) -> void:
	health -= damage
	velocity.x = signf(dir.x) * 120.0
	velocity.y = -100.0
	if SoundManager:
		SoundManager.play_hit()
	FloatingText.spawn(get_parent(), global_position, "-%d BOSS" % damage, Color(1, 0.4, 0.2))
	_flash()
	if health <= 0:
		_die()

func _flash() -> void:
	body_rect.color = Color(1, 1, 1)
	await get_tree().create_timer(0.1).timeout
	body_rect.color = _base_color

func _die() -> void:
	if SoundManager:
		SoundManager.play_chest_open()
	FloatingText.spawn(get_parent(), global_position, "BOSS DEFEATED!", Color(1.0, 0.85, 0.1))
	
	# 대량 보상 드롭
	for i in range(8):
		var p := PICKUP_SCENE.instantiate() as Pickup
		get_parent().add_child(p)
		p.global_position = global_position + Vector2(randf_range(-30, 30), -20)
		p.setup("gold", 10)

	for i in range(5):
		var m := PICKUP_SCENE.instantiate() as Pickup
		get_parent().add_child(m)
		m.global_position = global_position + Vector2(randf_range(-30, 30), -25)
		m.setup("material", 2, "noodle" if i % 2 == 0 else "cheese")

	queue_free()

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
