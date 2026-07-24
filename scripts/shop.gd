extends Area2D
class_name Shop
## 푸르지아 마을 상점 — 하플링 상인 '토리'.
## 플레이어가 접근해 '위(interact)'를 누르면 HUD의 상점 패널을 연다.
## 소재 판매/무기 구매 로직 자체는 GameState + HUD가 담당.

@onready var prompt: Label = $Prompt
var _player_in: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false

func _process(_delta: float) -> void:
	if _player_in and Input.is_action_just_pressed("interact"):
		get_tree().call_group("hud", "toggle_shop")

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		_player_in = true
		if prompt:
			prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerDADA:
		_player_in = false
		if prompt:
			prompt.visible = false
		get_tree().call_group("hud", "close_shop")
