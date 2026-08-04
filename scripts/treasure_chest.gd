extends Node2D
class_name TreasureChest

## ==========================================================
## TreasureChest: 정교한 절차적 픽셀 아트 보물상자 & UP-DOWN 3회 연타 해제
## 레퍼런스 이미지 1~4 기반 고품질 픽셀 디자인 + QTE 키 입력 연동
## ==========================================================

const FloatingText = preload("res://scripts/floating_text.gd")

@export var reward_gold: int = 50
@export var recipe_unlock: String = ""

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual_root: Node2D = get_node_or_null("VisualRoot")
@onready var interact_area: Area2D = get_node_or_null("InteractArea")

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")

var _opened: bool = false
var _player_inside: bool = false
var _combo_count: int = 0      # 0 to 3
var _current_step: int = 0     # 0: waiting for UP, 1: waiting for DOWN
var _combo_timer: float = 0.0
var _prompt_label: Label = null

func _ready() -> void:
	if is_instance_valid(hurtbox):
		hurtbox.hit_received.connect(_on_hit)
	if is_instance_valid(interact_area):
		interact_area.body_entered.connect(_on_player_entered)
		interact_area.body_exited.connect(_on_player_exited)

	_create_prompt_label()
	_build_pixel_chest(false)

func _process(delta: float) -> void:
	if _opened:
		if is_instance_valid(_prompt_label):
			_prompt_label.visible = false
		return

	if _combo_count > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_reset_combo()

	if _player_inside and not _opened:
		_handle_qte_input()

func _create_prompt_label() -> void:
	_prompt_label = Label.new()
	_prompt_label.text = "⬆️ ⬇️ [위아래 3회 연타]"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(-70, -62)
	_prompt_label.size = Vector2(140, 24)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_prompt_label.add_theme_constant_override("outline_size", 4)
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.visible = false
	add_child(_prompt_label)

func _on_player_entered(body: Node2D) -> void:
	if body is PlayerDADA and not _opened:
		_player_inside = true
		if is_instance_valid(_prompt_label):
			_prompt_label.visible = true

func _on_player_exited(body: Node2D) -> void:
	if body is PlayerDADA:
		_player_inside = false
		if is_instance_valid(_prompt_label):
			_prompt_label.visible = false
		_reset_combo()

func _handle_qte_input() -> void:
	var up_just := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var down_just := Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)

	# 0단계: UP 키 대기
	if _current_step == 0:
		if up_just:
			_current_step = 1
			_combo_timer = 2.0
			if SoundManager:
				SoundManager.play_jump()
	# 1단계: DOWN 키 대기
	elif _current_step == 1:
		if down_just:
			_combo_count += 1
			_current_step = 0
			_combo_timer = 2.0
			_shake_chest()
			
			if _combo_count < 3:
				FloatingText.spawn(get_parent(), global_position + Vector2(0, -35), "🔓 UP-DOWN (%d/3)" % _combo_count, Color(1.0, 0.85, 0.2))
				if SoundManager:
					SoundManager.play_hit()
			else:
				FloatingText.spawn(get_parent(), global_position + Vector2(0, -40), "🎉 3/3 UNLOCKED!", Color(0.2, 1.0, 0.4))
				open_chest()

func _reset_combo() -> void:
	_combo_count = 0
	_current_step = 0
	_combo_timer = 0.0

func _shake_chest() -> void:
	if not is_instance_valid(visual_root):
		return
	var tw := create_tween()
	tw.tween_property(visual_root, "position:x", -3.0, 0.04)
	tw.tween_property(visual_root, "position:x", 3.0, 0.04)
	tw.tween_property(visual_root, "position:x", 0.0, 0.04)

func open_chest() -> void:
	if _opened:
		return
	_opened = true
	if is_instance_valid(_prompt_label):
		_prompt_label.visible = false

	_build_pixel_chest(true) # 열린 상태 픽셀 아트 렌더링
	if SoundManager:
		SoundManager.play_chest_open()

	# 보상 드롭 (골드 피크업 4개)
	var count := 4
	for i in count:
		var p := PICKUP_SCENE.instantiate() as Pickup
		get_parent().add_child(p)
		p.global_position = global_position + Vector2(randf_range(-22, 22), -26)
		p.setup("gold", int(reward_gold / count))

	# 레시피 / 재료 드롭
	var m := PICKUP_SCENE.instantiate() as Pickup
	get_parent().add_child(m)
	m.global_position = global_position + Vector2(0, -30)
	m.setup("material", 2, "cheese")

	if recipe_unlock != "" and not GameState.has_recipe(recipe_unlock):
		GameState.unlocked_recipes.append(recipe_unlock)
		GameState.save_state()

func _on_hit(_damage: int, _dir: Vector2) -> void:
	# 근접 공격 대신 UP-DOWN 3회 연타로 안내
	if not _opened:
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -30), "⬆️ ⬇️ 3회 연타로 열기!", Color(1.0, 0.4, 0.3))

# ==========================================================
# 🎨 레퍼런스 1~4 기반 정교한 절차적 픽셀 아트 렌더링
# ==========================================================
func _build_pixel_chest(is_open: bool) -> void:
	if not is_instance_valid(visual_root):
		return
	for c in visual_root.get_children():
		c.queue_free()

	# 레퍼런스 팔레트 (풍부한 나무 & 고풍스러운 앤티크 황금)
	var outline_col := Color(0.12, 0.07, 0.04, 1.0)
	var wood_dark   := Color(0.38, 0.20, 0.08, 1.0)
	var wood_mid    := Color(0.56, 0.32, 0.14, 1.0)
	var wood_light  := Color(0.72, 0.46, 0.22, 1.0)
	var gold_dark   := Color(0.58, 0.40, 0.08, 1.0)
	var gold_mid    := Color(0.94, 0.74, 0.18, 1.0)
	var gold_light  := Color(1.0, 0.90, 0.48, 1.0)
	var gold_shine  := Color(1.0, 0.98, 0.80, 1.0)
	var gem_red     := Color(0.92, 0.25, 0.25, 1.0)
	var gem_green   := Color(0.25, 0.88, 0.40, 1.0)

	if not is_open:
		# ----------------------------------------------------
		# 📦 닫힌 상태 (Closed Chest - Ref 1, 3, 4)
		# ----------------------------------------------------
		# 1. 외곽 테두리 (W:40, H:28)
		_add_rect(Vector2(-20, -28), Vector2(40, 28), outline_col)
		
		# 2. 메인 원목 몸통 & 나뭇결
		_add_rect(Vector2(-18, -26), Vector2(36, 26), wood_mid)
		_add_rect(Vector2(-18, -26), Vector2(36, 6), wood_light) # 상단 나무 결 하이라이트
		_add_rect(Vector2(-18, -12), Vector2(36, 3), wood_dark) # 나뭇결 음영 띠
		_add_rect(Vector2(-18, -2), Vector2(36, 2), wood_dark)

		# 3. 아치형 돔 뚜껑 곡선 계단 (Rounded Arch Lid)
		_add_rect(Vector2(-16, -30), Vector2(32, 4), outline_col)
		_add_rect(Vector2(-14, -29), Vector2(28, 3), wood_light)
		_add_rect(Vector2(-10, -32), Vector2(20, 3), outline_col)
		_add_rect(Vector2(-8, -31), Vector2(16, 2), gold_shine)

		# 4. 황금 세로 테두리 밴드 (Golden Banding Straps)
		for side_x in [-18.0, 12.0]:
			_add_rect(Vector2(side_x - 1, -27), Vector2(8, 27), outline_col)
			_add_rect(Vector2(side_x, -26), Vector2(6, 25), gold_mid)
			_add_rect(Vector2(side_x + 1, -26), Vector2(2, 25), gold_light) # 세로 광택선
			
			# 모서리 리벳 볼트 (Corner Rivets - Ref 3, 4)
			_add_rect(Vector2(side_x + 2, -24), Vector2(2, 2), gold_dark)
			_add_rect(Vector2(side_x + 2, -5), Vector2(2, 2), gold_dark)

		# 5. 가로 황금 결속 띠
		_add_rect(Vector2(-19, -15), Vector2(38, 5), outline_col)
		_add_rect(Vector2(-18, -14), Vector2(36, 3), gold_mid)

		# 6. 팔각형 황금 자물쇠 메인 플레이트 (Ref 1, 4)
		_add_rect(Vector2(-7, -19), Vector2(14, 16), outline_col)
		_add_rect(Vector2(-6, -18), Vector2(12, 14), gold_mid)
		_add_rect(Vector2(-5, -17), Vector2(4, 12), gold_light) # 좌측 금장 광택
		
		# U자형 고리 (Shackle)
		_add_rect(Vector2(-4, -22), Vector2(8, 4), outline_col)
		_add_rect(Vector2(-3, -21), Vector2(6, 3), gold_mid)

		# 열쇠구멍 (Keyhole - Ref 1)
		_add_rect(Vector2(-2, -15), Vector2(4, 4), outline_col)
		_add_rect(Vector2(-1.5, -12), Vector2(3, 5), outline_col)
	else:
		# ----------------------------------------------------
		# 🎁 열린 상태 (Open Chest - Ref 2, 3)
		# ----------------------------------------------------
		# 1. 하단 박스 몸체 (Open Base Box)
		_add_rect(Vector2(-20, -18), Vector2(40, 18), outline_col)
		_add_rect(Vector2(-18, -16), Vector2(36, 16), wood_dark)

		# 2. 열린 상자 내부 황금/보석 수놓인 빛나는 보물 (Gold & Gems Inside - Ref 3)
		_add_rect(Vector2(-16, -15), Vector2(32, 11), Color(0.22, 0.12, 0.08)) # 내부 어두운 깊이감
		
		# 금화 더미 픽셀 (Golden Coins Layer)
		for gx in [-14, -8, -2, 4, 10]:
			_add_rect(Vector2(gx, -12), Vector2(5, 5), gold_mid)
			_add_rect(Vector2(gx + 1, -12), Vector2(2, 2), gold_light)

		# 보석 반짝임 (Red & Green Gemstone Shimmer)
		_add_rect(Vector2(-10, -13), Vector2(4, 4), gem_red)
		_add_rect(Vector2(-9, -13), Vector2(2, 2), gold_shine)
		_add_rect(Vector2(4, -13), Vector2(4, 4), gem_green)
		_add_rect(Vector2(5, -13), Vector2(2, 2), gold_shine)

		# 왕관 보관 하이라이트
		_add_rect(Vector2(-3, -16), Vector2(6, 6), gold_light)

		# 3. 열린 하단 프레임 황금 테두리
		_add_rect(Vector2(-19, -3), Vector2(38, 4), gold_mid)

		# 4. 뒤로 넘어가 열린 아치 뚜껑 (Open Arch Lid - Ref 2)
		_add_rect(Vector2(-20, -36), Vector2(40, 18), outline_col)
		_add_rect(Vector2(-18, -34), Vector2(36, 14), wood_mid)
		_add_rect(Vector2(-18, -34), Vector2(36, 4), wood_light)
		
		# 뚜껑 안쪽 황금 테두리
		_add_rect(Vector2(-18, -22), Vector2(36, 4), gold_mid)
		_add_rect(Vector2(-18, -34), Vector2(4, 14), gold_dark)
		_add_rect(Vector2(14, -34), Vector2(4, 14), gold_dark)

func _add_rect(pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = col
	visual_root.add_child(r)
