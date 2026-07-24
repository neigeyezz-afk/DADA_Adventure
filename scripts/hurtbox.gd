extends Area2D
class_name Hurtbox
## 공격을 '받는' 판정 영역. 슬라임, 숨겨진 요소 등에 부착한다.
## 공격 히트박스(DADA의 검)가 이 영역을 감지하면 receive_hit()을 호출하고,
## 소유자(슬라임 등)는 hit_received 시그널을 받아 데미지 처리를 한다.

signal hit_received(damage: int, direction: Vector2)

func receive_hit(damage: int, direction: Vector2) -> void:
	hit_received.emit(damage, direction)
