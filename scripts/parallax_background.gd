extends ParallaxBackground
class_name StageParallaxBackground

## 스테이지 1 슬라임 초원의 다중 레이어 배경 시스템
## Sky, Distant Hills, Near Trees/Hills 레이어의 패럴랙스 스크롤을 처리합니다.

@export var sky_top_color: Color = Color(0.12, 0.28, 0.52, 1.0)
@export var sky_bottom_color: Color = Color(0.42, 0.68, 0.88, 1.0)

func _ready() -> void:
	scroll_ignore_camera_zoom = false
