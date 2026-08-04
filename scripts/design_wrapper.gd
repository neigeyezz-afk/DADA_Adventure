extends Node
class_name DesignWrapper
## ==========================================================
## DesignWrapper: 캐릭터, 몬스터, 드롭템, 보물상자, 상점 디자인 래핑 관리 시스템
## ==========================================================

# 래핑 상태 모드 (true = 디자인 래핑 적용, false = 초기 블록 형태)
static var is_wrapping_enabled: bool = true

# 1. 플레이어 디자인 래핑 적용
static func wrap_player(player_node: CharacterBody2D, texture_path: String = "", custom_scale: Vector2 = Vector2.ONE) -> void:
	if not is_instance_valid(player_node):
		return
	var sprite: Sprite2D = player_node.get_node_or_null("Sprite2D")
	var color_rect: ColorRect = player_node.get_node_or_null("ColorRect")
	
	if texture_path != "" and FileAccess.file_exists(texture_path):
		var tex := load(texture_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.visible = true
			sprite.scale = custom_scale
			if color_rect:
				color_rect.visible = false
			return
	
	# 기본 블록 모드 유지/복원
	if color_rect:
		color_rect.visible = true
	if sprite and texture_path == "":
		sprite.visible = false

# 2. 몬스터 디자인 래핑 적용
static func wrap_monster(monster_node: Node2D, texture_path: String = "", custom_color: Color = Color.WHITE) -> void:
	if not is_instance_valid(monster_node):
		return
	var sprite: Sprite2D = monster_node.get_node_or_null("Sprite2D")
	var color_rect: ColorRect = monster_node.get_node_or_null("ColorRect")
	
	if texture_path != "" and FileAccess.file_exists(texture_path):
		var tex := load(texture_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.visible = true
			if color_rect:
				color_rect.visible = false
			return
	
	if color_rect:
		color_rect.visible = true
		if custom_color != Color.WHITE:
			color_rect.color = custom_color

# 3. 드롭 아이템 디자인 래핑 적용
static func wrap_drop_item(item_node: Node2D, texture_path: String = "", item_color: Color = Color.GOLD) -> void:
	if not is_instance_valid(item_node):
		return
	var sprite: Sprite2D = item_node.get_node_or_null("Sprite2D")
	var color_rect: ColorRect = item_node.get_node_or_null("ColorRect")
	
	if texture_path != "" and FileAccess.file_exists(texture_path):
		var tex := load(texture_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.visible = true
			if color_rect:
				color_rect.visible = false
			return
	
	if color_rect:
		color_rect.visible = true
		color_rect.color = item_color

# 4. 보물상자 디자인 래핑 적용
static func wrap_chest(chest_node: Node2D, closed_tex_path: String = "", open_tex_path: String = "") -> void:
	if not is_instance_valid(chest_node):
		return
	var sprite: Sprite2D = chest_node.get_node_or_null("Sprite2D")
	var color_rect: ColorRect = chest_node.get_node_or_null("ColorRect")
	
	if closed_tex_path != "" and FileAccess.file_exists(closed_tex_path):
		var tex := load(closed_tex_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.visible = true
			if color_rect:
				color_rect.visible = false
			return

# 5. 상점 NPC/건물 디자인 래핑 적용
static func wrap_shop(shop_node: Node2D, building_tex_path: String = "", npc_tex_path: String = "") -> void:
	if not is_instance_valid(shop_node):
		return
	var sprite: Sprite2D = shop_node.get_node_or_null("Sprite2D")
	var color_rect: ColorRect = shop_node.get_node_or_null("ColorRect")
	
	if building_tex_path != "" and FileAccess.file_exists(building_tex_path):
		var tex := load(building_tex_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.visible = true
			if color_rect:
				color_rect.visible = false
			return
