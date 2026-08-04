extends CanvasLayer
## 화면 상단 정보 표시 + 상점/인벤토리 패널 + 일시정지(P)/레시피북(R)/인벤토리(Q) 단축키

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
@onready var upgrade_pot_button: Button = get_node_or_null("ShopPanel/UpgradePotButton")
@onready var cook_button: Button = $ShopPanel/CookButton
@onready var shop_close_button: Button = get_node_or_null("ShopPanel/CloseButton")

@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var recipe_book_button: Button = get_node_or_null("Top/RecipeBookButton")
@onready var recipe_book_panel: Panel = get_node_or_null("RecipeBookPanel")
@onready var recipe_book_content: RichTextLabel = get_node_or_null("RecipeBookPanel/Content")
@onready var recipe_book_close: Button = get_node_or_null("RecipeBookPanel/CloseButton")
@onready var pause_overlay: ColorRect = get_node_or_null("PauseOverlay")

@onready var stage_banner_panel: Panel = get_node_or_null("StageBannerPanel")
@onready var stage_title_label: Label = get_node_or_null("StageBannerPanel/TitleLabel")
@onready var objective_label: Label = get_node_or_null("Top/ObjectiveLabel")
@onready var stage_clear_panel: Panel = get_node_or_null("StageClearPanel")

var _cook_active: bool = false
var _cook_recipe_name: String = ""
var _cook_time_left: float = 0.0
var _cook_total_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	shop_panel.visible = false
	if is_instance_valid(recipe_book_panel):
		recipe_book_panel.visible = false
	if is_instance_valid(stage_clear_panel):
		stage_clear_panel.visible = false
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = false

	GameState.gold_changed.connect(func(_v: int) -> void: _refresh())
	GameState.materials_changed.connect(func(_v: int) -> void: _refresh())
	GameState.weapon_changed.connect(func(_v: int) -> void: _refresh())
	GameState.pot_changed.connect(func(_lvl: int, _info: Dictionary) -> void: _refresh())
	GameState.ramen_crafted.connect(func(_v: int) -> void: _refresh())

	sell_button.pressed.connect(_on_sell)
	buy_button.pressed.connect(_on_buy)
	if is_instance_valid(upgrade_pot_button):
		upgrade_pot_button.pressed.connect(_on_upgrade_pot)
	cook_button.pressed.connect(_on_cook)
	if is_instance_valid(shop_close_button):
		shop_close_button.pressed.connect(close_shop)

	if is_instance_valid(recipe_book_button):
		recipe_book_button.pressed.connect(toggle_recipe_book)
	if is_instance_valid(recipe_book_close):
		recipe_book_close.pressed.connect(close_recipe_book)

	_refresh()
	_play_stage_intro("STAGE 1: 슬라임 초원 (Slime Meadow)")
	call_deferred("_connect_player")
	call_deferred("_connect_timer")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k_event := event as InputEventKey
		var key: Key = k_event.keycode
		if key == KEY_P:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif key == KEY_R:
			toggle_recipe_book()
			get_viewport().set_input_as_handled()
		elif key == KEY_Q:
			toggle_inventory()
			get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var is_p := not get_tree().paused
	get_tree().paused = is_p
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = is_p

func toggle_inventory() -> void:
	shop_panel.visible = not shop_panel.visible
	if shop_panel.visible:
		_refresh_shop()

func _play_stage_intro(title: String) -> void:
	if is_instance_valid(stage_banner_panel) and is_instance_valid(stage_title_label):
		stage_title_label.text = title
		stage_banner_panel.visible = true
		stage_banner_panel.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(stage_banner_panel, "modulate:a", 0.0, 1.2)
		tween.tween_callback(func(): stage_banner_panel.visible = false)

func _process(delta: float) -> void:
	if _cook_active and not get_tree().paused:
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
	mat_label.text = "Materials  %d/%d (%s)" % [GameState.materials, GameState.get_max_capacity(), GameState.get_pot()["name"]]
	weapon_label.text = "Weapon  %s" % GameState.get_weapon()["name"]
	if shop_panel.visible:
		_refresh_shop()

func _refresh_shop() -> void:
	shop_info.text = "Gold %d | Materials %d/%d (%s)\nSell Price: 1 = %d Gold" % [
		GameState.gold, GameState.materials, GameState.get_max_capacity(), GameState.get_pot()["name"], GameState.MATERIAL_SELL_PRICE
	]
	shop_weapon_info.text = "Weapon: %s | Pot: %s" % [GameState.get_weapon()["name"], GameState.get_pot()["name"]]
	sell_button.disabled = GameState.materials <= 0
	if GameState.has_next_weapon():
		var nxt := GameState.next_weapon()
		buy_button.text = "Buy Next Weapon: %s (%d G)" % [nxt["name"], nxt["price"]]
		buy_button.disabled = GameState.gold < int(nxt["price"])
	else:
		buy_button.text = "Max Weapon Owned"
		buy_button.disabled = true

	if is_instance_valid(upgrade_pot_button):
		upgrade_pot_button.visible = not GameState.pot_growth_paused
		if not GameState.pot_growth_paused:
			if GameState.has_next_pot():
				var nxt_pot := GameState.next_pot()
				upgrade_pot_button.text = "Upgrade Pot: %s (%d G)" % [nxt_pot["name"], nxt_pot["price"]]
				upgrade_pot_button.disabled = GameState.gold < int(nxt_pot["price"])
			else:
				upgrade_pot_button.text = "Max Pot Level Reached"
				upgrade_pot_button.disabled = true

	var next_recipe := GameState.get_next_recipe()
	var recipe_data := GameState.get_recipe(next_recipe)
	var req_pot_lvl: int = int(recipe_data.get("required_pot_level", 1))
	var required_materials: int = int(recipe_data.get("required_materials", 0))
	var current_pot_lvl: int = int(GameState.get_pot().get("level", 1))

	if _cook_active:
		cook_button.text = "Finish Cooking"
		cook_button.disabled = false
		_set_recipe_status("Cooking %s - %.1fs" % [_cook_recipe_name, _cook_time_left], Color(1.0, 0.8, 0.2))
	else:
		cook_button.text = "Cook %s (%d mats)" % [next_recipe, required_materials]
		if not GameState.pot_growth_paused and current_pot_lvl < req_pot_lvl:
			cook_button.disabled = true
			_set_recipe_status("Needs %s (Pot Lv%d)\nRamen Cooked: %d" % [recipe_data.get("description", next_recipe), req_pot_lvl, GameState.ramen_completed], Color(1.0, 0.45, 0.45))
		else:
			cook_button.disabled = not GameState.can_craft_recipe(next_recipe)
			_set_recipe_status("Next: %s\nRamen Cooked: %d | Unlocked: %d" % [next_recipe, GameState.ramen_completed, GameState.get_available_recipes().size()], Color(0.25, 1.0, 0.45))

func _set_recipe_status(text: String, color: Color) -> void:
	recipe_info.text = text
	recipe_info.add_theme_color_override("font_color", color)

func toggle_shop() -> void:
	toggle_inventory()

func open_shop() -> void:
	shop_panel.visible = true
	_refresh_shop()

func close_shop() -> void:
	shop_panel.visible = false

func _on_sell() -> void:
	var earned := GameState.sell_all_materials()
	if earned > 0 and SoundManager:
		SoundManager.play_sell()
	_refresh_shop()

func _on_buy() -> void:
	if GameState.try_buy_next_weapon() and SoundManager:
		SoundManager.play_buy()
	_refresh_shop()

func _on_upgrade_pot() -> void:
	if GameState.try_upgrade_pot() and SoundManager:
		SoundManager.play_buy()
	_refresh_shop()

func _on_cook() -> void:
	if _cook_active:
		_finish_cooking(true)
		return
	var recipe := GameState.get_next_recipe()
	if not GameState.can_craft_recipe(recipe):
		recipe_info.text = "Cannot cook %s (Check pot level or materials)." % recipe
		return
	_cook_active = true
	_cook_recipe_name = recipe
	if SoundManager:
		SoundManager.play_cook_start()
	var recipe_data := GameState.get_recipe(recipe)
	var base_time: float = float(recipe_data.get("cook_time", 6.0))
	var pot_speed: float = float(GameState.get_pot().get("cook_speed", 1.0))
	_cook_total_time = base_time / pot_speed
	_cook_time_left = _cook_total_time
	_set_recipe_status("Cooking %s - %.1fs" % [recipe, _cook_time_left], Color(1.0, 0.8, 0.2))
	_refresh_shop()

func _finish_cooking(success: bool) -> void:
	if not _cook_active:
		return
	_cook_active = false
	if success:
		if GameState.craft_recipe(_cook_recipe_name):
			if SoundManager:
				SoundManager.play_cook_success()
			_set_recipe_status("Success! %s cooked." % _cook_recipe_name, Color(0.3, 1.0, 0.55))
		else:
			_set_recipe_status("Cooking failed for %s." % _cook_recipe_name, Color(1.0, 0.35, 0.35))
	else:
		_set_recipe_status("Cooking failed! The pot boiled over.", Color(1.0, 0.35, 0.35))
	_refresh_shop()

func toggle_recipe_book() -> void:
	if not is_instance_valid(recipe_book_panel):
		return
	recipe_book_panel.visible = not recipe_book_panel.visible
	if recipe_book_panel.visible:
		_refresh_recipe_book()

func close_recipe_book() -> void:
	if is_instance_valid(recipe_book_panel):
		recipe_book_panel.visible = false

func _refresh_recipe_book() -> void:
	if not is_instance_valid(recipe_book_content):
		return
	var text: String = "[b]Recipe List (Shortcut: R):[/b]\n\n"
	for recipe_name in GameState.RECIPES.keys():
		var data: Dictionary = GameState.RECIPES[recipe_name]
		var unlocked := GameState.has_recipe(recipe_name)
		var status_str := "[color=#40ff70]UNLOCKED[/color]" if unlocked else "[color=#ff5050]LOCKED[/color]"
		var desc: String = String(data.get("description", recipe_name))
		var req_mats: int = int(data.get("required_materials", 0))
		text += "• [b]%s[/b] [%s]\n  - %s (Required Materials: %d)\n\n" % [recipe_name, status_str, desc, req_mats]
	recipe_book_content.text = text
