class_name Dialogue
extends CanvasLayer
## 對話框:底部面板 + 打字機效果。按 E / 空白 / Enter 推進;打字中按鍵會先顯示整句。
## 台詞格式:{"who": "白狐", "text": "……"};who 為空字串代表旁白。

signal finished

const CHARS_PER_SECOND := 28.0

var active := false

var _lines: Array = []
var _index := -1
var _typing := false
var _tween: Tween
var _panel: PanelContainer
var _name_label: Label
var _text_label: Label


func _ready() -> void:
	layer = 10
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 120.0
	_panel.offset_right = -120.0
	_panel.offset_top = -230.0
	_panel.offset_bottom = -36.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(WB.C_SUMI, 0.86)
	style.border_color = WB.C_GOLD.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_name_label = WB.label(box, 26, 800, 6)
	_name_label.add_theme_color_override("font_color", WB.C_GOLD)
	_text_label = WB.label(box, 27, 500, 2)
	_text_label.add_theme_constant_override("line_spacing", 8)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hint := WB.label(box, 16)
	hint.text = "按 E / 空白 繼續"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate = Color(1, 1, 1, 0.6)
	_panel.visible = false


func play(lines: Array) -> void:
	_lines = lines
	_index = -1
	active = true
	_panel.visible = true
	_next()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _typing:
			_finish_typing()
		else:
			_next()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		active = false
		_panel.visible = false
		finished.emit()
		return
	var line: Dictionary = _lines[_index]
	var who: String = line.get("who", "")
	_name_label.text = "◆ " + who
	_name_label.visible = who != ""
	_text_label.text = line["text"]
	_text_label.visible_ratio = 0.0
	_typing = true
	if _tween:
		_tween.kill()
	var duration: float = maxf(0.2, float(_text_label.text.length()) / CHARS_PER_SECOND)
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_ratio", 1.0, duration)
	_tween.finished.connect(func() -> void: _typing = false)


func _finish_typing() -> void:
	if _tween:
		_tween.kill()
	_text_label.visible_ratio = 1.0
	_typing = false
