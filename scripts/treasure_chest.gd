extends Node2D
class_name TreasureChest

const FloatingText = preload("res://scripts/floating_text.gd")

@export var reward_gold: int = 30
@export var recipe_unlock: String = "" # e.g. "Cheese Ramen" or "Kimchi Ramen"

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
	body_rect.color = Color(0.3, 0.25, 0.15, 1) # Dark opened chest
	if SoundManager:
		SoundManager.play_chest_open()
	FloatingText.spawn(get_parent(), global_position, "Treasure Opened!", Color(1.0, 0.9, 0.2))
	
	# Spawn Gold Pickups
	var count := 4
	for i in count:
		var p := PICKUP_SCENE.instantiate() as Pickup
		get_parent().add_child(p)
		p.global_position = global_position + Vector2(randf_range(-20, 20), -24)
		p.setup("gold", int(reward_gold / count))

	# Spawn Materials
	var m := PICKUP_SCENE.instantiate() as Pickup
	get_parent().add_child(m)
	m.global_position = global_position + Vector2(0, -28)
	m.setup("material", 2, "cheese")

	# Unlock recipe if defined
	if recipe_unlock != "" and not GameState.has_recipe(recipe_unlock):
		GameState.unlocked_recipes.append(recipe_unlock)
		GameState.save_state()
