extends Node
## ==========================================================
## GameState (오토로드 싱글턴)
## 기획서 3.3 '경제 선순환'과 3.2 '스펙업'의 데이터 허브.
## 골드/소재/장착무기/상점 재산EXP를 전역 보관한다.
## 세이브·로드 시스템(Phase 3)은 여기에 저장/복원 함수만 붙이면 확장된다.
## ==========================================================

signal gold_changed(amount: int)
signal materials_changed(total: int)
signal weapon_changed(index: int)
signal pot_changed(level: int, pot_info: Dictionary)
signal wealth_changed(level: int, exp_value: int)
signal ramen_crafted(count: int)

const SAVE_PATH: String = "user://dada_save.json"

# --- 재화 ---
var gold: int = 0
var materials: int = 3
var ingredient_inventory: Dictionary = {}

# --- 냄비 성장 시스템 (기획서 12. 냄비 성장 시스템) ---
const POTS: Array[Dictionary] = [
	{"level": 1, "name": "양은냄비 (Brass Pot)", "capacity": 10, "cook_speed": 1.0, "price": 0},
	{"level": 3, "name": "코팅냄비 (Coated Pot)", "capacity": 15, "cook_speed": 1.15, "price": 50},
	{"level": 4, "name": "법랑냄비 (Enamel Pot)", "capacity": 20, "cook_speed": 1.3, "price": 100},
	{"level": 5, "name": "스탠냄비 (Stainless Pot)", "capacity": 25, "cook_speed": 1.45, "price": 180},
	{"level": 6, "name": "강화유리냄비 (Glass Pot)", "capacity": 30, "cook_speed": 1.6, "price": 280},
	{"level": 10, "name": "무쇠냄비 (Cast Iron Pot)", "capacity": 40, "cook_speed": 2.0, "price": 450},
]
var pot_index: int = 0

# --- 라면 시스템 ---
var ramen_completed: int = 0
var unlocked_recipes: Array[String] = ["Basic Ramen"]
const RECIPES: Dictionary = {
	"Basic Ramen": {"required_pot_level": 1, "required_materials": 3, "cook_time": 6.0, "description": "순정라면 (Req: Pot Lv1)"},
	"Cheese Ramen": {"required_pot_level": 3, "required_materials": 5, "cook_time": 8.0, "description": "치즈라면 (Req: Pot Lv3)"},
	"Kimchi Ramen": {"required_pot_level": 4, "required_materials": 6, "cook_time": 9.0, "description": "김치라면 (Req: Pot Lv4)"},
	"Seafood Ramen": {"required_pot_level": 5, "required_materials": 7, "cook_time": 10.0, "description": "해물라면 (Req: Pot Lv5)"},
	"Beef Ramen": {"required_pot_level": 6, "required_materials": 8, "cook_time": 11.0, "description": "고기라면 (Req: Pot Lv6)"},
}

# --- 상점(푸르지아) 재산(Wealth) 경험치: 기획서 2.3 단계별 성장 ---
var wealth_level: int = 1
var wealth_exp: int = 0
const WEALTH_EXP_PER_LEVEL: int = 100

# --- 무기 티어 (기획서 3.2: 리치와 데미지가 실제로 커진다) ---
# name / damage / reach(히트박스 길이 px) / price(골드) / color(화이트박스 색)
const WEAPONS: Array[Dictionary] = [
	{"name": "Old Shortsword", "damage": 1, "reach": 30.0, "price": 0, "color": Color(0.55, 0.6, 0.7)},
	{"name": "Steel Longsword", "damage": 2, "reach": 48.0, "price": 40, "color": Color(0.8, 0.86, 0.98)},
	{"name": "Dwarven Greatsword", "damage": 4, "reach": 70.0, "price": 120, "color": Color(1.0, 0.78, 0.2)},
]
var weapon_index: int = 0

const MATERIAL_SELL_PRICE: int = 5    # 소재 1개당 매입가(골드)
const MATERIAL_WEALTH_EXP: int = 10   # 소재 1개 판매 시 상점이 얻는 재산 EXP

func _ready() -> void:
	load_state()

func get_pot() -> Dictionary:
	return POTS[pot_index]

func get_max_capacity() -> int:
	return int(get_pot().get("capacity", 10))

func can_add_material(_material_name: String = "", amount: int = 1) -> bool:
	if pot_growth_paused:
		return true
	return (materials + amount) <= get_max_capacity()

func has_next_pot() -> bool:
	return pot_index + 1 < POTS.size()

func next_pot() -> Dictionary:
	if has_next_pot():
		return POTS[pot_index + 1]
	return {}

func try_upgrade_pot() -> bool:
	if not has_next_pot():
		return false
	var nxt := next_pot()
	var price: int = int(nxt.get("price", 0))
	if gold < price:
		return false
	gold -= price
	pot_index += 1
	gold_changed.emit(gold)
	pot_changed.emit(int(POTS[pot_index]["level"]), POTS[pot_index])
	save_state()
	return true

func get_weapon() -> Dictionary:
	return WEAPONS[weapon_index]

func get_recipe(recipe_name: String) -> Dictionary:
	if RECIPES.has(recipe_name):
		return RECIPES[recipe_name]
	return {}

func has_recipe(recipe_name: String) -> bool:
	return recipe_name in unlocked_recipes

func get_available_recipes() -> Array[String]:
	var names: Array[String] = []
	for recipe_name in RECIPES.keys():
		if has_recipe(recipe_name):
			names.append(recipe_name)
	return names

func get_next_recipe() -> String:
	var ordered: Array[String] = ["Basic Ramen", "Cheese Ramen", "Kimchi Ramen", "Seafood Ramen", "Beef Ramen"]
	for recipe_name in ordered:
		if has_recipe(recipe_name):
			return recipe_name
	return "Basic Ramen"

# 냄비 성장 시스템 일시 중지 플래그 (중지 요청에 따라 true로 설정)
var pot_growth_paused: bool = true

func can_craft_recipe(recipe_name: String) -> bool:
	if not has_recipe(recipe_name):
		return false
	var recipe := get_recipe(recipe_name)
	if recipe.is_empty():
		return false
	if not pot_growth_paused:
		var req_pot_lvl: int = int(recipe.get("required_pot_level", 1))
		var current_pot_lvl: int = int(get_pot().get("level", 1))
		if current_pot_lvl < req_pot_lvl:
			return false
	return materials >= int(recipe.get("required_materials", 0))

func craft_recipe(recipe_name: String) -> bool:
	if not can_craft_recipe(recipe_name):
		return false
	var recipe := get_recipe(recipe_name)
	var required_materials: int = int(recipe.get("required_materials", 0))
	materials -= required_materials
	materials_changed.emit(materials)
	ramen_completed += 1
	if recipe_name == "Basic Ramen" and not has_recipe("Cheese Ramen"):
		unlocked_recipes.append("Cheese Ramen")
	elif recipe_name == "Cheese Ramen" and not has_recipe("Kimchi Ramen"):
		unlocked_recipes.append("Kimchi Ramen")
	elif recipe_name == "Kimchi Ramen" and not has_recipe("Seafood Ramen"):
		unlocked_recipes.append("Seafood Ramen")
	elif recipe_name == "Seafood Ramen" and not has_recipe("Beef Ramen"):
		unlocked_recipes.append("Beef Ramen")
	unlocked_recipes = _unique_strings(unlocked_recipes)
	ramen_crafted.emit(ramen_completed)
	save_state()
	return true

func has_next_weapon() -> bool:
	return weapon_index + 1 < WEAPONS.size()

func next_weapon() -> Dictionary:
	if has_next_weapon():
		return WEAPONS[weapon_index + 1]
	return {}

func save_state() -> void:
	var data: Dictionary = {
		"gold": gold,
		"materials": materials,
		"ingredient_inventory": ingredient_inventory,
		"weapon_index": weapon_index,
		"pot_index": pot_index,
		"wealth_level": wealth_level,
		"wealth_exp": wealth_exp,
		"ramen_completed": ramen_completed,
		"unlocked_recipes": unlocked_recipes,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		gold = int(parsed.get("gold", gold))
		materials = int(parsed.get("materials", materials))
		ingredient_inventory = parsed.get("ingredient_inventory", ingredient_inventory)
		weapon_index = int(parsed.get("weapon_index", weapon_index))
		pot_index = int(parsed.get("pot_index", pot_index))
		wealth_level = int(parsed.get("wealth_level", wealth_level))
		wealth_exp = int(parsed.get("wealth_exp", wealth_exp))
		ramen_completed = int(parsed.get("ramen_completed", ramen_completed))
		var loaded_recipes: Variant = parsed.get("unlocked_recipes", unlocked_recipes)
		if loaded_recipes is Array:
			unlocked_recipes = []
			for item in loaded_recipes:
				if typeof(item) == TYPE_STRING:
					unlocked_recipes.append(item)
				else:
					unlocked_recipes.append(str(item))
		else:
			unlocked_recipes = Array(unlocked_recipes)
		if unlocked_recipes.is_empty():
			unlocked_recipes = ["Basic Ramen"]
		gold_changed.emit(gold)
		materials_changed.emit(materials)
		weapon_changed.emit(weapon_index)
		pot_changed.emit(int(POTS[pot_index]["level"]), POTS[pot_index])
		wealth_changed.emit(wealth_level, wealth_exp)
		ramen_crafted.emit(ramen_completed)

# 소재 전량 판매 -> 골드 획득 + 상점 재산 EXP 적립 (기획서 3.3)
func sell_all_materials() -> int:
	if materials <= 0:
		return 0
	var earned: int = materials * MATERIAL_SELL_PRICE
	gold += earned
	_add_wealth_exp(materials * MATERIAL_WEALTH_EXP)
	materials = 0
	ingredient_inventory.clear()
	materials_changed.emit(materials)
	gold_changed.emit(gold)
	save_state()
	return earned

# 다음 등급 무기 구매 시도 -> 성공 시 즉시 스펙업 (기획서 3.2)
func try_buy_next_weapon() -> bool:
	if not has_next_weapon():
		return false
	var price: int = WEAPONS[weapon_index + 1]["price"]
	if gold < price:
		return false
	gold -= price
	weapon_index += 1
	gold_changed.emit(gold)
	weapon_changed.emit(weapon_index)
	save_state()
	return true

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	save_state()

func add_material(material_name: String, amount: int = 1) -> bool:
	if not can_add_material(material_name, amount):
		return false
	materials += amount
	if ingredient_inventory.has(material_name):
		ingredient_inventory[material_name] += amount
	else:
		ingredient_inventory[material_name] = amount
	materials_changed.emit(materials)
	save_state()
	return true

func add_materials(amount: int) -> bool:
	return add_material("water", amount)

func get_material_count(material_name: String) -> int:
	return int(ingredient_inventory.get(material_name, 0))

func _add_wealth_exp(amount: int) -> void:
	wealth_exp += amount
	while wealth_exp >= WEALTH_EXP_PER_LEVEL:
		wealth_exp -= WEALTH_EXP_PER_LEVEL
		wealth_level += 1
	wealth_changed.emit(wealth_level, wealth_exp)

func _unique_strings(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		if value not in unique:
			unique.append(value)
	return unique
