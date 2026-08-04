extends Node2D

## 마을 스테이지: 상점(Shop)과 화롯불(Campfire)이 모여있는 평화로운 무사지역 마을.

@onready var player: PlayerDADA = $DADA
@onready var portal_stage1: Area2D = $PortalToStage1

func _ready() -> void:
	if is_instance_valid(portal_stage1):
		portal_stage1.body_entered.connect(_on_portal_stage1_body_entered)

func _on_portal_stage1_body_entered(body: Node2D) -> void:
	if body is PlayerDADA or body.is_in_group("player"):
		get_tree().change_scene_to_file("res://scenes/test_world.tscn")
