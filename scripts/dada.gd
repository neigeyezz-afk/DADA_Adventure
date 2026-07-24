extends CharacterBody2D
class_name PlayerDADA

# ==========================================================
# 1. 이동 및 물리 상수 (디자이너가 밸런스를 잡기 쉽도록 export)
# ==========================================================
@export var speed: float = 250.0
@export var jump_velocity: float = -450.0
@export var acceleration: float = 1200.0
@export var friction: float = 1500.0
@export var max_health: int = 6

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# ==========================================================
# 2. 상태 변수
# ==========================================================
var is_blocking: bool = false      # 방패 방어 상태 (기획서 3.2: 정지 시 자동)
var is_facing_right: bool = true
var health: int = 0
var is_attacking: bool = false
var invincible: bool = false
var spawn_point: Vector2 = Vector2.ZERO
var _already_hit: Array = []        # 한 번의 스윙에서 같은 대상 중복 타격 방지
var _walk_cycle: float = 0.0
var _is_filled_pot: bool = false
var _sprite_mode_key: String = ""
var _sprite_scale_multiplier: float = 1.0
var _attack_anim_time: float = 0.0
var _landing_bump: float = 0.0
var _visual_root: Node2D
var _body_visual: ColorRect
var _head_visual: ColorRect
var _left_leg: ColorRect
var _right_leg: ColorRect
var _left_arm: ColorRect
var _right_arm: ColorRect

signal health_changed(current: int, maximum: int)
signal died()

# ==========================================================
# 3. 노드 참조
# ==========================================================
@onready var body_rect: ColorRect = get_node_or_null("ColorRect")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var sword: Area2D = $Sword
@onready var sword_shape: CollisionShape2D = $Sword/CollisionShape2D
@onready var sword_visual: ColorRect = $Sword/ColorRect
@onready var camera: Camera2D = $Camera2D

const ATTACK_DURATION: float = 0.18
const INVINCIBLE_DURATION: float = 0.6
const BASE_SPRITE_SCALE: Vector2 = Vector2(0.075, 0.075)
const BODY_CENTER := Vector2(16, 32)   # 로컬 기준 몸 중심 (32x64 박스)
const BODY_HALF_WIDTH: float = 16.0
const WALK_HFRAMES: int = 4
const WALK_VFRAMES: int = 2
const WALK_FRAME_COUNT: int = 8

# 본 스테이지 카메라 한계값 (방에서 나올 때 복원용)
const MAIN_LIMIT_LEFT: int = 0
const MAIN_LIMIT_TOP: int = -400
const MAIN_LIMIT_RIGHT: int = 6400
const MAIN_LIMIT_BOTTOM: int = 120

var _pre_room_position: Vector2 = Vector2.ZERO
var _in_room: bool = false
var _room_paused_timer: bool = false

func _ready() -> void:
	add_to_group("player")
	health = max_health
	spawn_point = global_position
	sword.monitoring = false
	sword.area_entered.connect(_on_sword_area_entered)
	GameState.weapon_changed.connect(func(_i: int) -> void: _apply_weapon())
	_create_visuals()
	_apply_weapon()
	_setup_sprite_texture()
	if is_instance_valid(sprite):
		sprite.scale = BASE_SPRITE_SCALE
	health_changed.emit(health, max_health)

func _create_visuals() -> void:
	if is_instance_valid(sprite):
		sprite.visible = true
		sprite.position = Vector2(16, 32)
		sprite.rotation_degrees = 0.0
		return
	_visual_root = Node2D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)

	_body_visual = ColorRect.new()
	_body_visual.size = Vector2(24, 44)
	_body_visual.position = Vector2(4, 10)
	_body_visual.color = Color(0.6, 0.7, 1.0)
	_visual_root.add_child(_body_visual)

	_head_visual = ColorRect.new()
	_head_visual.size = Vector2(14, 14)
	_head_visual.position = Vector2(9, 4)
	_head_visual.color = Color(0.95, 0.8, 0.6)
	_visual_root.add_child(_head_visual)

	_left_leg = ColorRect.new()
	_left_leg.size = Vector2(6, 18)
	_left_leg.position = Vector2(8, 50)
	_left_leg.color = Color(0.4, 0.5, 0.8)
	_visual_root.add_child(_left_leg)

	_right_leg = ColorRect.new()
	_right_leg.size = Vector2(6, 18)
	_right_leg.position = Vector2(16, 50)
	_right_leg.color = Color(0.4, 0.5, 0.8)
	_visual_root.add_child(_right_leg)

	_left_arm = ColorRect.new()
	_left_arm.size = Vector2(6, 18)
	_left_arm.position = Vector2(4, 24)
	_left_arm.color = Color(0.95, 0.85, 0.45)
	_visual_root.add_child(_left_arm)

	_right_arm = ColorRect.new()
	_right_arm.size = Vector2(6, 18)
	_right_arm.position = Vector2(20, 24)
	_right_arm.color = Color(0.95, 0.85, 0.45)
	_visual_root.add_child(_right_arm)

func _get_texture_from_paths(candidate_paths: Array[String]) -> Texture2D:
	for path in candidate_paths:
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

# 정지 시 사용하는 단일 포즈 텍스처 (기존 player.png 계열)
func _get_idle_texture(is_filled: bool = false) -> Texture2D:
	var candidate_paths: Array[String] = []
	if is_filled:
		candidate_paths = ["res://assets/sprites/player_filled.png", "res://assets/sprites/player.png", "res://assets/sprites/player_character_sheet.png"]
	else:
		candidate_paths = ["res://assets/sprites/player.png", "res://assets/sprites/player_empty.png", "res://assets/sprites/player_character_sheet_empty.png"]
	return _get_texture_from_paths(candidate_paths)

# 이동 중 사용하는 8프레임 걷기 스프라이트시트 (팔다리 스윙 모션)
func _get_walk_texture(is_filled: bool = false) -> Texture2D:
	var path := "res://assets/sprites/player_walk_spritesheet.png" if is_filled else "res://assets/sprites/player_walk_spritesheet_empty.png"
	return _get_texture_from_paths([path])

func _setup_sprite_texture() -> void:
	if is_instance_valid(sprite):
		_apply_sprite_mode(false)
		sprite.visible = sprite.texture != null
		if is_instance_valid(body_rect):
			body_rect.visible = sprite.texture == null

# 정지<->이동 텍스처 전환 및 걷기 프레임 갱신 (텍스처는 모드가 바뀔 때만 재할당)
# 걷기 시트는 프레임 단위로 잘려 idle 텍스처보다 원본 픽셀 크기가 작으므로,
# 두 텍스처의 실제 높이를 비교해 화면상 캐릭터 크기가 변하지 않도록 배율을 보정한다.
func _apply_sprite_mode(is_walking_anim: bool) -> void:
	var wanted_key := ("walk_" if is_walking_anim else "idle_") + ("filled" if _is_filled_pot else "empty")
	if wanted_key == _sprite_mode_key:
		if is_walking_anim:
			sprite.frame = int(fmod(_walk_cycle, TAU) / TAU * WALK_FRAME_COUNT) % WALK_FRAME_COUNT
		return
	if is_walking_anim:
		var walk_tex := _get_walk_texture(_is_filled_pot)
		if walk_tex:
			sprite.texture = walk_tex
			sprite.hframes = WALK_HFRAMES
			sprite.vframes = WALK_VFRAMES
			sprite.frame = int(fmod(_walk_cycle, TAU) / TAU * WALK_FRAME_COUNT) % WALK_FRAME_COUNT
			var idle_tex := _get_idle_texture(_is_filled_pot)
			var walk_frame_height := float(walk_tex.get_height()) / float(WALK_VFRAMES)
			_sprite_scale_multiplier = float(idle_tex.get_height()) / walk_frame_height if idle_tex and walk_frame_height > 0.0 else 1.0
			_sprite_mode_key = wanted_key
	else:
		var idle_tex := _get_idle_texture(_is_filled_pot)
		if idle_tex:
			sprite.texture = idle_tex
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.frame = 0
			_sprite_scale_multiplier = 1.0
			_sprite_mode_key = wanted_key

# ==========================================================
# 4. 메인 물리 루프
# ==========================================================
func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	# 중력
	if not is_on_floor():
		velocity.y += gravity * delta
		is_blocking = false

	# 점프
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 공격
	if Input.is_action_just_pressed("attack"):
		_attack()

	# 좌우 이동
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		if direction > 0 and not is_facing_right:
			flip_character()
		elif direction < 0 and is_facing_right:
			flip_character()
		is_blocking = false
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		# 기획서 3.2: 바닥에서 정지 중이면 자동으로 방패를 든다
		if is_on_floor() and not is_attacking:
			is_blocking = true

	move_and_slide()
	if not was_on_floor and is_on_floor() and velocity.y >= 0.0:
		_landing_bump = 1.0
	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	var moving_state: bool = abs(velocity.x) > 10.0
	var bob_offset: float = 0.0
	var is_walking_anim: bool = moving_state and is_on_floor()
	if is_walking_anim:
		_walk_cycle += delta * 10.0
	else:
		_walk_cycle = 0.0
	if _landing_bump > 0.0:
		_landing_bump = max(0.0, _landing_bump - delta * 8.0)
	if _attack_anim_time > 0.0:
		_attack_anim_time = max(0.0, _attack_anim_time - delta)
	if is_instance_valid(sprite):
		_apply_sprite_mode(is_walking_anim)
		bob_offset = sin(_walk_cycle) * (4.0 if moving_state else 0.0)
		sprite.position = Vector2(16.0, 32.0 + bob_offset)
		sprite.flip_h = not is_facing_right
		var attack_tilt := 0.0
		var sprite_scale_x: float = 0.0
		var sprite_scale_y: float = 0.0
		if _attack_anim_time > 0.0:
			var attack_progress := 1.0 - (_attack_anim_time / ATTACK_DURATION)
			attack_tilt = -34.0 * (1.0 - attack_progress * 0.3) if is_facing_right else 34.0 * (1.0 - attack_progress * 0.3)
			sprite_scale_x = -0.08 + attack_progress * 0.02
			sprite_scale_y = 0.12 - attack_progress * 0.03
		elif is_blocking:
			attack_tilt = 6.0 if is_facing_right else -6.0
		elif _landing_bump > 0.0:
			sprite_scale_x = 0.05
			sprite_scale_y = -0.08
		elif not is_on_floor() and velocity.y < 0.0:
			sprite_scale_x = -0.02
			sprite_scale_y = 0.05
		sprite.rotation_degrees = attack_tilt
		sprite.scale = BASE_SPRITE_SCALE * _sprite_scale_multiplier * Vector2(1.0 + sprite_scale_x, 1.0 + sprite_scale_y)
		return
	if not is_instance_valid(_visual_root):
		return
	_visual_root.scale.x = -1.0 if not is_facing_right else 1.0
	bob_offset = sin(_walk_cycle) * (4.0 if moving_state else 0.0)
	_visual_root.position.y = bob_offset
	var leg_swing := sin(_walk_cycle) * (18.0 if moving_state else 0.0)
	_left_leg.rotation_degrees = leg_swing
	_right_leg.rotation_degrees = -leg_swing
	var arm_angle := 0.0
	var root_scale_x: float = 0.0
	var root_scale_y: float = 0.0
	if _attack_anim_time > 0.0:
		var attack_progress := 1.0 - (_attack_anim_time / ATTACK_DURATION)
		arm_angle = -95.0 * (1.0 - attack_progress * 0.3) if is_facing_right else 95.0 * (1.0 - attack_progress * 0.3)
		root_scale_x = -0.08 + attack_progress * 0.02
		root_scale_y = 0.12 - attack_progress * 0.03
	elif is_blocking:
		arm_angle = 25.0 if is_facing_right else -25.0
	elif moving_state:
		arm_angle = 12.0 if is_facing_right else -12.0
	elif _landing_bump > 0.0:
		root_scale_x = 0.05
		root_scale_y = -0.08
	elif not is_on_floor() and velocity.y < 0.0:
		root_scale_x = -0.02
		root_scale_y = 0.05
	_left_arm.rotation_degrees = arm_angle * 0.6
	_right_arm.rotation_degrees = -arm_angle
	_visual_root.scale = Vector2((-1.0 if not is_facing_right else 1.0) * (1.0 + root_scale_x), 1.0 + root_scale_y)

# ==========================================================
# 5. 전투 - 공격 (기획서 3.1 허공 찌르기 / 3.2 리치 스펙업)
# ==========================================================
func _attack() -> void:
	if is_attacking:
		return
	is_attacking = true
	is_blocking = false
	_attack_anim_time = ATTACK_DURATION
	_already_hit.clear()
	_position_sword()
	sword.monitoring = true

	# 물리 프레임을 한 번 넘겨 겹침 상태를 반영한 뒤, 이미 겹쳐 있던 대상도 즉시 타격
	await get_tree().physics_frame
	if is_inside_tree():
		for a in sword.get_overlapping_areas():
			_try_hit_area(a)

	await get_tree().create_timer(ATTACK_DURATION).timeout
	if is_inside_tree():
		sword.monitoring = false
	is_attacking = false

func _on_sword_area_entered(area: Area2D) -> void:
	_try_hit_area(area)

func _try_hit_area(area: Area2D) -> void:
	if area in _already_hit:
		return
	if area is Hurtbox:
		_already_hit.append(area)
		var wpn := GameState.get_weapon()
		var dir := Vector2(1.0 if is_facing_right else -1.0, 0.0)
		(area as Hurtbox).receive_hit(int(wpn["damage"]), dir)

# 무기 리치에 맞춰 검 히트박스 크기/위치를 갱신 (바라보는 방향으로 배치)
func _position_sword() -> void:
	var wpn := GameState.get_weapon()
	var reach: float = wpn["reach"]
	var shape := sword_shape.shape as RectangleShape2D
	shape.size = Vector2(reach, 44.0)
	var side := 1.0 if is_facing_right else -1.0
	sword_shape.position = Vector2(
		BODY_CENTER.x + side * (BODY_HALF_WIDTH + reach / 2.0),
		BODY_CENTER.y - 6.0
	)
	# 공격 효과(검 궤적) 시각화도 히트박스와 동일하게 맞춘다
	sword_visual.size = shape.size
	sword_visual.position = sword_shape.position - shape.size / 2.0

# 장비 변경 시: 리치 갱신 + 화이트박스 색으로 외형 스펙업 표시 (기획서 3.2)
func _apply_weapon() -> void:
	var wpn := GameState.get_weapon()
	if is_instance_valid(body_rect) and (not is_instance_valid(sprite) or sprite.texture == null):
		body_rect.color = wpn["color"]
	_position_sword()

# ==========================================================
# 6. 피격 처리
# ==========================================================
func take_damage(amount: int, attack_direction: Vector2) -> void:
	if invincible:
		return
	# 정면에서 오는 공격은 방패로 막는다 (기획서 3.2)
	if is_blocking and _is_frontal(attack_direction):
		return

	health = max(0, health - amount)
	health_changed.emit(health, max_health)

	# 넉백
	velocity.x = signf(attack_direction.x) * 220.0
	velocity.y = -180.0

	if health <= 0:
		_die()
		return

	_flash_hurt()
	invincible = true
	await get_tree().create_timer(INVINCIBLE_DURATION).timeout
	invincible = false

func _is_frontal(dir: Vector2) -> bool:
	# dir = (플레이어 - 공격원). 바라보는 쪽에서 온 공격이면 정면.
	if is_facing_right:
		return dir.x < 0.0
	return dir.x > 0.0

func _flash_hurt() -> void:
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 0.3, 0.3)
	elif is_instance_valid(body_rect):
		body_rect.color = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 1.0, 1.0)
	elif is_instance_valid(body_rect):
		body_rect.color = Color(0.55, 0.6, 0.7, 1)

func set_filled_pot(is_filled: bool = true) -> void:
	_is_filled_pot = is_filled
	_sprite_mode_key = ""  # 다음 _update_visuals에서 텍스처를 강제로 다시 불러오게 함
	if is_instance_valid(sprite):
		_apply_sprite_mode(false)

func _die() -> void:
	died.emit()
	# Phase 1: 즉시 리스폰 (세이브/사망 페널티는 Phase 3에서 확장)
	health = max_health
	health_changed.emit(health, max_health)
	global_position = spawn_point
	velocity = Vector2.ZERO
	invincible = false

# 무적 상태와 무관하게 즉시 사망 처리 후 리스폰 (구덩이 추락 / 가시 등 지형 즉사 판정 공용)
func _force_death() -> void:
	health = 0
	health_changed.emit(health, max_health)
	_die()

func fall_into_pit() -> void:
	_force_death()

func die_by_spikes() -> void:
	_force_death()

# ==========================================================
# 8. 방(상점/비밀상점 내부 공간) 이동
# ==========================================================
func enter_room(entry_position: Vector2, limit_left: float, limit_top: float, limit_right: float, limit_bottom: float, pause_stage_timer: bool = false) -> void:
	if not _in_room:
		_pre_room_position = global_position
	_in_room = true
	global_position = entry_position
	velocity = Vector2.ZERO
	camera.limit_left = int(limit_left)
	camera.limit_top = int(limit_top)
	camera.limit_right = int(limit_right)
	camera.limit_bottom = int(limit_bottom)
	_room_paused_timer = pause_stage_timer
	if pause_stage_timer:
		var timer := get_tree().get_first_node_in_group("stage_timer") as StageTimer
		if timer:
			timer.pause_timer()

func exit_room() -> void:
	if not _in_room:
		return
	_in_room = false
	global_position = _pre_room_position
	velocity = Vector2.ZERO
	camera.limit_left = MAIN_LIMIT_LEFT
	camera.limit_top = MAIN_LIMIT_TOP
	camera.limit_right = MAIN_LIMIT_RIGHT
	camera.limit_bottom = MAIN_LIMIT_BOTTOM
	if _room_paused_timer:
		var timer := get_tree().get_first_node_in_group("stage_timer") as StageTimer
		if timer:
			timer.resume_timer()
	_room_paused_timer = false

# ==========================================================
# 9. 헬퍼
# ==========================================================
func flip_character() -> void:
	is_facing_right = not is_facing_right
	if is_instance_valid(sprite):
		sprite.flip_h = not is_facing_right
	# 검이 항상 바라보는 방향에 오도록 갱신
	if sword_shape:
		_position_sword()
