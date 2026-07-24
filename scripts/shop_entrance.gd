extends Area2D
class_name ShopEntrance
## 상점 입구 — 상호작용하면 별도 공간(상점방)으로 입장한다.
## 실제 매입/구매 로직은 방 안에 배치된 Shop 인스턴스가 그대로 담당한다.

@export var room_entry_position: Vector2
@export var room_limit_left: float
@export var room_limit_top: float
@export var room_limit_right: float
@export var room_limit_bottom: float

@onready var prompt: Label = $Prompt
@onready var level_sign: Label = $LevelSign
var _player_in: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false
	GameState.wealth_changed.connect(func(_l: int, _e: int) -> void: _refresh_level_sign())
	_refresh_level_sign()

func _refresh_level_sign() -> void:
	if level_sign:
		level_sign.text = "Shop Lv %d" % GameState.wealth_level

func _process(_delta: float) -> void:
	if _player_in and Input.is_action_just_pressed("interact"):
		var player := get_tree().get_first_node_in_group("player") as PlayerDADA
		if player:
			player.enter_room(room_entry_position, room_limit_left, room_limit_top, room_limit_right, room_limit_bottom, true)

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
