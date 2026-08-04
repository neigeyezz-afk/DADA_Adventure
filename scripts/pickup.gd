extends Area2D
class_name Pickup
## 몬스터 사망/숨겨진 요소에서 튀어나오는 획득물. 플레이어와 닿으면 자동 획득.


var kind: String = "material"
var amount: int = 1
var material_name: String = "water"
var _collected: bool = false

@onready var rect: ColorRect = $ColorRect

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(k: String, a: int, material_name_override: String = "") -> void:
	kind = k
	amount = a
	if material_name_override != "":
		material_name = material_name_override
	elif kind != "gold":
		material_name = "water"
	rect.color = _get_pickup_color()
	var base_y := position.y
	var tw := create_tween()
	tw.tween_property(self, "position:y", base_y - 12.0, 0.15)
	tw.tween_property(self, "position:y", base_y, 0.2)

func _get_pickup_color() -> Color:
	if kind == "gold":
		return Color(1, 0.85, 0.1)
	match material_name:
		"water":
			return Color(0.2, 0.6, 1.0)
		"noodle":
			return Color(0.95, 0.85, 0.55)
		"meat_stock":
			return Color(0.9, 0.35, 0.2)
		"cheese":
			return Color(1.0, 0.95, 0.3)
		_:
			return Color(0.2, 0.9, 0.4)

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body is PlayerDADA:
		if kind == "gold":
			_collected = true
			GameState.add_gold(amount)
			if SoundManager:
				SoundManager.play_pickup()
			FloatingText.spawn(get_parent(), global_position, "+%d G" % amount, Color(1.0, 0.85, 0.2))
			queue_free()
		else:
			if GameState.can_add_material(material_name, amount):
				_collected = true
				GameState.add_material(material_name, amount)
				if SoundManager:
					SoundManager.play_pickup()
				FloatingText.spawn(get_parent(), global_position, "+%d Mat" % amount, Color(0.3, 0.95, 0.45))
				queue_free()
			else:
				# Pot inventory full effect: slight jump up
				var tw := create_tween()
				tw.tween_property(self, "position:y", position.y - 8.0, 0.1)
				tw.tween_property(self, "position:y", position.y, 0.1)

