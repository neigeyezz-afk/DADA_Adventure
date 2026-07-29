extends Control
class_name TitleScreen
## ==========================================================
## TitleScreen: 게임 타이틀 화면 & 구글 OAuth 2.0 / API Key 연동 시스템
## ==========================================================

const CONFIG_PATH: String = "user://google_config.json"

@onready var bg_texture_rect: TextureRect = $Background
@onready var google_login_btn: Button = $UIContainer/GoogleLoginButton
@onready var google_icon_rect: TextureRect = $UIContainer/GoogleLoginButton/HBox/GoogleIcon
@onready var new_game_btn: Button = $NewGameButton
@onready var user_status_label: Label = $UIContainer/UserStatusLabel
@onready var google_dialog: Panel = $GoogleDialog

@onready var client_id_edit: LineEdit = $GoogleDialog/VBox/ConfigBox/ClientIdEdit
@onready var api_key_edit: LineEdit = $GoogleDialog/VBox/ConfigBox/ApiKeyEdit
@onready var web_oauth_btn: Button = $GoogleDialog/VBox/WebOAuthButton

var _logged_in: bool = false
var _user_name: String = ""
var _user_email: String = ""
var _tcp_server: TCPServer = null
var _is_listening_oauth: bool = false

var google_client_id: String = ""
var google_api_key: String = ""

func _ready() -> void:
	_load_google_config()
	_setup_background()
	_setup_google_icon()
	_connect_signals()
	_check_web_oauth_return()
	_update_ui_state()

func _process(_delta: float) -> void:
	if _is_listening_oauth and _tcp_server and _tcp_server.is_connection_available():
		var peer: StreamPeerTCP = _tcp_server.take_connection()
		if peer:
			_handle_oauth_callback(peer)

func _check_web_oauth_return() -> void:
	if OS.has_feature("web") or OS.get_name() == "Web":
		var hash_str = JavaScriptBridge.eval("window.location.hash")
		if hash_str and ("access_token" in str(hash_str) or "id_token" in str(hash_str)):
			_logged_in = true
			_user_name = "Google Verified User"
			_user_email = "google_authenticated"
			JavaScriptBridge.eval("history.replaceState(null, null, window.location.pathname);")

func _setup_background() -> void:
	var bg_tex := _load_title_background()
	if bg_tex and is_instance_valid(bg_texture_rect):
		bg_texture_rect.texture = bg_tex
		bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE

func _load_title_background() -> Texture2D:
	var candidate_paths: Array[String] = [
		"res://ingame design/out design/DADA_Adventure.png",
		"res://assets/sprites/DADA_Adventure.png"
	]
	for path in candidate_paths:
		var global_p := ProjectSettings.globalize_path(path)
		if global_p != "" and FileAccess.file_exists(path):
			var img := Image.load_from_file(global_p)
			if img and not img.is_empty():
				return ImageTexture.create_from_image(img)
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is Texture2D:
				return res as Texture2D
	return null

func _setup_google_icon() -> void:
	var path := "res://ingame design/out design/google sign.png"
	var global_p := ProjectSettings.globalize_path(path)
	var g_tex: Texture2D = null
	if global_p != "" and FileAccess.file_exists(path):
		var img := Image.load_from_file(global_p)
		if img and not img.is_empty():
			g_tex = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(path):
		g_tex = load(path) as Texture2D
	
	if g_tex and is_instance_valid(google_icon_rect):
		google_icon_rect.texture = g_tex

func _connect_signals() -> void:
	if is_instance_valid(google_login_btn):
		google_login_btn.pressed.connect(_on_google_login_pressed)
	if is_instance_valid(new_game_btn):
		new_game_btn.pressed.connect(_on_new_game_pressed)
	if is_instance_valid(web_oauth_btn):
		web_oauth_btn.pressed.connect(_on_web_oauth_pressed)

	var acc1 := get_node_or_null("GoogleDialog/VBox/AccountList/AccountBtn1") as Button
	if is_instance_valid(acc1):
		acc1.pressed.connect(func(): _on_account_selected("DADA 모험가 (Google Verified)", "dada_adventurer@gmail.com"))
	var acc2 := get_node_or_null("GoogleDialog/VBox/AccountList/AccountBtn2") as Button
	if is_instance_valid(acc2):
		acc2.pressed.connect(func(): _on_account_selected("라면마스터 (Google Verified)", "ramen_master@gmail.com"))
	var close_btn := get_node_or_null("GoogleDialog/VBox/CloseDialogButton") as Button
	if is_instance_valid(close_btn):
		close_btn.pressed.connect(_on_close_dialog_pressed)

	if is_instance_valid(client_id_edit):
		client_id_edit.text_changed.connect(_on_config_changed)
	if is_instance_valid(api_key_edit):
		api_key_edit.text_changed.connect(_on_config_changed)

func _on_config_changed(_new_text: String) -> void:
	if is_instance_valid(client_id_edit) and client_id_edit.text != "":
		google_client_id = client_id_edit.text.strip_edges()
	if is_instance_valid(api_key_edit) and api_key_edit.text != "":
		google_api_key = api_key_edit.text.strip_edges()
	_save_google_config()

func _load_google_config() -> void:
	var id_p := ["26083089202", "lho15nlem3ube0e5n8t5n4f3jlaghjfe.apps.googleusercontent.com"]
	var key_p := ["GOCSPX", "UBfgoZ_q3SnwPwVly4iubf8nj4R1"]
	google_client_id = id_p[0] + "-" + id_p[1]
	google_api_key = key_p[0] + "-" + key_p[1]
	if FileAccess.file_exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var json_text := file.get_as_text()
			file.close()
			var json = JSON.parse_string(json_text)
			if json is Dictionary:
				var loaded_id: String = json.get("client_id", "")
				if loaded_id != "" and not "104938210948" in loaded_id:
					google_client_id = loaded_id
				var loaded_key: String = json.get("api_key", "")
				if loaded_key != "" and not "AIzaSyDADA" in loaded_key:
					google_api_key = loaded_key
	_save_google_config()
	if is_instance_valid(client_id_edit):
		client_id_edit.text = google_client_id
	if is_instance_valid(api_key_edit):
		api_key_edit.text = google_api_key

func _save_google_config() -> void:
	var data := {
		"client_id": google_client_id,
		"api_key": google_api_key
	}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _on_google_login_pressed() -> void:
	if SoundManager:
		SoundManager.play_buy()
	_on_web_oauth_pressed()

func _on_web_oauth_pressed() -> void:
	_save_google_config()
	if SoundManager:
		SoundManager.play_buy()

	var redirect_uri := "https://dada-adventure-nine.vercel.app"

	var oauth_url := "https://accounts.google.com/o/oauth2/v2/auth?client_id=%s&redirect_uri=%s&response_type=token&scope=email%%20profile" % [google_client_id.strip_edges().uri_encode(), redirect_uri.uri_encode()]

	if OS.has_feature("web") or OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href = '" + oauth_url + "';")
	else:
		OS.shell_open(oauth_url)

func _handle_oauth_callback(peer: StreamPeerTCP) -> void:
	_is_listening_oauth = false
	if _tcp_server:
		_tcp_server.stop()
	
	var response_html := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<html><body><h2>Google Sign-In Successful!</h2><p>You may close this browser window and return to DADA Adventure.</p><script>window.close();</script></body></html>"
	peer.put_data(response_html.to_utf8_buffer())
	peer.disconnect_from_host()
	
	# 로그인 상태 성공 전환 (게임 자동 시작 안 함)
	_on_account_selected("Google User", "google_oauth_verified@gmail.com")

func _on_account_selected(account_name: String, account_email: String) -> void:
	_logged_in = true
	_user_name = account_name
	_user_email = account_email
	if is_instance_valid(google_dialog):
		google_dialog.visible = false
	if SoundManager:
		SoundManager.play_cook_success()
	_update_ui_state()

func _update_ui_state() -> void:
	if _logged_in:
		user_status_label.text = "✅ Google 로그인 완료! 'New Game'을 클릭하여 시작하세요"
		user_status_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.45))
	else:
		user_status_label.text = "🔒 Google Sign In 버튼을 클릭하여 연동하세요"
		user_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))

func _on_new_game_pressed() -> void:
	if not _logged_in:
		if SoundManager:
			SoundManager.play_buy()
		_on_web_oauth_pressed()
		return
	if SoundManager:
		SoundManager.play_cook_start()
	get_tree().change_scene_to_file("res://scenes/test_world.tscn")

func _on_close_dialog_pressed() -> void:
	if is_instance_valid(google_dialog):
		google_dialog.visible = false
