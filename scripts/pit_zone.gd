extends Area2D
class_name PitZone
## 바닥이 끊긴 구덩이 구간 — 플레이어가 떨어지면 무적 여부와 상관없이 즉시 사망 처리 후 리스폰.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerDADA:
		(body as PlayerDADA).fall_into_pit()
