extends Node2D
class_name SecretSpot
## 기획서 3.1 '허공 찌르기' — 아무것도 없어 보이는 허공을 공격하면
## 숨겨진 골드나 희귀 소재가 쏟아진다. 평소엔 보이지 않는다.

@export var reward_kind: String = "gold"   # "gold" 또는 "material"
@export var reward_amount: int = 25
@export var pop_count: int = 3

@onready var hurtbox: Hurtbox = $Hurtbox

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")
var _triggered: bool = false

func _ready() -> void:
	hurtbox.hit_received.connect(_on_hit)

func _on_hit(_damage: int, _dir: Vector2) -> void:
	if _triggered:
		return
	_triggered = true
	for i in pop_count:
		var p := PICKUP_SCENE.instantiate() as Pickup
		get_parent().add_child(p)
		p.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-16, 4))
		var amt := reward_amount if i == 0 else maxi(1, reward_amount / 3)
		p.setup(reward_kind, amt)
	queue_free()
