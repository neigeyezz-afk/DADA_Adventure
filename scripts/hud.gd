extends CanvasLayer
## 화면 상단 정보 표시 + 상점 패널. group "hud" 로 등록되어 Shop이 호출한다.

@onready var hp_label: Label = $Top/HP
@onready var gold_label: Label = $Top/Gold
@onready var mat_label: Label = $Top/Materials
@onready var weapon_label: Label = $Top/Weapon
@onready var timer_label: Label = $TimerLabel

@onready var shop_panel: Panel = $ShopPanel
@onready var shop_info: Label = $ShopPanel/Info
@onready var shop_weapon_info: Label = $ShopPanel/WeaponInfo
@onready var recipe_info: Label = $ShopPanel/RecipeInfo
@onready var sell_button: Button = $ShopPanel/SellButton
@onready var buy_button: Button = $ShopPanel/BuyButton
@onready var cook_button: Button = $ShopPanel/CookButton

@onready var game_over_panel: ColorRect = $GameOverPanel

var _cook_active: bool = false
var _cook_recipe_name: String = ""
var _cook_time_left: float = 0.0
var _cook_total_time: float = 0.0

func _ready() -> void:
	add_to_group("hud")
	shop_panel.visible = false
	GameState.gold_changed.connect(func(_v: int) -> void: _refresh())
	GameState.materials_changed.connect(func(_v: int) -> void: _refresh())
	GameState.weapon_changed.connect(func(_v: int) -> void: _refresh())
	GameState.ramen_crafted.connect(func(_v: int) -> void: _refresh())
	sell_button.pressed.connect(_on_sell)
	buy_button.pressed.connect(_on_buy)
	cook_button.pressed.connect(_on_cook)
	_refresh()
	# 플레이어/타이머가 그룹에 등록된 뒤(다음 프레임) 시그널 연결
	call_deferred("_connect_player")
	call_deferred("_connect_timer")

func _process(delta: float) -> void:
	if _cook_active:
		_cook_time_left = maxf(0.0, _cook_time_left - delta)
		recipe_info.text = "Cooking %s - %.1fs" % [_cook_recipe_name, _cook_time_left]
		if _cook_time_left <= 0.0:
			_finish_cooking(false)

func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerDADA
	if player:
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)

func _on_health_changed(current: int, maximum: int) -> void:
	hp_label.text = "HP  %d / %d" % [current, maximum]

func _connect_timer() -> void:
	var timer := get_tree().get_first_node_in_group("stage_timer") as StageTimer
	if timer:
		timer.time_updated.connect(_on_time_updated)
		timer.game_over.connect(_on_game_over)
		timer.stage_cleared.connect(_on_stage_cleared)
		_on_time_updated(timer.get_remaining())

func _on_time_updated(remaining: float) -> void:
	@warning_ignore("integer_division")
	var m := int(remaining) / 60
	var s := int(remaining) % 60
	timer_label.text = "%d:%02d" % [m, s]
	var digital_green := Color(0.25, 1, 0.45, 1)
	var digital_red := Color(1, 0.25, 0.25, 1)
	timer_label.add_theme_color_override("font_color", digital_red if remaining <= 30.0 else digital_green)

func _on_game_over() -> void:
	game_over_panel.visible = true

func _on_stage_cleared() -> void:
	timer_label.text = "Stage Clear!"
	timer_label.modulate = Color(0.4, 1.0, 0.4)

func _refresh() -> void:
	gold_label.text = "Gold  %d" % GameState.gold
	mat_label.text = "Mana Stone  %d" % GameState.materials
	weapon_label.text = "Weapon  %s" % GameState.get_weapon()["name"]
	if shop_panel.visible:
		_refresh_shop()

func _refresh_shop() -> void:
	shop_info.text = "Gold %d   |   Materials %d\nSell Price: 1 = %d Gold" % [
		GameState.gold, GameState.materials, GameState.MATERIAL_SELL_PRICE
	]
	shop_weapon_info.text = "Weapon: %s" % GameState.get_weapon()["name"]
	sell_button.disabled = GameState.materials <= 0
	if GameState.has_next_weapon():
		var nxt := GameState.next_weapon()
		buy_button.text = "Buy Next Weapon: %s (%d G)" % [nxt["name"], nxt["price"]]
		buy_button.disabled = GameState.gold < int(nxt["price"])
	else:
		buy_button.text = "Max Weapon Owned"
		buy_button.disabled = true

	var next_recipe := GameState.get_next_recipe()
	var recipe_data := GameState.get_recipe(next_recipe)
	var required_materials: int = int(recipe_data.get("required_materials", 0))
	if _cook_active:
		cook_button.text = "Finish Cooking"
		cook_button.disabled = false
		_set_recipe_status("Cooking %s - %.1fs" % [_cook_recipe_name, _cook_time_left], Color(1.0, 0.8, 0.2))
	else:
		cook_button.text = "Cook %s (%d mats)" % [next_recipe, required_materials]
		cook_button.disabled = not GameState.can_craft_recipe(next_recipe)
		_set_recipe_status("Ramen Cooked: %d\nUnlocked: %d" % [GameState.ramen_completed, GameState.get_available_recipes().size()], Color(0.25, 1.0, 0.45))

func _set_recipe_status(text: String, color: Color) -> void:
	recipe_info.text = text
	recipe_info.add_theme_color_override("font_color", color)

func toggle_shop() -> void:
	shop_panel.visible = not shop_panel.visible
	if shop_panel.visible:
		_refresh_shop()

func open_shop() -> void:
	shop_panel.visible = true
	_refresh_shop()

func close_shop() -> void:
	shop_panel.visible = false

func _on_sell() -> void:
	GameState.sell_all_materials()
	_refresh_shop()

func _on_buy() -> void:
	GameState.try_buy_next_weapon()
	_refresh_shop()

func _on_cook() -> void:
	if _cook_active:
		_finish_cooking(true)
		return
	var recipe := GameState.get_next_recipe()
	if not GameState.can_craft_recipe(recipe):
		recipe_info.text = "Not enough materials to cook %s." % recipe
		return
	_cook_active = true
	_cook_recipe_name = recipe
	var recipe_data := GameState.get_recipe(recipe)
	_cook_total_time = float(recipe_data.get("cook_time", 6.0))
	_cook_time_left = _cook_total_time
	_set_recipe_status("Cooking %s - %.1fs" % [recipe, _cook_time_left], Color(1.0, 0.8, 0.2))
	_refresh_shop()

func _finish_cooking(success: bool) -> void:
	if not _cook_active:
		return
	_cook_active = false
	if success:
		if GameState.craft_recipe(_cook_recipe_name):
			_set_recipe_status("Success! %s cooked." % _cook_recipe_name, Color(0.3, 1.0, 0.55))
		else:
			_set_recipe_status("Not enough materials to cook %s." % _cook_recipe_name, Color(1.0, 0.35, 0.35))
	else:
		_set_recipe_status("Cooking failed! The pot boiled over.", Color(1.0, 0.35, 0.35))
	_refresh_shop()
