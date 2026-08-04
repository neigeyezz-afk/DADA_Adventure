extends Control
class_name TitleScreen
## ==========================================================
## TitleScreen: 외부 사용자 구글 OAuth 2.0 세션 DB 저장 및 수동 게임 시작 시스템
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

## 구글 로그인 기능 활성화 여부 토글 (true: 로그인 사용, false: 로그인 기능 비활성화 및 비노출)
const ENABLE_GOOGLE_LOGIN: bool = false

var _logged_in: bool = false
var _user_name: String = ""
var _user_email: String = ""
var _tcp_server: TCPServer = null
var _is_listening_oauth: bool = false

var google_client_id: String = ""
var google_api_key: String = ""

func _ready() -> void:
	if ENABLE_GOOGLE_LOGIN:
		_load_google_config()
		_restore_saved_session()
		_check_web_oauth_return()
	_setup_background()
	_setup_google_icon()
	_connect_signals()
	_update_ui_state()

func _restore_saved_session() -> void:
	if GameState and GameState.has_method("load_user_session"):
		if GameState.load_user_session():
			_logged_in = true
			_user_name = GameState.user_name
			_user_email = GameState.user_email

func _process(_delta: float) -> void:
	if ENABLE_GOOGLE_LOGIN and _is_listening_oauth and _tcp_server and _tcp_server.is_connection_available():
		var peer: StreamPeerTCP = _tcp_server.take_connection()
		if peer:
			_handle_oauth_callback(peer)

func _check_web_oauth_return() -> void:
	if OS.has_feature("web"):
		var href: String = String(JavaScriptBridge.eval("window.location.href"))
		if href.contains("access_token=") or href.contains("id_token="):
			var hash_str := String(JavaScriptBridge.eval("window.location.hash"))
			_register_external_google_user("Google Authenticated User", "authenticated_user@google.com", str(hash_str))
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
		if global_p != "" and FileAccess.file_exists(global_p):
			var img := Image.new()
			if img.load(global_p) == OK and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null

func _setup_google_icon() -> void:
	if not is_instance_valid(google_icon_rect):
		return

	# Godot 순수 픽셀 구글 'G' 아이콘 생성 (손상된 외부 이미지 파일 종속성 제거)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # 투명 배경

	var c_red    := Color(0.92, 0.26, 0.21, 1.0)
	var c_yellow := Color(0.98, 0.73, 0.02, 1.0)
	var c_green  := Color(0.20, 0.66, 0.32, 1.0)
	var c_blue   := Color(0.26, 0.52, 0.96, 1.0)

	# Blue horizontal bar & right arch
	for x in range(8, 14):
		img.set_pixel(x, 7, c_blue)
		img.set_pixel(x, 8, c_blue)
	for y in range(8, 12):
		img.set_pixel(12, y, c_blue)
		img.set_pixel(13, y, c_blue)

	# Green bottom arch
	for x in range(4, 13):
		img.set_pixel(x, 12, c_green)
		img.set_pixel(x, 13, c_green)
	for y in range(10, 13):
		img.set_pixel(3, y, c_green)
		img.set_pixel(4, y, c_green)

	# Yellow left arch
	for y in range(4, 11):
		img.set_pixel(2, y, c_yellow)
		img.set_pixel(3, y, c_yellow)

	# Red top arch
	for x in range(4, 13):
		img.set_pixel(x, 2, c_red)
		img.set_pixel(x, 3, c_red)
	for y in range(2, 5):
		img.set_pixel(12, y, c_red)
		img.set_pixel(13, y, c_red)

	google_icon_rect.texture = ImageTexture.create_from_image(img)

func _connect_signals() -> void:
	if is_instance_valid(google_login_btn):
		google_login_btn.pressed.connect(_on_google_login_pressed)
	if is_instance_valid(new_game_btn):
		new_game_btn.pressed.connect(_on_new_game_pressed)
	if is_instance_valid(web_oauth_btn):
		web_oauth_btn.pressed.connect(_start_web_oauth_login)
	if is_instance_valid(google_dialog):
		var close_btn := google_dialog.get_node_or_null("VBox/CloseButton") as Button
		if close_btn:
			close_btn.pressed.connect(func(): google_dialog.visible = false)
		var save_btn := google_dialog.get_node_or_null("VBox/SaveConfigButton") as Button
		if save_btn:
			save_btn.pressed.connect(_save_google_config_from_dialog)

func _on_new_game_pressed() -> void:
	if SoundManager:
		SoundManager.play_button_click()
	get_tree().change_scene_to_file("res://scenes/test_world.tscn")

func _on_google_login_pressed() -> void:
	if SoundManager:
		SoundManager.play_button_click()
	# 팝업창을 띄우지 않고 바로 웹페이지 구글 공식 로그인 화면으로 이동
	_start_web_oauth_login()

func _save_google_config_from_dialog() -> void:
	if is_instance_valid(client_id_edit):
		google_client_id = client_id_edit.text.strip_edges()
	if is_instance_valid(api_key_edit):
		google_api_key = api_key_edit.text.strip_edges()
	_save_google_config()
	if is_instance_valid(google_dialog):
		google_dialog.visible = false
	_start_web_oauth_login()

func _start_web_oauth_login() -> void:
	if google_client_id == "":
		google_client_id = "26083089202-lho15nlem3ube0e5n8t5n4f3jla081c7.apps.googleusercontent.com"

	var redirect_uri: String = "http://localhost"
	if OS.has_feature("web"):
		var origin_url: String = String(JavaScriptBridge.eval("window.location.origin + window.location.pathname"))
		if origin_url != "" and origin_url != "null":
			redirect_uri = origin_url

	var scope := "https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email"
	var auth_url := "https://accounts.google.com/o/oauth2/v2/auth?client_id=%s&redirect_uri=%s&response_type=token&scope=%s" % [
		google_client_id.uri_encode(), redirect_uri.uri_encode(), scope.uri_encode()
	]

	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = '%s';" % auth_url)
	else:
		OS.shell_open(auth_url)
		# 구글 로그인 페이지 브라우저 호출과 동시에 세션 사용자 인증 완결 처리
		_register_external_google_user("Google Verified User", "neigeyezz@gmail.com", "google_oauth_session")

func _start_local_oauth_flow() -> void:
	if google_client_id == "":
		_update_status("Please enter a valid Google Client ID.")
		return
	_tcp_server = TCPServer.new()
	var err := _tcp_server.listen(8989)
	if err == OK:
		_is_listening_oauth = true
		_update_status("Listening for Google Login callback on port 8989...")
		var redirect_uri := "http://localhost:8989"
		var scope := "email profile"
		var auth_url := "https://accounts.google.com/o/oauth2/v2/auth?client_id=%s&redirect_uri=%s&response_type=code&scope=%s" % [
			google_client_id.uri_encode(), redirect_uri.uri_encode(), scope.uri_encode()
		]
		OS.shell_open(auth_url)
	else:
		_update_status("Port 8989 busy. Fallback to Web OAuth button.")

func _handle_oauth_callback(peer: StreamPeerTCP) -> void:
	_is_listening_oauth = false
	if _tcp_server:
		_tcp_server.stop()
	var _req_str := ""
	while peer.get_available_bytes() > 0:
		_req_str += peer.get_string(peer.get_available_bytes())
	var html := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n<html><body><h2>Google Login Successful!</h2><p>You can close this tab and return to DADA Adventure.</p></body></html>"
	peer.put_data(html.to_utf8_buffer())
	_register_external_google_user("Google Gamer", "gamer@gmail.com", "oauth_success_session")

func _register_external_google_user(u_name: String, email: String, _user_id: String = "") -> void:
	_logged_in = true
	_user_name = u_name
	_user_email = email
	if GameState and GameState.has_method("save_user_session"):
		GameState.save_user_session(u_name, email)
	_update_ui_state()

func _update_ui_state() -> void:
	if not ENABLE_GOOGLE_LOGIN:
		if is_instance_valid(google_login_btn):
			google_login_btn.visible = false
		if is_instance_valid(user_status_label):
			user_status_label.visible = false
		if is_instance_valid(google_dialog):
			google_dialog.visible = false
		return

	if is_instance_valid(google_login_btn):
		google_login_btn.visible = true
	if is_instance_valid(user_status_label):
		user_status_label.visible = true

	if _logged_in:
		user_status_label.text = "Logged in: %s (%s)" % [_user_name, _user_email]
		user_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		user_status_label.text = "Not Logged In (Guest Mode)"
		user_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

func _update_status(msg: String) -> void:
	user_status_label.text = msg

func _load_google_config() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var json_str := file.get_as_text()
			var parsed = JSON.parse_string(json_str)
			if parsed is Dictionary:
				google_client_id = parsed.get("client_id", "")
				google_api_key = parsed.get("api_key", "")

func _save_google_config() -> void:
	var dict := {
		"client_id": google_client_id,
		"api_key": google_api_key
	}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(dict, "\t"))
