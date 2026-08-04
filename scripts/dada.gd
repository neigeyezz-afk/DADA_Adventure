extends CharacterBody2D
class_name PlayerDADA

const FloatingText = preload("res://scripts/floating_text.gd")

# ==========================================================
# 1. 이동 및 물리 상수
# ==========================================================
@export var speed: float = 250.0
@export var jump_velocity: float = -450.0
@export var acceleration: float = 1200.0
@export var friction: float = 1500.0
@export var max_health: int = 10

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# ==========================================================
# 2. 상태 변수
# ==========================================================
var is_blocking: bool = false
var is_facing_right: bool = true
var health: int = 0
var is_attacking: bool = false
var invincible: bool = false
var spawn_point: Vector2 = Vector2.ZERO
var _already_hit: Array = []
var _walk_cycle: float = 0.0
var _is_filled_pot: bool = false
var _attack_anim_time: float = 0.0
var _landing_bump: float = 0.0

var is_on_ladder: bool = false
var current_ladder: Area2D = null
var is_climbing: bool = false
var _ladder_cooldown: float = 0.0

signal health_changed(current: int, maximum: int)
signal died()

func set_on_ladder(on: bool, ladder_ref: Area2D = null) -> void:
	is_on_ladder = on
	if on:
		current_ladder = ladder_ref
	else:
		if current_ladder == ladder_ref or ladder_ref == null:
			current_ladder = null
			is_climbing = false

# ==========================================================
# 3. 노드 참조
# ==========================================================
@onready var body_rect: ColorRect = get_node_or_null("ColorRect")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var sword: Area2D = $Sword
@onready var sword_shape: CollisionShape2D = $Sword/CollisionShape2D
@onready var sword_visual: ColorRect = $Sword/ColorRect
@onready var camera: Camera2D = $Camera2D
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D")

const ATTACK_DURATION: float = 0.18
const INVINCIBLE_DURATION: float = 0.6

# 10% 증대된 표준 스케일 높이
const TARGET_CHARACTER_HEIGHT: float = 80.0

var character_fan_art: Texture2D = null

func _ready() -> void:
	add_to_group("player")
	scale = Vector2(1.1, 1.1) # 플레이어 전체 크기 10% 증대!
	_load_character_fan_art()
	health = max_health
	spawn_point = global_position
	sword.monitoring = false
	sword.area_entered.connect(_on_sword_area_entered)
	GameState.weapon_changed.connect(func(_i: int) -> void: _apply_weapon())
	
	_hide_dummy_blocks()
	_setup_character_sprites_and_animations()
	_apply_weapon()
	health_changed.emit(health, max_health)

func _remove_white_background(img: Image) -> Image:
	if not img or img.is_empty():
		return img
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var bg_color := img.get_pixel(0, 0)
	
	# 외곽 테두리에서 시작하는 BFS 플러드 필 배경 완전 소거
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)
	
	var queue: Array[Vector2i] = []
	
	# 상하좌우 4개 테두리 픽셀을 큐에 삽입
	for x in range(w):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in range(1, h - 1):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))
		
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		
		var px := p.x
		var py := p.y
		var idx := py * w + px
		
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		
		var c := img.get_pixel(px, py)
		var diff: float = abs(c.r - bg_color.r) + abs(c.g - bg_color.g) + abs(c.b - bg_color.b)
		
		var is_neutral_grey: bool = (abs(c.r - c.g) < 0.10 and abs(c.g - c.b) < 0.10 and c.r > 0.35)
		var is_light_bg: bool = (c.r > 0.65 and c.g > 0.60 and c.b > 0.55)
		var is_black_outline: bool = (c.r < 0.20 and c.g < 0.20 and c.b < 0.20)
		
		if (diff < 0.50 or (is_neutral_grey and is_light_bg)) and not is_black_outline:
			img.set_pixel(px, py, Color(0, 0, 0, 0))
			
			# 4방향 확장 탐색
			if px > 0 and visited[py * w + (px - 1)] == 0:
				queue.append(Vector2i(px - 1, py))
			if px < w - 1 and visited[py * w + (px + 1)] == 0:
				queue.append(Vector2i(px + 1, py))
			if py > 0 and visited[(py - 1) * w + px] == 0:
				queue.append(Vector2i(px, py - 1))
			if py < h - 1 and visited[(py + 1) * w + px] == 0:
				queue.append(Vector2i(px, py + 1))

	return img

func _robust_load_texture(path: String, remove_bg: bool = true) -> Texture2D:
	var loaded_tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			loaded_tex = res as Texture2D

	if not loaded_tex:
		var global_p := ProjectSettings.globalize_path(path)
		if global_p != "" and FileAccess.file_exists(path):
			var raw_img = Image.load_from_file(global_p)
			if raw_img and not raw_img.is_empty():
				loaded_tex = ImageTexture.create_from_image(raw_img)

	if loaded_tex and remove_bg:
		var img: Image = loaded_tex.get_image()
		if img and not img.is_empty():
			img = _remove_white_background(img)
			return ImageTexture.create_from_image(img)

	return loaded_tex

func _load_character_fan_art() -> void:
	var path := "res://assets/sprites/player_fan.png"
	# 배경 제거는 에셋에 이미 구워져 있어 런타임 플러드필이 필요 없음 (성능 최적화)
	character_fan_art = _robust_load_texture(path, false)

func get_character_fan_art() -> Texture2D:
	if not character_fan_art:
		_load_character_fan_art()
	return character_fan_art

func _hide_dummy_blocks() -> void:
	if is_instance_valid(body_rect):
		body_rect.visible = true
	if is_instance_valid(sprite):
		sprite.visible = false
	if is_instance_valid(anim_sprite):
		anim_sprite.visible = false
	if is_instance_valid(sword_visual):
		sword_visual.visible = false
	var visual_root = get_node_or_null("Visuals")
	if visual_root:
		visual_root.visible = false

func _create_atlas_frame(src_tex: Texture2D, rect: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = src_tex
	atlas.region = rect
	return atlas

func _setup_character_sprites_and_animations() -> void:
	var pot_knight_path := "res://assets/sprites/player Pot Knight.png"

	# 배경 제거는 에셋에 이미 구워져 있어 런타임 플러드필이 필요 없음 (성능 최적화)
	var pot_knight_tex: Texture2D = _robust_load_texture(pot_knight_path, false)
	var fan_art_tex: Texture2D = get_character_fan_art()

	if is_instance_valid(body_rect):
		body_rect.visible = true

	# 1. 단일 2D 캐릭터 스프라이트 (Sprite2D)
	if is_instance_valid(sprite):
		var use_tex := fan_art_tex if fan_art_tex else pot_knight_tex
		if use_tex:
			sprite.texture = use_tex
			sprite.visible = true
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.frame = 0
			var h := float(use_tex.get_height())
			if h > 0.0:
				var sc := TARGET_CHARACTER_HEIGHT / h
				sprite.scale = Vector2(sc, sc)
			sprite.position = Vector2(16.0, 32.0)
			sprite.z_index = 10
			if is_instance_valid(body_rect):
				body_rect.visible = false
		else:
			sprite.visible = false

	# 2. 4프레임 모션 애니메이션 (AnimatedSprite2D)
	if is_instance_valid(anim_sprite) and pot_knight_tex:
		var sf := SpriteFrames.new()
		var tw := float(pot_knight_tex.get_width())
		var th := float(pot_knight_tex.get_height())

		var crop_w := tw * 0.12
		var crop_h := th * 0.30
		var walk_y := th * 0.59

		var front_frame := _create_atlas_frame(pot_knight_tex, Rect2(tw * 0.02, th * 0.09, crop_w, crop_h))
		var walk_1 := _create_atlas_frame(pot_knight_tex, Rect2(tw * 0.125, walk_y, crop_w, crop_h))
		var walk_2 := _create_atlas_frame(pot_knight_tex, Rect2(tw * 0.325, walk_y, crop_w, crop_h))
		var walk_3 := _create_atlas_frame(pot_knight_tex, Rect2(tw * 0.525, walk_y, crop_w, crop_h))
		var walk_4 := _create_atlas_frame(pot_knight_tex, Rect2(tw * 0.725, walk_y, crop_w, crop_h))

		# 🏃 walk
		sf.add_animation("walk")
		sf.set_animation_speed("walk", 12.0)
		sf.set_animation_loop("walk", true)
		sf.add_frame("walk", walk_1)
		sf.add_frame("walk", walk_2)
		sf.add_frame("walk", walk_3)
		sf.add_frame("walk", walk_4)

		# 🦘 jump
		sf.add_animation("jump")
		sf.set_animation_speed("jump", 10.0)
		sf.set_animation_loop("jump", false)
		sf.add_frame("jump", walk_2)
		sf.add_frame("jump", walk_3)

		# ⚔️ attack
		sf.add_animation("attack")
		sf.set_animation_speed("attack", 14.0)
		sf.set_animation_loop("attack", false)
		sf.add_frame("attack", front_frame)
		sf.add_frame("attack", walk_1)

		anim_sprite.sprite_frames = sf
		anim_sprite.visible = false
		anim_sprite.position = Vector2(16.0, 32.0)
		anim_sprite.z_index = 10
		if crop_h > 0.0:
			var sc := TARGET_CHARACTER_HEIGHT / crop_h
			anim_sprite.scale = Vector2(sc, sc)

func _apply_weapon() -> void:
	var w: Dictionary = GameState.WEAPONS[GameState.weapon_index]
	var base_reach: float = float(w.get("reach", 30.0))
	var reach: float = base_reach + 35.0 # 공격 감도 및 피격 범위 35px 확장!
	var col: Color = w.get("color", Color(1, 0.85, 0.25))
	var c_shape := sword_shape.shape as RectangleShape2D
	if c_shape:
		c_shape.size = Vector2(reach, 68.0) # 상하 68px로 공격 판정 높이 대폭 확장
	var dir_factor: float = 1.0 if is_facing_right else -1.0
	sword_shape.position.x = 16.0 + (reach * 0.5 * dir_factor)
	if is_instance_valid(sword_visual):
		sword_visual.position = Vector2(sword_shape.position.x - (reach * 0.5 * dir_factor), 4.0)
		sword_visual.size = Vector2(reach, 44.0)
		sword_visual.color = col

# ==========================================================
# 4. 메인 물리 및 이동 애니메이션 루프
# ==========================================================
func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()

	# 사다리 조작 입력 감지 (Up: UpArrow / W / interact, Down: DownArrow / S)
	var up_pressed := Input.is_action_pressed("interact") or Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var down_pressed := Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)

	if _ladder_cooldown > 0.0:
		_ladder_cooldown = maxf(0.0, _ladder_cooldown - delta)

	if is_on_ladder and _ladder_cooldown <= 0.0:
		if up_pressed or down_pressed:
			is_climbing = true
	else:
		if is_climbing and _ladder_cooldown <= 0.0:
			is_climbing = false
			collision_mask = 1

	if is_climbing:
		is_blocking = false
		collision_mask = 0 # 등반 중에는 발판 천장 충돌을 해제하여 발판 바닥을 관통하고 상단으로 올라갈 수 있도록 처리

		if is_instance_valid(current_ladder):
			global_position.x = move_toward(global_position.x, current_ladder.global_position.x, 180.0 * delta)
			var top_y: float = current_ladder.global_position.y - float(current_ladder.get("height"))
			var is_broken: bool = bool(current_ladder.get("is_broken_top"))
			if is_broken:
				var broken_limit_y: float = top_y + 65.0
				if global_position.y <= broken_limit_y:
					global_position.y = broken_limit_y
					if up_pressed:
						up_pressed = false
			else:
				var can_snap: bool = bool(current_ladder.get("can_snap"))
				var has_snapped: bool = bool(current_ladder.get("has_snapped"))
				var snap_trigger_y: float = current_ladder.global_position.y - float(current_ladder.get("height")) * 0.5
				if can_snap and not has_snapped and global_position.y <= snap_trigger_y:
					# 절반 이상 등반 시 외줄이 끊어지는 함정 - 등반 해제 후 추락 + 피해
					current_ladder.trigger_snap()
					is_climbing = false
					is_on_ladder = false
					collision_mask = 1
					_ladder_cooldown = 0.35
					take_damage(1, Vector2.ZERO)
				# 사다리/외줄 최상단 도달 시 UP 키를 누르고 있으면 발판 상단 표면 위로 자연스럽게 도약 착지 (Pop-to-top)
				elif up_pressed and global_position.y <= top_y + 40.0:
					# top_y는 발판의 중심선(half-thickness 12px)을 가리키므로, 발판 상단 표면은 top_y - 12.0.
					# 캐릭터 원점은 충돌 박스의 "윗변"이라 발(박스 하단)이 표면 위에 오려면
					# 박스 높이만큼 더 끌어올려야 함 - 그렇지 않으면 발판을 통째로 관통한 채 착지해
					# collision_mask 복원 시 깊은 겹침으로 천장에 막힌 것처럼 튕겨나오는 버그가 발생했었음.
					var box_bottom_offset := 52.0
					if is_instance_valid(body_collision) and body_collision.shape is RectangleShape2D:
						var box_shape := body_collision.shape as RectangleShape2D
						box_bottom_offset = body_collision.position.y + box_shape.size.y * 0.5
					global_position.y = top_y - 12.0 - box_bottom_offset - 4.0
					velocity = Vector2(velocity.x, -140.0) # 표면 위로 튀어오르는 도약감
					is_climbing = false
					is_on_ladder = false
					collision_mask = 1
					_ladder_cooldown = 0.35 # 0.35초 쿨다운으로 발판 상단 표면 착지 완결 및 재등반 루프 방지

		if up_pressed:
			velocity.y = -220.0
		elif down_pressed:
			velocity.y = 220.0
		else:
			velocity.y = 0.0

		if Input.is_action_just_pressed("jump"):
			is_climbing = false
			collision_mask = 1
			velocity.y = jump_velocity
			if SoundManager:
				SoundManager.play_jump()
	else:
		collision_mask = 1
		if not is_on_floor():
			velocity.y += gravity * delta
			is_blocking = false

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
			if SoundManager:
				SoundManager.play_jump()

	if Input.is_action_just_pressed("attack"):
		_attack()

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
		if is_on_floor() and not is_attacking and not is_climbing:
			is_blocking = true

	move_and_slide()
	global_position.x = maxf(16.0, global_position.x)
	if not was_on_floor and is_on_floor() and velocity.y >= 0.0:
		_landing_bump = 1.0
	_update_visuals(delta)

var _walk_frame: int = 0
var _walk_frame_timer: float = 0.0
var _facing_mode: String = "RIGHT" # "FRONT", "BACK", "LEFT", "RIGHT"
var _attack_phase: int = 0

func _update_visuals(delta: float) -> void:
	var moving_state: bool = abs(velocity.x) > 10.0
	if moving_state and is_on_floor():
		_walk_cycle += delta * 14.0
		_walk_frame_timer += delta
		if _walk_frame_timer >= 0.11:
			_walk_frame_timer -= 0.11
			_walk_frame = (_walk_frame + 1) % 4
	else:
		_walk_cycle += delta * 2.0
		_walk_frame = 0

	if _landing_bump > 0.0:
		_landing_bump = max(0.0, _landing_bump - delta * 8.0)
	if _attack_anim_time > 0.0:
		_attack_anim_time = max(0.0, _attack_anim_time - delta)

	# 픽셀 블록(ColorRect) 전용 렌더링
	if is_instance_valid(sprite):
		sprite.visible = false
	if is_instance_valid(anim_sprite):
		anim_sprite.visible = false
	if is_instance_valid(body_rect):
		body_rect.visible = true
		
		# 1) 점프 3프레임 / 이동 4프레임 / IDLE 호흡 정밀 적용
		var scale_vec := Vector2(1.0, 1.0)
		var bob_offset := 0.0
		var leg_l := get_node_or_null("ColorRect/LegLeft") as ColorRect
		var leg_r := get_node_or_null("ColorRect/LegRight") as ColorRect
		var cape_node := get_node_or_null("Cape") as ColorRect
		
		if not is_on_floor():
			# JUMP 3-Frame Motion: Frame 1(Launch Squat), Frame 2(Airborne Stretch), Frame 3(Descent)
			if velocity.y < -150.0:
				scale_vec = Vector2(0.82, 1.25)
				bob_offset = -8.0
				if leg_l: leg_l.position.x = 4.0
				if leg_r: leg_r.position.x = 26.0
				if cape_node: cape_node.rotation = -0.15
			elif velocity.y > 150.0:
				scale_vec = Vector2(1.10, 0.90)
				bob_offset = 3.0
				if leg_l: leg_l.position.x = 2.0
				if leg_r: leg_r.position.x = 28.0
				if cape_node: cape_node.rotation = 0.1
			else:
				scale_vec = Vector2(0.95, 1.05)
				bob_offset = -2.0
				if cape_node: cape_node.rotation = 0.0
		elif moving_state:
			# RUN 4-Frame Motion Loop: 0(Neutral), 1(Left Forward), 2(Stride Dip), 3(Right Forward)
			match _walk_frame:
				0:
					scale_vec = Vector2(1.0, 1.0)
					bob_offset = 0.0
					if leg_l: leg_l.position.x = 6.0
					if leg_r: leg_r.position.x = 24.0
					if cape_node: cape_node.rotation = 0.0
				1:
					scale_vec = Vector2(1.10, 0.90)
					bob_offset = 2.0
					if leg_l: leg_l.position.x = 2.0
					if leg_r: leg_r.position.x = 28.0
					if cape_node: cape_node.rotation = -0.08
				2:
					scale_vec = Vector2(0.90, 1.10)
					bob_offset = -3.0
					if leg_l: leg_l.position.x = 0.0
					if leg_r: leg_r.position.x = 30.0
					if cape_node: cape_node.rotation = 0.12
				3:
					scale_vec = Vector2(1.08, 0.92)
					bob_offset = 1.0
					if leg_l: leg_l.position.x = 10.0
					if leg_r: leg_r.position.x = 20.0
					if cape_node: cape_node.rotation = -0.05
		else:
			# IDLE Breathing: 미세 수직 숨쉬기 호흡 연출
			var idle_breath: float = sin(_walk_cycle * 2.5) * 1.5
			scale_vec = Vector2(1.0 + idle_breath * 0.015, 1.0 - idle_breath * 0.015)
			bob_offset = idle_breath * 0.5
			if leg_l: leg_l.position.x = 6.0
			if leg_r: leg_r.position.x = 24.0
			if cape_node: cape_node.rotation = sin(_walk_cycle * 1.5) * 0.04

		body_rect.scale = scale_vec
		body_rect.position.y = bob_offset
		
		# 망토(Cape) 밀착 수직 파동 연출
		if cape_node:
			var cape_wave: float = sin(_walk_cycle * 1.2) * 1.2 if moving_state else 0.0
			if is_facing_right:
				cape_node.position.x = -6.0 - cape_wave
			else:
				cape_node.position.x = 24.0 + cape_wave

	# 2) 공격 4프레임 연속동작 연출 (Ref 1, Ref 2 반영)
	if is_attacking and is_instance_valid(sword_visual):
		_update_sword_attack_frames(delta)

func _update_sword_attack_frames(delta: float) -> void:
	if _attack_anim_time <= 0.0:
		return
	
	# ATTACK_DURATION(0.18s) 동안 4프레임 공격 애니메이션
	var progress: float = 1.0 - (_attack_anim_time / ATTACK_DURATION)
	_attack_phase = int(clamp(progress * 4.0, 0.0, 3.0))
	
	var base_reach: float = float(GameState.WEAPONS[GameState.weapon_index].get("reach", 30.0))
	var reach: float = base_reach + 35.0
	var slash_arc := sword_visual.get_node_or_null("SlashArc") as Polygon2D
	var dir_factor: float = 1.0 if is_facing_right else -1.0
	var base_x: float = sword_shape.position.x - (reach * 0.5 * dir_factor)
	
	match _attack_phase:
		0:
			# Frame 1: 칼 치켜세우기 (High Guard / Wind-up)
			sword_visual.position = Vector2(base_x - (reach * 0.3 * dir_factor), -12.0)
			sword_visual.rotation_degrees = -35.0 * dir_factor
			if slash_arc: slash_arc.visible = false
		1:
			# Frame 2: 와이드 커다란 호 베기 (Wide Crescent Arc Slash - Ref 2)
			sword_visual.position = Vector2(base_x - (reach * 0.2 * dir_factor), 4.0)
			sword_visual.rotation_degrees = 35.0 * dir_factor
			if slash_arc:
				slash_arc.visible = true
				slash_arc.scale = Vector2(1.2 * dir_factor, 1.2)
		2:
			# Frame 3: 찌르기/팔 뻗기 (Follow-through Thrust)
			sword_visual.position = Vector2(sword_shape.position.x + reach * 0.2, 8.0)
			sword_visual.rotation_degrees = 0.0
			if slash_arc:
				slash_arc.visible = true
				slash_arc.scale = Vector2(0.9, 0.9)
		3:
			# Frame 4: 납도 및 전투 태세 복귀 (Recovery Pose)
			sword_visual.position = Vector2(sword_shape.position.x, 4.0)
			sword_visual.rotation_degrees = 15.0 if is_facing_right else -15.0
			if slash_arc: slash_arc.visible = false

func flip_character() -> void:
	is_facing_right = not is_facing_right
	_facing_mode = "RIGHT" if is_facing_right else "LEFT"
	_apply_direction_visuals()
	
	var reach: float = float(GameState.WEAPONS[GameState.weapon_index].get("reach", 30.0))
	if is_facing_right:
		sword_shape.position.x = 16.0 + (reach * 0.5)
	else:
		sword_shape.position.x = 16.0 - (reach * 0.5)
	if is_instance_valid(sword_visual):
		sword_visual.position = Vector2(sword_shape.position.x - reach * 0.5, 4.0)

func set_facing_direction(dir_name: String) -> void:
	_facing_mode = dir_name.to_upper()
	_apply_direction_visuals()

func _apply_direction_visuals() -> void:
	var eye_l := get_node_or_null("ColorRect/EyeLeft") as ColorRect
	var eye_r := get_node_or_null("ColorRect/EyeRight") as ColorRect
	var mouth := get_node_or_null("ColorRect/SmileMouth") as ColorRect
	var blush_l := get_node_or_null("ColorRect/BlushLeft") as ColorRect
	var blush_r := get_node_or_null("ColorRect/BlushRight") as ColorRect
	var boot_l := get_node_or_null("ColorRect/LegLeft/BootLeft") as ColorRect
	var boot_r := get_node_or_null("ColorRect/LegRight/BootRight") as ColorRect
	var cape := get_node_or_null("Cape") as ColorRect
	
	match _facing_mode:
		"FRONT":
			if eye_l: eye_l.visible = true; eye_l.position.x = 9.0
			if eye_r: eye_r.visible = true; eye_r.position.x = 25.0
			if mouth: mouth.visible = true; mouth.position.x = 17.0
			if blush_l: blush_l.visible = true; blush_l.position.x = 4.0
			if blush_r: blush_r.visible = true; blush_r.position.x = 30.0
			if boot_l: boot_l.position.x = -3.0
			if boot_r: boot_r.position.x = -3.0
			if cape: cape.position.x = -6.0; cape.size.x = 50.0
		"BACK":
			if eye_l: eye_l.visible = false
			if eye_r: eye_r.visible = false
			if mouth: mouth.visible = false
			if blush_l: blush_l.visible = false
			if blush_r: blush_r.visible = false
			if boot_l: boot_l.position.x = -3.0
			if boot_r: boot_r.position.x = -3.0
			if cape: cape.position.x = -6.0; cape.size.x = 50.0
		"LEFT":
			if eye_l: eye_l.visible = true; eye_l.position.x = 4.0
			if eye_r: eye_r.visible = true; eye_r.position.x = 18.0
			if mouth: mouth.visible = true; mouth.position.x = 10.0
			if blush_l: blush_l.visible = true; blush_l.position.x = 1.0
			if blush_r: blush_r.visible = true; blush_r.position.x = 21.0
			if boot_l: boot_l.position.x = -7.0
			if boot_r: boot_r.position.x = -7.0
			if cape: cape.position.x = 24.0; cape.size.x = 18.0
		"RIGHT", _:
			if eye_l: eye_l.visible = true; eye_l.position.x = 15.0
			if eye_r: eye_r.position.x = 29.0
			if mouth: mouth.visible = true; mouth.position.x = 21.0
			if blush_l: blush_l.visible = true; blush_l.position.x = 10.0
			if blush_r: blush_r.visible = true; blush_r.position.x = 33.0
			if boot_l: boot_l.position.x = -1.0
			if boot_r: boot_r.position.x = -1.0
			if cape: cape.position.x = -6.0; cape.size.x = 18.0

func _attack() -> void:
	if is_attacking:
		return
	is_attacking = true
	_attack_anim_time = ATTACK_DURATION
	_already_hit.clear()
	sword.monitoring = true
	if is_instance_valid(sword_visual):
		sword_visual.visible = true
		sword_visual.rotation_degrees = 0.0
	if SoundManager:
		SoundManager.play_sword_swing()

	# 프레임 1 즉시 피격 감지 (고감도 피격 판정)
	call_deferred("_check_instant_attack_hits")

	get_tree().create_timer(ATTACK_DURATION).timeout.connect(func():
		is_attacking = false
		sword.monitoring = false
		if is_instance_valid(sword_visual):
			sword_visual.visible = false
			sword_visual.rotation_degrees = 0.0
			var slash_arc := sword_visual.get_node_or_null("SlashArc") as Polygon2D
			if slash_arc: slash_arc.visible = false
	)

func _check_instant_attack_hits() -> void:
	if not is_attacking or not is_instance_valid(sword):
		return
	for area in sword.get_overlapping_areas():
		_on_sword_area_entered(area)

func _on_sword_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area):
		return
	var hurtbox = area as Hurtbox
	var parent_node := area.get_parent()
	var target_owner := hurtbox.owner if (hurtbox and is_instance_valid(hurtbox.owner)) else parent_node

	if target_owner == self or (is_instance_valid(target_owner) and target_owner in _already_hit):
		return
	if is_instance_valid(target_owner):
		_already_hit.append(target_owner)

	var dmg: int = int(GameState.WEAPONS[GameState.weapon_index].get("damage", 1))
	var hit_dir: Vector2 = area.global_position - global_position
	if is_instance_valid(target_owner) and "global_position" in target_owner:
		hit_dir = target_owner.global_position - global_position

	# 1. Hurtbox 직접 시그널/메소드 전송
	if hurtbox and hurtbox.has_method("receive_hit"):
		hurtbox.receive_hit(dmg, hit_dir)
	elif area.has_method("receive_hit"):
		area.receive_hit(dmg, hit_dir)

	# 2. 타겟 오너/부모 노드 피격 핸들러 호출
	if is_instance_valid(target_owner):
		if target_owner.has_method("take_damage"):
			target_owner.take_damage(dmg, global_position)
		elif target_owner.has_method("_on_hit_received"):
			target_owner._on_hit_received(dmg, hit_dir)
		elif target_owner.has_method("_on_hit"):
			target_owner._on_hit(dmg, hit_dir)
		elif target_owner.has_method("receive_hit"):
			target_owner.receive_hit(dmg, hit_dir)

	if SoundManager:
		SoundManager.play_hit()

func fall_into_pit() -> void:
	if invincible or health <= 0:
		return
	velocity = Vector2.ZERO
	health = max(0, health - 2)
	health_changed.emit(health, max_health)
	if SoundManager:
		SoundManager.play_player_hurt()
	_spawn_floating_text("-2 (구덩이)", Color(1.0, 0.2, 0.2))
	if health <= 0:
		_die()
	else:
		global_position = spawn_point
		_start_invincibility()

func take_damage(amount: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if invincible or health <= 0:
		return
	if is_blocking and attacker_pos != Vector2.ZERO:
		var attack_from_right: bool = attacker_pos.x > global_position.x
		if (is_facing_right and attack_from_right) or (not is_facing_right and not attack_from_right):
			if SoundManager:
				SoundManager.play_shield_block()
			var knock_dir := -1.0 if attack_from_right else 1.0
			velocity.x = knock_dir * 120.0
			return
	health = max(0, health - amount)
	health_changed.emit(health, max_health)
	if SoundManager:
		SoundManager.play_player_hurt()
	_spawn_floating_text("-%d" % amount, Color(1, 0.3, 0.3))
	if health <= 0:
		_die()
	else:
		_start_invincibility()
		var knock_dir := 1.0 if attacker_pos.x < global_position.x else -1.0
		velocity = Vector2(knock_dir * 220.0, -180.0)

func _start_invincibility() -> void:
	invincible = true
	var tw := create_tween()
	tw.set_loops(6)
	tw.tween_property(self, "modulate:a", 0.3, 0.05)
	tw.tween_property(self, "modulate:a", 1.0, 0.05)
	get_tree().create_timer(INVINCIBLE_DURATION).timeout.connect(func():
		invincible = false
		modulate.a = 1.0
	)

func _spawn_floating_text(text_val: String, color_val: Color) -> void:
	FloatingText.spawn(get_parent(), global_position + Vector2(16, -10), text_val, color_val)

func _die() -> void:
	died.emit()
	if SoundManager:
		SoundManager.play_player_die()
	# DIE 모션: 사망 시 냄비 몸통이 바닥으로 납작하게 축소 찌그러지는 연출
	if is_instance_valid(body_rect):
		var tw := create_tween()
		tw.tween_property(body_rect, "scale", Vector2(1.35, 0.35), 0.25)
		tw.tween_property(body_rect, "position:y", 22.0, 0.25)
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(body_rect):
		body_rect.scale = Vector2(1.0, 1.0)
		body_rect.position.y = 0.0
	global_position = spawn_point
	health = max_health
	health_changed.emit(health, max_health)

func fill_pot() -> void:
	_is_filled_pot = true

func empty_pot() -> void:
	_is_filled_pot = false

func is_pot_filled() -> bool:
	return _is_filled_pot
