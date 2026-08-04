extends Area2D
class_name TutorialSign

## 레트로 아케이드 조이스틱 디자인의 조작법 안내 캐비닛

@export var title: String = "기본 조작법"
@export_multiline var guide_text: String = "이동: ← / →\n점프: Space\n공격: A\n상호작용/등반: W / Up\n레시피북: R\n인벤토리: Q\n일시정지: P"

@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var panel: Panel = get_node_or_null("GuidePanel")
@onready var title_label: Label = get_node_or_null("GuidePanel/VBox/TitleLabel")
@onready var text_label: Label = get_node_or_null("GuidePanel/VBox/TextLabel")
@onready var visual_root: Node2D = get_node_or_null("VisualRoot")

var _player_in_range: bool = false

func _ready() -> void:
	if is_instance_valid(panel):
		panel.visible = false
	if is_instance_valid(prompt_label):
		prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_retro_arcade_joystick()

func _build_retro_arcade_joystick() -> void:
	if not is_instance_valid(visual_root):
		return

	for c in visual_root.get_children():
		c.queue_free()

	var outline_col := Color(0.08, 0.10, 0.16, 1.0)
	var cabinet_col := Color(0.20, 0.24, 0.36, 1.0)
	var deck_col    := Color(0.70, 0.72, 0.78, 1.0)
	var screen_bg   := Color(0.12, 0.16, 0.24, 1.0)
	var screen_glow := Color(0.35, 0.85, 1.00, 1.0)
	var joystick_red:= Color(0.92, 0.22, 0.25, 1.0)
	var btn_yellow  := Color(1.00, 0.85, 0.20, 1.0)
	var btn_blue    := Color(0.20, 0.65, 0.95, 1.0)

	# A) 캐비닛 본체 프레임 (Arcade Cabinet Frame)
	var frame_out := ColorRect.new()
	frame_out.size = Vector2(44.0, 56.0)
	frame_out.position = Vector2(-22.0, -56.0)
	frame_out.color = outline_col
	visual_root.add_child(frame_out)

	var frame_body := ColorRect.new()
	frame_body.size = Vector2(40.0, 52.0)
	frame_body.position = Vector2(-20.0, -54.0)
	frame_body.color = cabinet_col
	visual_root.add_child(frame_body)

	# B) 화면 모니터 영역 (Arcade Screen)
	var screen_out := ColorRect.new()
	screen_out.size = Vector2(32.0, 22.0)
	screen_out.position = Vector2(-16.0, -48.0)
	screen_out.color = outline_col
	visual_root.add_child(screen_out)

	var screen_inner := ColorRect.new()
	screen_inner.size = Vector2(28.0, 18.0)
	screen_inner.position = Vector2(-14.0, -46.0)
	screen_inner.color = screen_bg
	visual_root.add_child(screen_inner)

	# 화면 내부 레트로 조이스틱 아이콘 선
	var screen_icon := ColorRect.new()
	screen_icon.size = Vector2(10.0, 10.0)
	screen_icon.position = Vector2(-5.0, -42.0)
	screen_icon.color = screen_glow
	visual_root.add_child(screen_icon)

	# C) 조이스틱 데크 받침대 (Control Deck Slant)
	var deck := ColorRect.new()
	deck.size = Vector2(42.0, 14.0)
	deck.position = Vector2(-21.0, -24.0)
	deck.color = deck_col
	visual_root.add_child(deck)

	# D) 빨간색 조이스틱 레버 (Joystick Shaft & Red Ball Top)
	var shaft := ColorRect.new()
	shaft.size = Vector2(4.0, 12.0)
	shaft.position = Vector2(-11.0, -32.0)
	shaft.color = outline_col
	visual_root.add_child(shaft)

	var ball_out := ColorRect.new()
	ball_out.size = Vector2(12.0, 12.0)
	ball_out.position = Vector2(-15.0, -40.0)
	ball_out.color = outline_col
	visual_root.add_child(ball_out)

	var ball := ColorRect.new()
	ball.size = Vector2(10.0, 10.0)
	ball.position = Vector2(-14.0, -39.0)
	ball.color = joystick_red
	visual_root.add_child(ball)

	# 조이스틱 볼 하이라이트
	var ball_shine := ColorRect.new()
	ball_shine.size = Vector2(3.0, 3.0)
	ball_shine.position = Vector2(-12.0, -37.0)
	ball_shine.color = Color(1.0, 1.0, 1.0, 0.85)
	visual_root.add_child(ball_shine)

	# E) 아케이드 버튼들 (Yellow & Blue Pixel Buttons)
	var b1 := ColorRect.new()
	b1.size = Vector2(6.0, 6.0)
	b1.position = Vector2(2.0, -20.0)
	b1.color = btn_yellow
	visual_root.add_child(b1)

	var b2 := ColorRect.new()
	b2.size = Vector2(6.0, 6.0)
	b2.position = Vector2(11.0, -20.0)
	b2.color = btn_blue
	visual_root.add_child(b2)

	var b3 := ColorRect.new()
	b3.size = Vector2(6.0, 6.0)
	b3.position = Vector2(6.0, -14.0)
	b3.color = joystick_red
	visual_root.add_child(b3)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if is_instance_valid(prompt_label):
			prompt_label.visible = true
		_show_guide()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if is_instance_valid(prompt_label):
			prompt_label.visible = false
		if is_instance_valid(panel):
			panel.visible = false

func _show_guide() -> void:
	if is_instance_valid(title_label):
		title_label.text = "🕹️ " + title
	if is_instance_valid(text_label):
		text_label.text = guide_text

	if is_instance_valid(panel):
		panel.visible = true
		# 텍스트 길이에 맞춰 팝업 창 폭을 타이트하게 자동 조절 (Auto-fit width)
		var max_line_len: int = 0
		var lines := guide_text.split("\n")
		for line in lines:
			if line.length() > max_line_len:
				max_line_len = line.length()
		
		# 글자 수 기반 너비 계산 (최소 180px, 글자당 11px + 여백)
		var calculated_w := maxf(180.0, float(max_line_len * 11 + 36))
		panel.size.x = calculated_w
		panel.position.x = -calculated_w * 0.5
