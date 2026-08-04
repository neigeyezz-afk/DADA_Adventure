extends Area2D
class_name VillageEntrance

## 마을 입구: 플레이어가 다가가서 상호작용(W/Up)을 누르거나 도달하면 마을 스테이지로 이동합니다.

@export var target_scene: String = "res://scenes/town_stage.tscn"

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false

func _ready() -> void:
	if is_instance_valid(prompt_label):
		prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerDADA or body.is_in_group("player"):
		_player_in_range = true
		if is_instance_valid(prompt_label):
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerDADA or body.is_in_group("player"):
		_player_in_range = false
		if is_instance_valid(prompt_label):
			prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and (event.is_action_pressed("interact") or event.is_action_pressed("ui_up")):
		_enter_village()

func _enter_village() -> void:
	if ResourceLoader.exists(target_scene):
		get_tree().change_scene_to_file(target_scene)
