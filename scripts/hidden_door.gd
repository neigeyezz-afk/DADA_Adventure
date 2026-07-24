extends Area2D
class_name HiddenDoor
## 기획서 3.1 배경 상호작용 — 닫힌 문/동굴 앞에서 '위(interact)'를 누르면
## 보상 골드 지급 + 안내와 함께, 숨겨진 암시장 공간(방)으로 실제 입장한다.

signal opened()

@export var reward_gold: int = 50
@export var room_entry_position: Vector2
@export var room_limit_left: float
@export var room_limit_top: float
@export var room_limit_right: float
@export var room_limit_bottom: float

@onready var prompt: Label = $Prompt

var _player_in: bool = false
var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false

func _process(_delta: float) -> void:
	if _player_in and not _used and Input.is_action_just_pressed("interact"):
		_used = true
		GameState.add_gold(reward_gold)
		if prompt:
			prompt.text = "Found the Black Market! +%d G" % reward_gold
		opened.emit()
		var player := get_tree().get_first_node_in_group("player") as PlayerDADA
		if player:
			player.enter_room(room_entry_position, room_limit_left, room_limit_top, room_limit_right, room_limit_bottom)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerDADA and not _used:
		_player_in = true
		if prompt:
			prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerDADA:
		_player_in = false
		if prompt and not _used:
			prompt.visible = false
