extends Node
## ==========================================================
## SoundManager (오토로드 싱글턴)
## 절차적 PCM 샘플 생성 기반 동적 SFX 재생 시스템
## ==========================================================

var _audio_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
const MAX_PLAYERS: int = 8
var _sound_cache: Dictionary = {}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_audio_players.append(player)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -14.0
	add_child(_bgm_player)
	_start_bgm()

func _start_bgm() -> void:
	var bgm_stream := _generate_bgm()
	if bgm_stream:
		_bgm_player.stream = bgm_stream
		_bgm_player.play()

func _get_available_player() -> AudioStreamPlayer:
	for player in _audio_players:
		if not player.playing:
			return player
	return _audio_players[0]

func play_sound(sfx_type: String) -> void:
	if not _sound_cache.has(sfx_type):
		var stream := _generate_sfx(sfx_type)
		if stream:
			_sound_cache[sfx_type] = stream
	if _sound_cache.has(sfx_type):
		var player := _get_available_player()
		player.stream = _sound_cache[sfx_type]
		player.play()

# 편리한 헬퍼 메소드들
func play_jump() -> void: play_sound("jump")
func play_attack() -> void: play_sound("attack")
func play_hit() -> void: play_sound("hit")
func play_pickup() -> void: play_sound("pickup")
func play_sell() -> void: play_sound("sell")
func play_buy() -> void: play_sound("buy")
func play_cook_start() -> void: play_sound("cook_start")
func play_cook_success() -> void: play_sound("cook_success")
func play_chest_open() -> void: play_sound("chest_open")

func _generate_sfx(sfx_type: String) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var sample_count: int = 0
	var bytes := PackedByteArray()
	
	match sfx_type:
		"jump":
			# 점프: 150Hz -> 450Hz 도약 (0.12초)
			sample_count = int(mix_rate * 0.12)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var t: float = float(i) / mix_rate
				var progress: float = float(i) / sample_count
				var freq: float = lerp(180.0, 520.0, progress)
				var phase: float = t * freq * TAU
				var sample: float = sin(phase) * (1.0 - progress * 0.7)
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		"attack":
			# 휘두르기/공격: 짧은 슬래시 노이즈 + 피치 강하 (0.08초)
			sample_count = int(mix_rate * 0.08)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var progress: float = float(i) / sample_count
				var env: float = (1.0 - progress) * (1.0 - progress)
				var noise: float = randf_range(-1.0, 1.0)
				var wave: float = sin(float(i) * 0.3)
				var sample: float = lerp(wave, noise, 0.6) * env
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		"hit":
			# 피격/타격: 둔탁한 저음 펀치 (0.15초)
			sample_count = int(mix_rate * 0.15)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var t: float = float(i) / mix_rate
				var progress: float = float(i) / sample_count
				var freq: float = lerp(140.0, 35.0, progress)
				var env: float = exp(-progress * 5.0)
				var noise: float = randf_range(-0.5, 0.5) * (1.0 - progress)
				var sq: float = 1.0 if sin(t * freq * TAU) > 0.0 else -1.0
				var sample: float = (sq * 0.6 + noise * 0.4) * env
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		"pickup":
			# 아이템 획득: 맑은 2음 찰랑임 (E5 -> B5, 0.1초)
			sample_count = int(mix_rate * 0.12)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var t: float = float(i) / mix_rate
				var progress: float = float(i) / sample_count
				var freq: float = 659.25 if progress < 0.5 else 987.77 # E5 -> B5
				var env: float = exp(-fmod(progress * 2.0, 1.0) * 3.0)
				var sample: float = sin(t * freq * TAU) * env
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		"sell":
			# 판매: 찰랑이는 동전 소리 (0.14초)
			sample_count = int(mix_rate * 0.14)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var t: float = float(i) / mix_rate
				var progress: float = float(i) / sample_count
				var freq: float = 987.77 if progress < 0.5 else 1318.5 # B5 -> E6
				var env: float = exp(-fmod(progress * 2.0, 1.0) * 4.0)
				var sample: float = (sin(t * freq * TAU) + sin(t * freq * 1.5 * TAU) * 0.3) * env
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		"buy":
			# 구매: 밝은 3음 아르페지오 (C5 -> E5 -> G5, 0.18초)
			sample_count = int(mix_rate * 0.18)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var t: float = float(i) / mix_rate
				var progress: float = float(i) / sample_count
				var freq: float = 523.25
				if progress > 0.66: freq = 783.99
				elif progress > 0.33: freq = 659.25
				var env: float = exp(-fmod(progress * 3.0, 1.0) * 3.5)
				var sample: float = sin(t * freq * TAU) * env
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		"cook_start":
			# 조리 시작: 보글보글 거품 소리 (0.25초)
			sample_count = int(mix_rate * 0.25)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var t: float = float(i) / mix_rate
				var progress: float = float(i) / sample_count
				var bubble: float = sin(t * (300.0 + sin(t * 40.0) * 150.0) * TAU)
				var env: float = sin(progress * PI)
				var sample: float = bubble * env * 0.8
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		"cook_success":
			# 조리 완료/성공: 경쾌한 라면 완공 효과음 (C5 -> G5 -> C6, 0.3초)
			sample_count = int(mix_rate * 0.3)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var t: float = float(i) / mix_rate
				var progress: float = float(i) / sample_count
				var freq: float = 523.25
				if progress > 0.66: freq = 1046.5 # C6
				elif progress > 0.33: freq = 783.99 # G5
				var env: float = exp(-fmod(progress * 3.0, 1.0) * 2.5)
				var sample: float = (sin(t * freq * TAU) + sin(t * freq * 0.5 * TAU) * 0.3) * env
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		"chest_open":
			# 보물상자 개봉: 팬파레 상승음 (0.35초)
			sample_count = int(mix_rate * 0.35)
			bytes.resize(sample_count)
			for i in range(sample_count):
				var t: float = float(i) / mix_rate
				var progress: float = float(i) / sample_count
				var freq: float = lerp(440.0, 880.0, progress)
				var env: float = sin(progress * PI)
				var sq: float = 1.0 if sin(t * freq * TAU) > 0.0 else -1.0
				var sample: float = sq * env * 0.7
				bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

		_:
			return null

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = mix_rate
	stream.data = bytes
	return stream

func _generate_bgm() -> AudioStreamWAV:
	# 모험 분위기의 레트로 펜타토닉 멜로디 루프 BGM (약 4초)
	var mix_rate: int = 22050
	var duration: float = 4.0
	var sample_count: int = int(mix_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count)

	# C4, E4, G4, A4, C5, D5 멜로디 시퀀스 (8 비트 음계)
	var melody_notes: Array[float] = [261.63, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25, 523.25]
	var bass_notes: Array[float] = [130.81, 164.81, 196.00, 146.83] # C3, E3, G3, D3

	for i in range(sample_count):
		var t: float = float(i) / mix_rate
		var beat: float = (t / duration) * 8.0 # 8개 음표 구간
		var note_idx: int = int(beat) % melody_notes.size()
		var bass_idx: int = int(beat / 2.0) % bass_notes.size()

		var note_freq: float = melody_notes[note_idx]
		var bass_freq: float = bass_notes[bass_idx]

		var note_env: float = exp(-fmod(beat, 1.0) * 2.5)
		var bass_env: float = exp(-fmod(beat / 2.0, 1.0) * 1.5)

		var lead: float = (1.0 if sin(t * note_freq * TAU) > 0.0 else -1.0) * note_env * 0.25
		var bass: float = sin(t * bass_freq * TAU) * bass_env * 0.35
		var sample: float = lead + bass

		bytes[i] = int(clampf((sample + 1.0) * 0.5 * 255.0, 0.0, 255.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = mix_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = sample_count
	stream.data = bytes
	return stream
