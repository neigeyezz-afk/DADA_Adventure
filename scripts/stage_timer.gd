extends Node
class_name StageTimer
## 스테이지 제한 시간. 제한 시간 안에 HiddenDoor(스테이지 출구)에 도달하지 못하면
## 그 즉시 게임이 종료된다(트리 일시정지 + 게임오버 표시).
## HiddenDoor의 opened 시그널이 연결되면(씬 파일 참고) 타이머가 멈추고 클리어 처리된다.

signal time_updated(remaining: float)
signal game_over()
signal stage_cleared()

@export var time_limit: float = 0.0              # 0 = 무제한 (임시 변경)

var _remaining: float = 0.0
var _finished: bool = false   # 시간 초과(게임오버) 또는 클리어로 더 이상 진행하지 않음
var _manually_paused: bool = false   # 상점 등 안전 지역에 머무는 동안 일시정지

func _ready() -> void:
	add_to_group("stage_timer")
	_remaining = time_limit

func get_remaining() -> float:
	return _remaining

func pause_timer() -> void:
	_manually_paused = true

func resume_timer() -> void:
	_manually_paused = false

func _process(delta: float) -> void:
	if _finished or _manually_paused:
		return

	# time_limit이 0이면 무제한 모드
	if time_limit <= 0.0:
		return

	_remaining = maxf(0.0, _remaining - delta)
	time_updated.emit(_remaining)
	if _remaining <= 0.0:
		_finished = true
		game_over.emit()
		get_tree().paused = true

func _on_stage_cleared() -> void:
	_finished = true
	stage_cleared.emit()
