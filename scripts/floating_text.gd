extends Node
class_name FloatingText
## ==========================================================
## FloatingText: 데미지/재화 획득 팝업 이펙트 (Autoload / Helper)
## ==========================================================

static func spawn(parent: Node, global_pos: Vector2, text_str: String, color: Color = Color.WHITE) -> Label:
	if not parent:
		return null
	var label := Label.new()
	label.text = text_str
	label.global_position = global_pos + Vector2(-20, -10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	label.z_index = 100
	parent.add_child(label)

	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y - 48.0, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(label.queue_free)
	return label
