extends CharacterBody2D
class_name EnemyMole


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
@onready var visual_root: Node2D = get_node_or_null("VisualRoot")

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")

func _ready() -> void:
	_build_pixel_mole()
	if mole_type == "konjac_mole":
		max_health = 2
		touch_damage = 3
	else:
		max_health = 2
		touch_damage = 2
	_apply_mole_tint()

	health = max_health
	hurtbox.hit_received.connect(_on_hit_received)
	touch_area.body_entered.connect(_on_touch_body)
	_timer = randf_range(1.0, 2.5)

# 안경 쓴 통통한 두더지 NPC 픽셀 아트 (몸통-귀-코-앞발-안경)
func _build_pixel_mole() -> void:
	if not is_instance_valid(visual_root):
		return
	for c in visual_root.get_children():
		c.queue_free()

	var outline_col := Color(0.10, 0.07, 0.05, 1.0)
	var fur_dark    := Color(0.42, 0.29, 0.16, 1.0)
	var fur_mid     := Color(0.58, 0.40, 0.22, 1.0)
	var fur_light   := Color(0.70, 0.52, 0.32, 1.0)
	var snout_col   := Color(0.95, 0.65, 0.65, 1.0)
	var claw_col    := Color(0.85, 0.78, 0.68, 1.0)
	var lens_col    := Color(0.75, 0.88, 0.95, 0.9)

	# 1. 몸통 외곽 + 통통한 본체
	var body_out := ColorRect.new()
	body_out.size = Vector2(34.0, 26.0)
	body_out.position = Vector2(-17.0, -13.0)
	body_out.color = outline_col
	visual_root.add_child(body_out)

	var body := ColorRect.new()
	body.size = Vector2(30.0, 22.0)
	body.position = Vector2(-15.0, -11.0)
	body.color = fur_mid
	visual_root.add_child(body)

	# 둥근 느낌을 주는 상단 코너 컷
	for corner_x in [-15.0, 9.0]:
		var corner := ColorRect.new()
		corner.size = Vector2(6.0, 3.0)
		corner.position = Vector2(corner_x, -13.0)
		corner.color = outline_col
		visual_root.add_child(corner)

	# 2. 배 하이라이트
	var belly := ColorRect.new()
	belly.size = Vector2(16.0, 12.0)
	belly.position = Vector2(-8.0, -2.0)
	belly.color = fur_light
	visual_root.add_child(belly)

	# 3. 귀
	for ear_x in [-13.0, 7.0]:
		var ear_out := ColorRect.new()
		ear_out.size = Vector2(8.0, 8.0)
		ear_out.position = Vector2(ear_x - 1.0, -19.0)
		ear_out.color = outline_col
		visual_root.add_child(ear_out)

		var ear := ColorRect.new()
		ear.size = Vector2(6.0, 6.0)
		ear.position = Vector2(ear_x, -18.0)
		ear.color = fur_dark
		visual_root.add_child(ear)

	# 4. 코 (분홍 주둥이)
	var snout_out := ColorRect.new()
	snout_out.size = Vector2(12.0, 9.0)
	snout_out.position = Vector2(9.0, -3.0)
	snout_out.color = outline_col
	visual_root.add_child(snout_out)

	var snout := ColorRect.new()
	snout.size = Vector2(10.0, 7.0)
	snout.position = Vector2(10.0, -2.0)
	snout.color = snout_col
	visual_root.add_child(snout)

	var nose_tip := ColorRect.new()
	nose_tip.size = Vector2(3.0, 3.0)
	nose_tip.position = Vector2(17.0, 0.0)
	nose_tip.color = outline_col
	visual_root.add_child(nose_tip)

	# 5. 수염
	for whisker_y in [-1.0, 2.0]:
		var whisker := ColorRect.new()
		whisker.size = Vector2(6.0, 1.0)
		whisker.position = Vector2(19.0, whisker_y)
		whisker.color = Color(0.9, 0.9, 0.85, 0.8)
		visual_root.add_child(whisker)

	# 6. 안경 (근시 두더지 시그니처 아이템)
	var glasses_band := ColorRect.new()
	glasses_band.size = Vector2(24.0, 4.0)
	glasses_band.position = Vector2(-11.0, -8.0)
	glasses_band.color = outline_col
	visual_root.add_child(glasses_band)

	for lens_x in [-9.0, 5.0]:
		var lens_out := ColorRect.new()
		lens_out.size = Vector2(9.0, 9.0)
		lens_out.position = Vector2(lens_x - 1.0, -9.0)
		lens_out.color = outline_col
		visual_root.add_child(lens_out)

		var lens := ColorRect.new()
		lens.size = Vector2(7.0, 7.0)
		lens.position = Vector2(lens_x, -8.0)
		lens.color = lens_col
		visual_root.add_child(lens)

		var pupil := ColorRect.new()
		pupil.size = Vector2(2.0, 2.0)
		pupil.position = Vector2(lens_x + 2.5, -5.5)
		pupil.color = outline_col
		visual_root.add_child(pupil)

	# 7. 땅파기 앞발 & 발톱
	for paw_x in [-11.0, -1.0]:
		var paw_out := ColorRect.new()
		paw_out.size = Vector2(10.0, 8.0)
		paw_out.position = Vector2(paw_x - 1.0, 8.0)
		paw_out.color = outline_col
		visual_root.add_child(paw_out)

		var paw := ColorRect.new()
		paw.size = Vector2(8.0, 6.0)
		paw.position = Vector2(paw_x, 9.0)
		paw.color = fur_dark
		visual_root.add_child(paw)

		for claw_offset in [0.0, 3.0, 6.0]:
			var claw := ColorRect.new()
			claw.size = Vector2(2.0, 3.0)
			claw.position = Vector2(paw_x + claw_offset, 14.0)
			claw.color = claw_col
			visual_root.add_child(claw)

func _apply_mole_tint() -> void:
	if not is_instance_valid(visual_root):
		return
	if mole_type == "konjac_mole":
		visual_root.modulate = Color(0.78, 0.85, 0.95) # Konjac grey
	else:
		visual_root.modulate = Color(1.0, 1.0, 1.0) # Potato brown (기본 색 그대로)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0

	_timer -= delta
	match _state:
		State.BURROWED:
			visual_root.visible = false
			hurtbox.monitoring = false
			hurtbox.monitorable = false
			if _timer <= 0.0:
				_state = State.EMERGING
				_timer = 0.4
		State.EMERGING:
			visual_root.visible = true
			visual_root.scale.y = 0.3
			if _timer <= 0.0:
				_state = State.SURFACE
				_timer = 2.0
				hurtbox.monitoring = true
				hurtbox.monitorable = true
				visual_root.scale.y = 1.0
		State.SURFACE:
			visual_root.visible = true
			visual_root.scale.y = 1.0
			hurtbox.monitoring = true
			hurtbox.monitorable = true
			if _timer <= 0.0:
				_state = State.BURROWING
				_timer = 0.4
		State.BURROWING:
			visual_root.scale.y = 0.3
			if _timer <= 0.0:
				_state = State.BURROWED
				_timer = randf_range(1.5, 3.5)

	move_and_slide()

func take_damage(damage: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	var dir := global_position - attacker_pos
	_on_hit_received(damage, dir)

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
	if is_instance_valid(visual_root):
		visual_root.modulate = Color(2.0, 2.0, 2.0)
	await get_tree().create_timer(0.08).timeout
	_apply_mole_tint()

func _die() -> void:
	var drop_mat: String = "konjac_dough" if mole_type == "konjac_mole" else "potato_dough"
	_spawn_pickup("material", 1, Vector2(randf_range(-12, 12), -10), drop_mat)
	_spawn_pickup("gold", 5, Vector2(randf_range(-10, 10), -10))
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
	if body is PlayerDADA and _state == State.SURFACE:
		_try_touch(body as PlayerDADA)

func _try_touch(body: PlayerDADA) -> void:
	if not _can_touch or _state != State.SURFACE:
		return
	_can_touch = false
	body.take_damage(touch_damage, body.global_position - global_position)
	await get_tree().create_timer(0.8).timeout
	_can_touch = true
