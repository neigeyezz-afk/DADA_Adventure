extends Area2D
class_name SpikeHazard
## 구덩이 바닥의 가시 — 닿으면 무적 여부와 상관없이 즉시 사망.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		(body as PlayerDADA).die_by_spikes()
