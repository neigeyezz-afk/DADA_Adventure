extends Node2D
class_name FlowerMob

const FloatingText = preload("res://scripts/floating_text.gd")
const PICKUP_SCENE: PackedScene = preload("res://scenes/pickup.tscn")

@export var flower_type: int = 1 # 1: Sky Blue Flower, 2: White Daisy, 3: Golden Cluster, 4: Orange Blossom
@export var drop_type: String = "gold" # "gold" or "material"
@export var drop_material_name: String = "noodle"
@export var drop_amount: int = 2

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual_root: Node2D = $VisualRoot

var hp: int = 1
var touch_damage: int = 0
var _is_dead: bool = false
var _anim_cycle: float = 0.0

func _ready() -> void:
	hp = 1
	touch_damage = 0
	_anim_cycle = randf() * 10.0
	if is_instance_valid(hurtbox):
		hurtbox.hit_received.connect(_on_hit_received)
	_build_godot_pixel_flower()

func _process(delta: float) -> void:
	if _is_dead or not is_instance_valid(visual_root):
		return
	_anim_cycle += delta * 3.0
	visual_root.rotation = sin(_anim_cycle) * 0.06

func _build_godot_pixel_flower() -> void:
	if not is_instance_valid(visual_root):
		return

	for child in visual_root.get_children():
		child.queue_free()

	var petal_color  := Color(0.25, 0.65, 0.95, 1.0) # 1: Sky Blue
	var center_color := Color(1.0, 0.85, 0.20, 1.0)
	var stem_color   := Color(0.25, 0.65, 0.22, 1.0)
	var outline_col  := Color(0.10, 0.14, 0.18, 1.0)
	var leaf_color   := Color(0.18, 0.52, 0.16, 1.0)

	if flower_type == 2: # White Daisy
		petal_color = Color(0.96, 0.96, 0.96, 1.0)
		center_color = Color(1.0, 0.75, 0.15, 1.0)
	elif flower_type == 3: # Golden Cluster
		petal_color = Color(1.0, 0.72, 0.18, 1.0)
		center_color = Color(0.9, 0.35, 0.10, 1.0)
	elif flower_type == 4: # Orange Blossom
		petal_color = Color(1.0, 0.55, 0.15, 1.0)
		center_color = Color(0.75, 0.2, 0.08, 1.0)

	# 1. 줄기 & 잎사귀 (Stem & Leaves)
	var stem_out := ColorRect.new()
	stem_out.size = Vector2(8.0, 24.0)
	stem_out.position = Vector2(-4.0, -24.0)
	stem_out.color = outline_col
	visual_root.add_child(stem_out)

	var stem_body := ColorRect.new()
	stem_body.size = Vector2(4.0, 22.0)
	stem_body.position = Vector2(-2.0, -23.0)
	stem_body.color = stem_color
	visual_root.add_child(stem_body)

	# 잎사귀
	var leaf_l := ColorRect.new()
	leaf_l.size = Vector2(8.0, 5.0)
	leaf_l.position = Vector2(-10.0, -14.0)
	leaf_l.color = leaf_color
	visual_root.add_child(leaf_l)

	var leaf_r := ColorRect.new()
	leaf_r.size = Vector2(8.0, 5.0)
	leaf_r.position = Vector2(2.0, -18.0)
	leaf_r.color = leaf_color
	visual_root.add_child(leaf_r)

	# 2. 픽셀 꽃잎 (개별 픽셀 꽃잎 - 검정 사각 박스 완전히 소거!)
	var py := -36.0
	var petal_positions: Array[Vector2] = [
		Vector2(-5.0, py - 14.0), # 상
		Vector2(-5.0, py + 4.0),  # 하
		Vector2(-14.0, py - 5.0), # 좌
		Vector2(4.0, py - 5.0),   # 우
		Vector2(-11.0, py - 11.0),# 좌상
		Vector2(1.0, py - 11.0), # 우상
		Vector2(-11.0, py + 1.0), # 좌하
		Vector2(1.0, py + 1.0)   # 우하
	]

	# 각 꽃잎마다 1px 외곽 테두리 적용 후 꽃잎 메인 컬러 배치 (투명 배경 유지)
	for p_pos in petal_positions:
		var p_out := ColorRect.new()
		p_out.size = Vector2(12.0, 12.0)
		p_out.position = p_pos + Vector2(-1.0, -1.0)
		p_out.color = outline_col
		visual_root.add_child(p_out)

	for p_pos in petal_positions:
		var p_body := ColorRect.new()
		p_body.size = Vector2(10.0, 10.0)
		p_body.position = p_pos
		p_body.color = petal_color
		visual_root.add_child(p_body)

	# 3. 꽃 수술 중앙 핵심 픽셀 (Flower Core Center)
	var center_out := ColorRect.new()
	center_out.size = Vector2(14.0, 14.0)
	center_out.position = Vector2(-7.0, py - 7.0)
	center_out.color = outline_col
	visual_root.add_child(center_out)

	var center_box := ColorRect.new()
	center_box.size = Vector2(12.0, 12.0)
	center_box.position = Vector2(-6.0, py - 6.0)
	center_box.color = center_color
	visual_root.add_child(center_box)

	var shine := ColorRect.new()
	shine.size = Vector2(4.0, 4.0)
	shine.position = Vector2(-4.0, py - 4.0)
	shine.color = Color(1.0, 1.0, 1.0, 0.85)
	visual_root.add_child(shine)

func _on_hit_received(_damage: int, _direction: Vector2) -> void:
	take_damage(_damage, global_position)

func take_damage(_damage: int, _attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if _is_dead:
		return
	hp -= 1
	if hp <= 0:
		_die()

func _die() -> void:
	_is_dead = true
	if SoundManager:
		SoundManager.play_hit()
	FloatingText.spawn(get_parent(), global_position, "Flower Pop!", Color(0.4, 0.9, 1.0))
	call_deferred("_deferred_spawn_drop")
	queue_free()

func _deferred_spawn_drop() -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return
	var drop := PICKUP_SCENE.instantiate() as Pickup
	parent_node.add_child(drop)
	drop.global_position = global_position + Vector2(0, -12)
	drop.setup(drop_type, drop_amount, drop_material_name)
