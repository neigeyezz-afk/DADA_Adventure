extends Area2D
class_name RoomExit
## 방(상점방/암시장방) 안의 출구 — 상호작용하면 방에 들어오기 전 위치로 되돌아간다.

@onready var prompt: Label = $Prompt
var _player_in: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false

func _process(_delta: float) -> void:
	if _player_in and Input.is_action_just_pressed("interact"):
		var player := get_tree().get_first_node_in_group("player") as PlayerDADA
		if player:
			player.exit_room()

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
