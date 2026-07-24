extends Node2D
class_name CoinBox
## 공격하면 골드 코인이 쏟아지는 보상 상자. 고지대 보상용 오브젝트.

@export var coin_count: int = 3
@export var coin_value: int = 10   # 코인 1개당 골드량

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var body_rect: ColorRect = $ColorRect

const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")
var _opened: bool = false

func _ready() -> void:
	hurtbox.hit_received.connect(_on_hit)

func _on_hit(_damage: int, _dir: Vector2) -> void:
	if _opened:
		return
	_opened = true
	body_rect.color = Color(0.4, 0.32, 0.15, 1)   # 연 상자는 어두운 색으로 표시
	for i in coin_count:
		var p := PICKUP_SCENE.instantiate() as Pickup
		get_parent().add_child(p)
		p.global_position = global_position + Vector2(randf_range(-14, 14), -18)
		p.setup("gold", coin_value)
