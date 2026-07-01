extends Control

const GRID_INDEXES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
const TIME_COLOR_NORMAL := Color(0.07, 0.11, 0.18)
const TIME_COLOR_URGENT := Color(0.86, 0.18, 0.16)
const ROUND_TIME_LIMIT: int = 5
const URGENT_TIME_THRESHOLD: int = 1
const MAX_TIME_LIMIT: int = 9
const CORRECT_REVEAL_DURATION: float = 1.0
const LEVEL_BANNER_DURATION: float = 1.45
const SAVE_PATH: String = "user://save.cfg"
const SAVE_SECTION: String = "progress"
const SAVE_KEY_HIGH_SCORE: String = "high_score"
const SAVE_KEY_QUESTIONS_PER_LEVEL: String = "questions_per_level"
const SAVE_KEY_ASSIST_VISIBLE: String = "assist_visible"

var rng := RandomNumberGenerator.new()

var score: int = 0
var high_score: int = 0
var chances: int = 3
var level: int = 1
var effective_level: int = 1
var streak: int = 0
var current_correct_index: int = -1
var input_locked: bool = false
var current_question_text: String = ""
var current_stage_label: String = ""

var consecutive_misses: int = 0
var assist_rounds_left: int = 0
var questions_per_level: int = 10
var assist_items_visible: bool = false
var hint_uses: int = 1
var slow_uses: int = 1
var shield_uses: int = 1
var shield_armed: bool = false

var score_label: Label
var high_score_label: Label
var chances_label: Label
var level_label: Label
var streak_label: Label
var time_label: Label
var question_label: Label
var correct_hint_label: Label
var status_badge_panel: PanelContainer
var status_badge_label: Label
var assist_toggle_button: CheckBox
var questions_per_level_spinbox: SpinBox
var powerup_bar: HBoxContainer
var hint_button: Button
var slow_button: Button
var shield_button: Button
var hud_bar: HBoxContainer
var gameplay_center: CenterContainer
var welcome_overlay: ColorRect
var options_overlay: ColorRect
var help_overlay: ColorRect
var help_title_label: Label
var help_body_label: Label
var help_page_label: Label
var level_banner_overlay: ColorRect
var level_banner_label: Label
var game_over_overlay: ColorRect
var game_over_label: Label
var board_grid: GridContainer
var board_wrap: VBoxContainer

var correct_sfx_player: AudioStreamPlayer
var wrong_sfx_player: AudioStreamPlayer
var tick_sfx_player: AudioStreamPlayer
var urgent_tick_sfx_player: AudioStreamPlayer
var assist_item_sfx_player: AudioStreamPlayer
var combo_bonus_sfx_player: AudioStreamPlayer
var round_timer: Timer
var round_unlock_fallback_timer: Timer
var time_pulse_tween: Tween
var status_badge_tween: Tween

var round_time_left: int = ROUND_TIME_LIMIT
var round_time_limit: int = ROUND_TIME_LIMIT
var round_id: int = 0
var last_banner_level_shown: int = -1
var pending_unlock_round_id: int = -1
var help_page_index: int = 0

var help_pages: Array[Dictionary] = [
	{
		"title": "How To Play",
		"body": "Solve the math question in the center area.\nTap one number in the 3x3 grid before time runs out.",
	},
	{
		"title": "Scoring And Chances",
		"body": "Correct answer: +1 point.\nEvery 3 correct in a row gives a combo bonus.\nYou have 3 chances before game over.",
	},
	{
		"title": "Assist Items",
		"body": "Hint removes 2 wrong choices.\n+2s adds two seconds to current question.\nShield saves one wrong answer or timeout.",
	},
	{
		"title": "Level Progress",
		"body": "Difficulty increases by level.\nOperations grow from +, -, *, / to mixed expressions.\nQuestions per level can be changed in Options.",
	},
]

var answer_buttons: Dictionary = {}
var cell_panels: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	build_ui()
	build_audio()
	load_progress()
	update_hud()
	show_welcome_screen()


func build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.95, 0.98, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	hud_bar = HBoxContainer.new()
	hud_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_bar.offset_left = 20
	hud_bar.offset_top = 20
	hud_bar.offset_right = -20
	hud_bar.offset_bottom = 90
	hud_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_bar.add_theme_constant_override("separation", 24)
	add_child(hud_bar)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	hud_bar.add_child(score_label)

	high_score_label = Label.new()
	high_score_label.add_theme_font_size_override("font_size", 36)
	high_score_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	hud_bar.add_child(high_score_label)

	chances_label = Label.new()
	chances_label.add_theme_font_size_override("font_size", 36)
	chances_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	hud_bar.add_child(chances_label)

	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 36)
	level_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	hud_bar.add_child(level_label)

	streak_label = Label.new()
	streak_label.add_theme_font_size_override("font_size", 36)
	streak_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	hud_bar.add_child(streak_label)

	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 36)
	time_label.add_theme_color_override("font_color", TIME_COLOR_NORMAL)
	hud_bar.add_child(time_label)

	powerup_bar = HBoxContainer.new()
	powerup_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	powerup_bar.offset_left = 20
	powerup_bar.offset_top = 88
	powerup_bar.offset_right = -20
	powerup_bar.offset_bottom = 132
	powerup_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	powerup_bar.add_theme_constant_override("separation", 14)
	powerup_bar.visible = false
	add_child(powerup_bar)

	hint_button = Button.new()
	hint_button.custom_minimum_size = Vector2(140, 40)
	hint_button.add_theme_font_size_override("font_size", 22)
	hint_button.pressed.connect(_on_hint_powerup_pressed)
	powerup_bar.add_child(hint_button)

	slow_button = Button.new()
	slow_button.custom_minimum_size = Vector2(140, 40)
	slow_button.add_theme_font_size_override("font_size", 22)
	slow_button.pressed.connect(_on_slow_powerup_pressed)
	powerup_bar.add_child(slow_button)

	shield_button = Button.new()
	shield_button.custom_minimum_size = Vector2(140, 40)
	shield_button.add_theme_font_size_override("font_size", 22)
	shield_button.pressed.connect(_on_shield_powerup_pressed)
	powerup_bar.add_child(shield_button)

	gameplay_center = CenterContainer.new()
	gameplay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameplay_center.offset_top = 134
	gameplay_center.offset_bottom = -20
	add_child(gameplay_center)

	board_wrap = VBoxContainer.new()
	board_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	board_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_wrap.add_theme_constant_override("separation", 14)
	gameplay_center.add_child(board_wrap)

	question_label = Label.new()
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.custom_minimum_size = Vector2(260, 64)
	question_label.add_theme_font_size_override("font_size", 46)
	question_label.add_theme_color_override("font_color", Color(0.06, 0.10, 0.16))
	board_wrap.add_child(question_label)

	correct_hint_label = Label.new()
	correct_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	correct_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	correct_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	correct_hint_label.clip_text = true
	correct_hint_label.add_theme_font_size_override("font_size", 28)
	correct_hint_label.add_theme_color_override("font_color", Color(0.06, 0.10, 0.16))
	correct_hint_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	correct_hint_label.visible = false
	correct_hint_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	correct_hint_label.custom_minimum_size = Vector2(220, 72)
	correct_hint_label.position = Vector2(16, 100)
	add_child(correct_hint_label)

	status_badge_panel = PanelContainer.new()
	status_badge_panel.visible = false
	status_badge_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	status_badge_panel.custom_minimum_size = Vector2(260, 52)
	status_badge_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_badge_panel.offset_top = 136
	status_badge_panel.offset_bottom = 188
	status_badge_panel.offset_left = 130
	status_badge_panel.offset_right = -130
	status_badge_panel.z_index = 30
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.07, 0.15, 0.28, 0.94)
	badge_style.corner_radius_top_left = 10
	badge_style.corner_radius_top_right = 10
	badge_style.corner_radius_bottom_right = 10
	badge_style.corner_radius_bottom_left = 10
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge_style.border_color = Color(0.48, 0.72, 0.98, 0.96)
	status_badge_panel.add_theme_stylebox_override("panel", badge_style)
	add_child(status_badge_panel)

	status_badge_label = Label.new()
	status_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_badge_label.add_theme_font_size_override("font_size", 28)
	status_badge_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	status_badge_panel.add_child(status_badge_label)

	board_grid = GridContainer.new()
	board_grid.columns = 3
	board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_grid.add_theme_constant_override("h_separation", 6)
	board_grid.add_theme_constant_override("v_separation", 6)
	board_wrap.add_child(board_grid)

	for i in range(9):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(120, 120)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", make_cell_style())
		board_grid.add_child(panel)
		cell_panels[i] = panel

		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_font_size_override("font_size", 44)
		button.add_theme_color_override("font_color", Color(0.06, 0.10, 0.16))
		button.add_theme_color_override("font_hover_color", Color(0.06, 0.10, 0.16))
		button.add_theme_color_override("font_pressed_color", Color(0.06, 0.10, 0.16))
		button.pressed.connect(_on_answer_pressed.bind(i))
		panel.add_child(button)
		answer_buttons[i] = button

	build_game_over_overlay()
	build_round_timer()
	build_round_unlock_fallback_timer()
	build_level_banner_overlay()
	build_welcome_overlay()
	build_options_overlay()
	build_help_overlay()
	update_board_size()
	_on_assist_visibility_toggled(assist_items_visible)


func build_game_over_overlay() -> void:
	game_over_overlay = ColorRect.new()
	game_over_overlay.color = Color(0.05, 0.08, 0.15, 0.82)
	game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.visible = false
	add_child(game_over_overlay)

	var popup_center := CenterContainer.new()
	popup_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.add_child(popup_center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 220)
	panel.add_theme_stylebox_override("panel", make_popup_style())
	popup_center.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	game_over_label = Label.new()
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 34)
	game_over_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	content.add_child(game_over_label)

	var restart_button := Button.new()
	restart_button.text = "Play Again"
	restart_button.custom_minimum_size = Vector2(220, 56)
	restart_button.add_theme_font_size_override("font_size", 28)
	restart_button.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	restart_button.pressed.connect(_on_restart_pressed)
	content.add_child(restart_button)

	var welcome_button := Button.new()
	welcome_button.text = "Back To Welcome"
	welcome_button.custom_minimum_size = Vector2(220, 56)
	welcome_button.add_theme_font_size_override("font_size", 26)
	welcome_button.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	welcome_button.pressed.connect(_on_back_to_welcome_pressed)
	content.add_child(welcome_button)


func build_audio() -> void:
	correct_sfx_player = AudioStreamPlayer.new()
	correct_sfx_player.stream = create_tone_stream(940.0, 0.13, 0.28)
	add_child(correct_sfx_player)

	wrong_sfx_player = AudioStreamPlayer.new()
	wrong_sfx_player.stream = create_tone_stream(220.0, 0.22, 0.35)
	add_child(wrong_sfx_player)

	tick_sfx_player = AudioStreamPlayer.new()
	tick_sfx_player.stream = create_tone_stream(1350.0, 0.05, 0.22)
	add_child(tick_sfx_player)

	urgent_tick_sfx_player = AudioStreamPlayer.new()
	urgent_tick_sfx_player.stream = create_tone_stream(1700.0, 0.05, 0.36)
	add_child(urgent_tick_sfx_player)

	assist_item_sfx_player = AudioStreamPlayer.new()
	assist_item_sfx_player.stream = create_tone_stream(760.0, 0.09, 0.25)
	add_child(assist_item_sfx_player)

	combo_bonus_sfx_player = AudioStreamPlayer.new()
	combo_bonus_sfx_player.stream = create_tone_stream(1120.0, 0.16, 0.30)
	add_child(combo_bonus_sfx_player)


func build_round_timer() -> void:
	round_timer = Timer.new()
	round_timer.wait_time = 1.0
	round_timer.one_shot = false
	round_timer.autostart = false
	round_timer.timeout.connect(_on_round_timer_timeout)
	add_child(round_timer)


func build_round_unlock_fallback_timer() -> void:
	round_unlock_fallback_timer = Timer.new()
	round_unlock_fallback_timer.one_shot = true
	round_unlock_fallback_timer.autostart = false
	round_unlock_fallback_timer.timeout.connect(_on_round_unlock_fallback_timeout)
	add_child(round_unlock_fallback_timer)


func build_level_banner_overlay() -> void:
	level_banner_overlay = ColorRect.new()
	level_banner_overlay.color = Color(0.06, 0.10, 0.18, 0.82)
	level_banner_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_banner_overlay.visible = false
	add_child(level_banner_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_banner_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 150)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.19, 0.33, 0.95)
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.border_color = Color(0.45, 0.66, 0.90)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	level_banner_label = Label.new()
	level_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_banner_label.add_theme_font_size_override("font_size", 36)
	level_banner_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	panel.add_child(level_banner_label)


func build_welcome_overlay() -> void:
	welcome_overlay = ColorRect.new()
	welcome_overlay.color = Color(0.06, 0.10, 0.18, 0.88)
	welcome_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome_overlay.visible = false
	add_child(welcome_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 320)
	panel.add_theme_stylebox_override("panel", make_popup_style())
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)

	var title := Label.new()
	title.text = "Math Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	content.add_child(title)

	var start_button := Button.new()
	start_button.text = "Start Game"
	start_button.custom_minimum_size = Vector2(260, 56)
	start_button.add_theme_font_size_override("font_size", 30)
	start_button.pressed.connect(_on_start_game_pressed)
	content.add_child(start_button)

	var options_button := Button.new()
	options_button.text = "Options"
	options_button.custom_minimum_size = Vector2(260, 56)
	options_button.add_theme_font_size_override("font_size", 30)
	options_button.pressed.connect(_on_open_options_pressed)
	content.add_child(options_button)

	var help_button := Button.new()
	help_button.text = "Help"
	help_button.custom_minimum_size = Vector2(260, 56)
	help_button.add_theme_font_size_override("font_size", 30)
	help_button.pressed.connect(_on_open_help_pressed)
	content.add_child(help_button)


func build_options_overlay() -> void:
	options_overlay = ColorRect.new()
	options_overlay.color = Color(0.06, 0.10, 0.18, 0.88)
	options_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_overlay.visible = false
	add_child(options_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 360)
	panel.add_theme_stylebox_override("panel", make_popup_style())
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title := Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	content.add_child(title)

	var assist_row := HBoxContainer.new()
	assist_row.alignment = BoxContainer.ALIGNMENT_CENTER
	assist_row.custom_minimum_size = Vector2(460, 84)
	assist_row.add_theme_constant_override("separation", 20)
	content.add_child(assist_row)

	var assist_label := Label.new()
	assist_label.text = "Show Assist Items"
	assist_label.add_theme_font_size_override("font_size", 36)
	assist_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	assist_row.add_child(assist_label)

	assist_toggle_button = CheckBox.new()
	assist_toggle_button.text = ""
	assist_toggle_button.button_pressed = assist_items_visible
	assist_toggle_button.custom_minimum_size = Vector2(56, 56)
	assist_toggle_button.scale = Vector2(2.0, 2.0)
	assist_toggle_button.toggled.connect(_on_assist_visibility_toggled)
	assist_row.add_child(assist_toggle_button)

	var qpl_row := HBoxContainer.new()
	qpl_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qpl_row.add_theme_constant_override("separation", 12)
	content.add_child(qpl_row)

	var qpl_label := Label.new()
	qpl_label.text = "Questions Per Level"
	qpl_label.add_theme_font_size_override("font_size", 36)
	qpl_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	qpl_row.add_child(qpl_label)

	questions_per_level_spinbox = SpinBox.new()
	questions_per_level_spinbox.min_value = 3
	questions_per_level_spinbox.max_value = 12
	questions_per_level_spinbox.step = 1
	questions_per_level_spinbox.rounded = true
	questions_per_level_spinbox.value = questions_per_level
	questions_per_level_spinbox.custom_minimum_size = Vector2(180, 64)
	questions_per_level_spinbox.add_theme_font_size_override("font_size", 32)
	var qpl_line_edit := questions_per_level_spinbox.get_line_edit()
	if qpl_line_edit != null:
		qpl_line_edit.add_theme_font_size_override("font_size", 32)
	questions_per_level_spinbox.value_changed.connect(_on_questions_per_level_changed)
	qpl_row.add_child(questions_per_level_spinbox)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(220, 54)
	back_button.add_theme_font_size_override("font_size", 30)
	back_button.pressed.connect(_on_options_back_pressed)
	content.add_child(back_button)


func build_help_overlay() -> void:
	help_overlay = ColorRect.new()
	help_overlay.color = Color(0.06, 0.10, 0.18, 0.88)
	help_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_overlay.visible = false
	add_child(help_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 420)
	panel.add_theme_stylebox_override("panel", make_popup_style())
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	help_title_label = Label.new()
	help_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_title_label.add_theme_font_size_override("font_size", 40)
	help_title_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	content.add_child(help_title_label)

	help_body_label = Label.new()
	help_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_body_label.custom_minimum_size = Vector2(500, 180)
	help_body_label.add_theme_font_size_override("font_size", 28)
	help_body_label.add_theme_color_override("font_color", Color(0.07, 0.11, 0.18))
	content.add_child(help_body_label)

	help_page_label = Label.new()
	help_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_page_label.add_theme_font_size_override("font_size", 24)
	help_page_label.add_theme_color_override("font_color", Color(0.12, 0.20, 0.33))
	content.add_child(help_page_label)

	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 14)
	content.add_child(nav_row)

	var prev_button := Button.new()
	prev_button.text = "Prev"
	prev_button.custom_minimum_size = Vector2(160, 52)
	prev_button.add_theme_font_size_override("font_size", 26)
	prev_button.pressed.connect(_on_help_prev_pressed)
	nav_row.add_child(prev_button)

	var next_button := Button.new()
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(160, 52)
	next_button.add_theme_font_size_override("font_size", 26)
	next_button.pressed.connect(_on_help_next_pressed)
	nav_row.add_child(next_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(220, 54)
	back_button.add_theme_font_size_override("font_size", 30)
	back_button.pressed.connect(_on_help_back_pressed)
	content.add_child(back_button)


func show_welcome_screen() -> void:
	input_locked = true
	stop_round_countdown()
	stop_time_pulse()
	if welcome_overlay != null:
		welcome_overlay.visible = true
	if options_overlay != null:
		options_overlay.visible = false
	if help_overlay != null:
		help_overlay.visible = false
	if game_over_overlay != null:
		game_over_overlay.visible = false
	set_gameplay_visible(false)


func show_options_screen() -> void:
	if welcome_overlay != null:
		welcome_overlay.visible = false
	if options_overlay != null:
		options_overlay.visible = true
	if help_overlay != null:
		help_overlay.visible = false
	if assist_toggle_button != null:
		assist_toggle_button.button_pressed = assist_items_visible
	if questions_per_level_spinbox != null:
		questions_per_level_spinbox.value = questions_per_level


func show_help_screen() -> void:
	if welcome_overlay != null:
		welcome_overlay.visible = false
	if options_overlay != null:
		options_overlay.visible = false
	if help_overlay != null:
		help_overlay.visible = true
	help_page_index = 0
	refresh_help_page()


func refresh_help_page() -> void:
	if help_title_label == null or help_body_label == null or help_page_label == null:
		return
	if help_pages.is_empty():
		return
	help_page_index = clampi(help_page_index, 0, help_pages.size() - 1)
	var page: Dictionary = help_pages[help_page_index]
	help_title_label.text = str(page.get("title", "Help"))
	help_body_label.text = str(page.get("body", ""))
	help_page_label.text = "Page %d / %d" % [help_page_index + 1, help_pages.size()]


func set_gameplay_visible(visible: bool) -> void:
	if hud_bar != null:
		hud_bar.visible = visible
	if powerup_bar != null:
		powerup_bar.visible = visible and assist_items_visible
	if gameplay_center != null:
		gameplay_center.visible = visible


func begin_new_game() -> void:
	score = 0
	chances = 3
	level = 1
	effective_level = 1
	streak = 0
	consecutive_misses = 0
	assist_rounds_left = 0
	hint_uses = 1
	slow_uses = 1
	shield_uses = 1
	shield_armed = false
	round_time_limit = ROUND_TIME_LIMIT
	round_time_left = ROUND_TIME_LIMIT
	last_banner_level_shown = -1
	pending_unlock_round_id = -1
	if welcome_overlay != null:
		welcome_overlay.visible = false
	if options_overlay != null:
		options_overlay.visible = false
	set_gameplay_visible(true)
	update_board_size()
	update_hud()
	start_new_round()


func _on_start_game_pressed() -> void:
	begin_new_game()


func _on_open_options_pressed() -> void:
	show_options_screen()


func _on_open_help_pressed() -> void:
	show_help_screen()


func _on_options_back_pressed() -> void:
	if options_overlay != null:
		options_overlay.visible = false
	if welcome_overlay != null:
		welcome_overlay.visible = true
	save_progress()


func _on_help_prev_pressed() -> void:
	help_page_index = maxi(0, help_page_index - 1)
	refresh_help_page()


func _on_help_next_pressed() -> void:
	help_page_index = mini(help_pages.size() - 1, help_page_index + 1)
	refresh_help_page()


func _on_help_back_pressed() -> void:
	if help_overlay != null:
		help_overlay.visible = false
	if welcome_overlay != null:
		welcome_overlay.visible = true


func create_tone_stream(frequency: float, duration_sec: float, amplitude: float) -> AudioStreamWAV:
	var mix_rate: int = 44100
	var sample_count: int = maxi(1, int(duration_sec * float(mix_rate)))
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(mix_rate)
		var edge_fade: float = minf(1.0, minf(t * 16.0, (duration_sec - t) * 16.0))
		var wave: float = sin(TAU * frequency * t)
		var sample_val: int = int(round(wave * amplitude * edge_fade * 32767.0))
		data.encode_s16(i * 2, sample_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func make_cell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.9)
	style.border_color = Color(0.16, 0.24, 0.35)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	return style


func make_popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		update_board_size()


func update_board_size() -> void:
	if board_grid == null or question_label == null or board_wrap == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var horizontal_limit: float = viewport_size.x * 0.88
	var reserved_top: float = 134.0 if (powerup_bar != null and powerup_bar.visible) else 104.0
	var reserved_bottom: float = 20.0
	var wrap_gap: float = float(board_wrap.get_theme_constant("separation"))
	var question_height: float = maxf(question_label.get_combined_minimum_size().y, 64.0)
	var vertical_limit: float = viewport_size.y - reserved_top - reserved_bottom - question_height - wrap_gap - 10.0
	var side: float = clampf(minf(horizontal_limit, vertical_limit), 180.0, 620.0)
	board_grid.custom_minimum_size = Vector2(side, side)
	question_label.custom_minimum_size = Vector2(side, 64.0)
	for panel in cell_panels.values():
		var item := panel as PanelContainer
		if item != null:
			item.custom_minimum_size = Vector2(side / 3.0 - 6.0, side / 3.0 - 6.0)
	position_correct_hint_label()


func position_correct_hint_label() -> void:
	if correct_hint_label == null or board_grid == null:
		return
	var board_rect: Rect2 = board_grid.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	var margin: float = 14.0
	var hint_height: float = 84.0
	var right_space: float = viewport_size.x - (board_rect.position.x + board_rect.size.x) - margin

	if right_space >= 220.0:
		var width_right: float = clampf(right_space - margin, 220.0, 360.0)
		correct_hint_label.size = Vector2(width_right, hint_height)
		var x_right: float = board_rect.position.x + board_rect.size.x + margin
		var y_right: float = board_rect.position.y + board_rect.size.y * 0.5 - hint_height * 0.5
		y_right = clampf(y_right, margin, viewport_size.y - hint_height - margin)
		correct_hint_label.position = Vector2(x_right, y_right)
		return

	# Fallback: place hint below grid when right-side room is insufficient.
	var width_bottom: float = minf(viewport_size.x - margin * 2.0, 420.0)
	correct_hint_label.size = Vector2(width_bottom, hint_height)
	var x_bottom: float = board_rect.position.x + board_rect.size.x * 0.5 - width_bottom * 0.5
	x_bottom = clampf(x_bottom, margin, viewport_size.x - width_bottom - margin)
	var y_bottom: float = board_rect.position.y + board_rect.size.y + margin
	y_bottom = minf(y_bottom, viewport_size.y - hint_height - margin)
	correct_hint_label.position = Vector2(x_bottom, y_bottom)


func start_new_round() -> void:
	input_locked = true
	stop_round_countdown()
	update_hud()
	round_id += 1
	level = calculate_level()
	effective_level = max(1, level - 2) if assist_rounds_left > 0 else level
	if assist_rounds_left > 0:
		assist_rounds_left -= 1
	var profile := build_difficulty_profile(level)
	if assist_rounds_left >= 0 and effective_level != level:
		profile = build_difficulty_profile(effective_level)
		profile["time_limit"] = mini(MAX_TIME_LIMIT, int(profile["time_limit"]) + 1)
		profile["stage_label"] = "Assist: %s" % profile["stage_label"]
	round_time_limit = profile["time_limit"]
	round_time_left = round_time_limit
	var question_data := generate_question(profile)
	var correct_answer: int = question_data["answer"]
	current_question_text = question_data["text"]
	current_stage_label = profile["stage_label"]
	question_label.text = current_question_text
	correct_hint_label.visible = false

	var options := generate_options(correct_answer)
	var correct_slot: int = rng.randi_range(0, GRID_INDEXES.size() - 1)
	var existing_correct_slot: int = options.find(correct_answer)
	if existing_correct_slot >= 0 and existing_correct_slot != correct_slot:
		var temp: int = options[correct_slot]
		options[correct_slot] = options[existing_correct_slot]
		options[existing_correct_slot] = temp
	current_correct_index = GRID_INDEXES[correct_slot]

	for i in range(GRID_INDEXES.size()):
		var grid_index: int = GRID_INDEXES[i]
		var button := answer_buttons[grid_index] as Button
		button.disabled = true
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		button.text = str(options[i])

	update_hud()
	if level != last_banner_level_shown:
		last_banner_level_shown = level
		show_level_intro_banner(round_id)
	else:
		begin_round_interaction(round_id)


func show_level_intro_banner(active_round_id: int) -> void:
	if level_banner_overlay == null or level_banner_label == null:
		begin_round_interaction(active_round_id)
		return

	pending_unlock_round_id = active_round_id
	round_unlock_fallback_timer.stop()
	round_unlock_fallback_timer.wait_time = LEVEL_BANNER_DURATION + 0.6
	round_unlock_fallback_timer.start()

	level_banner_label.text = "Level %d\n%s" % [level, current_stage_label]
	level_banner_overlay.visible = true
	level_banner_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(level_banner_overlay, "modulate:a", 1.0, 0.16)
	tween.tween_interval(LEVEL_BANNER_DURATION)
	tween.tween_property(level_banner_overlay, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func() -> void:
		if active_round_id != round_id:
			return
		level_banner_overlay.visible = false
		begin_round_interaction(active_round_id)
	)


func begin_round_interaction(active_round_id: int) -> void:
	if active_round_id != round_id:
		return
	pending_unlock_round_id = -1
	round_unlock_fallback_timer.stop()
	input_locked = false
	for i in GRID_INDEXES:
		var button := answer_buttons[i] as Button
		button.disabled = false
	start_round_countdown()


func _on_round_unlock_fallback_timeout() -> void:
	if pending_unlock_round_id != round_id:
		return
	if not input_locked:
		return
	if game_over_overlay != null and game_over_overlay.visible:
		return
	if level_banner_overlay != null:
		level_banner_overlay.visible = false
	begin_round_interaction(round_id)


func start_round_countdown() -> void:
	if round_timer != null:
		round_timer.stop()
		round_timer.start()


func stop_round_countdown() -> void:
	if round_timer != null:
		round_timer.stop()


func _on_round_timer_timeout() -> void:
	if input_locked:
		return

	round_time_left -= 1
	if round_time_left > 0:
		if round_time_left == URGENT_TIME_THRESHOLD:
			play_urgent_tick(round_id)
		else:
			tick_sfx_player.play()
		update_hud()
		return

	round_time_left = 0
	update_hud()
	await on_time_up()


func play_urgent_tick(active_round_id: int) -> void:
	urgent_tick_sfx_player.play()
	await get_tree().create_timer(0.18).timeout
	if input_locked:
		return
	if active_round_id != round_id:
		return
	if round_time_left != URGENT_TIME_THRESHOLD:
		return
	urgent_tick_sfx_player.play()


func on_time_up() -> void:
	if input_locked:
		return

	input_locked = true
	stop_round_countdown()
	wrong_sfx_player.play()

	for i in GRID_INDEXES:
		var button := answer_buttons[i] as Button
		button.disabled = true

	streak = 0
	var penalty_applied: bool = apply_wrong_outcome()
	update_hud()

	if not penalty_applied:
		resume_current_round_after_shield_save(true)
		return

	if chances <= 0:
		show_game_over()
		return

	register_miss()
	await reveal_correct_answer(CORRECT_REVEAL_DURATION)
	start_new_round()


func calculate_level() -> int:
	return 1 + int(score / maxi(1, questions_per_level))


func build_difficulty_profile(current_level: int) -> Dictionary:
	var ops: Array[String] = ["+"]
	var operand_count: int = 2
	var min_value: int = 0
	var max_value: int = 10

	if current_level == 1:
		ops = ["+"]
		max_value = 10
		
	elif current_level == 2:
		ops = ["-"]
		max_value = 12
	elif current_level == 3:
		ops = ["*"]
		min_value = 1
		max_value = 6
	elif current_level == 4:
		ops = ["/"]
		min_value = 1
		max_value = 9
	elif current_level == 5:
		ops = ["+", "-"]
		max_value = 20
	elif current_level == 6:
		ops = ["+", "-", "*"]
		min_value = 1
		max_value = 12
	elif current_level == 7:
		ops = ["+", "-", "*", "/"]
		min_value = 1
		max_value = 12
	else:
		ops = ["+", "-", "*", "/"]
		operand_count = clampi(3 + int((current_level - 8) / 3), 3, 5)
		min_value = 1
		max_value = 14

	var time_limit: int = ROUND_TIME_LIMIT
	if current_level >= 3:
		time_limit += 1
	if current_level >= 7:
		time_limit += 1
	if operand_count >= 3:
		time_limit += 1
	if operand_count >= 4:
		time_limit += 1
	if operand_count >= 5:
		time_limit += 1
	time_limit = mini(time_limit, MAX_TIME_LIMIT)

	var stage_label: String = "Addition"
	if ops.size() == 1 and ops[0] == "-":
		stage_label = "Subtraction"
	elif ops.size() == 1 and ops[0] == "*":
		stage_label = "Multiplication"
	elif ops.size() == 1 and ops[0] == "/":
		stage_label = "Division"
	elif operand_count > 2:
		stage_label = "Mixed %d Numbers" % operand_count
	elif ops.size() > 1:
		stage_label = "Mixed Operations"

	return {
		"ops": ops,
		"operand_count": operand_count,
		"min": min_value,
		"max": max_value,
		"time_limit": time_limit,
		"stage_label": stage_label,
	}


func generate_question(profile: Dictionary) -> Dictionary:
	var ops: Array[String] = profile["ops"]
	var operand_count: int = profile["operand_count"]
	var min_value: int = profile["min"]
	var max_value: int = profile["max"]

	if operand_count <= 2:
		var op: String = ops[rng.randi_range(0, ops.size() - 1)]
		return generate_two_operand_question(op, min_value, max_value)

	return generate_multi_operand_question(ops, operand_count, min_value, max_value)


func generate_two_operand_question(op: String, min_value: int, max_value: int) -> Dictionary:
	if op == "+":
		var add_a: int = rng.randi_range(min_value, max_value)
		var add_b: int = rng.randi_range(min_value, max_value)
		return {
			"text": "%d + %d = ?" % [add_a, add_b],
			"answer": add_a + add_b,
		}

	if op == "-":
		var sub_a: int = rng.randi_range(min_value, max_value)
		var sub_b: int = rng.randi_range(min_value, max_value)
		if sub_b > sub_a:
			var sub_temp: int = sub_a
			sub_a = sub_b
			sub_b = sub_temp
		return {
			"text": "%d - %d = ?" % [sub_a, sub_b],
			"answer": sub_a - sub_b,
		}

	if op == "*":
		var mul_a: int = rng.randi_range(min_value, max_value)
		var mul_b: int = rng.randi_range(min_value, max_value)
		return {
			"text": "%d * %d = ?" % [mul_a, mul_b],
			"answer": mul_a * mul_b,
		}

	# Division questions are generated to always have integer answers.
	var divisor: int = rng.randi_range(max(2, min_value), max(2, max_value))
	var quotient: int = rng.randi_range(1, max_value)
	var dividend: int = divisor * quotient
	return {
		"text": "%d / %d = ?" % [dividend, divisor],
		"answer": quotient,
	}


func generate_multi_operand_question(ops: Array[String], operand_count: int, min_value: int, max_value: int) -> Dictionary:
	var current: int = rng.randi_range(min_value, max_value)
	var expression: String = str(current)

	for _i in range(operand_count - 1):
		var next_step := create_expression_step(current, ops, min_value, max_value)
		var op: String = next_step["op"]
		var value: int = next_step["value"]
		current = next_step["result"]
		expression = "(%s %s %d)" % [expression, op, value]

	return {
		"text": "%s = ?" % expression,
		"answer": current,
	}


func create_expression_step(current: int, ops: Array[String], min_value: int, max_value: int) -> Dictionary:
	var op: String = ops[rng.randi_range(0, ops.size() - 1)]

	if op == "+":
		var add_value: int = rng.randi_range(min_value, max_value)
		if current + add_value > 260:
			add_value = max(1, 260 - current)
		return {"op": "+", "value": add_value, "result": current + add_value}

	if op == "-":
		if current <= 0:
			var fallback_add: int = rng.randi_range(min_value, max_value)
			return {"op": "+", "value": fallback_add, "result": current + fallback_add}
		var subtract_value: int = rng.randi_range(1, mini(current, max_value))
		return {"op": "-", "value": subtract_value, "result": current - subtract_value}

	if op == "*":
		if current > 80:
			var fallback_sub: int = rng.randi_range(1, mini(current, max_value))
			return {"op": "-", "value": fallback_sub, "result": current - fallback_sub}
		var mul_value: int = rng.randi_range(2, mini(max_value, 7))
		return {"op": "*", "value": mul_value, "result": current * mul_value}

	# Use integer-safe division; if unavailable, fallback to addition.
	if current == 0:
		var zero_add: int = rng.randi_range(1, max_value)
		return {"op": "+", "value": zero_add, "result": current + zero_add}

	var divisors: Array[int] = []
	var abs_current: int = absi(current)
	for n in range(2, mini(abs_current, 9) + 1):
		if abs_current % n == 0:
			divisors.append(n)

	if divisors.is_empty():
		var fallback_plus: int = rng.randi_range(min_value, max_value)
		return {"op": "+", "value": fallback_plus, "result": current + fallback_plus}

	var div_value: int = divisors[rng.randi_range(0, divisors.size() - 1)]
	return {"op": "/", "value": div_value, "result": int(current / div_value)}


func generate_options(correct_answer: int) -> Array[int]:
	var target_count: int = GRID_INDEXES.size()
	var wrong_needed: int = target_count - 1
	var wrong_values: Array[int] = []
	var spread: int = maxi(2, mini(24, int(ceil(absf(float(correct_answer)) * 0.25)) + 2))

	# Build unique nearby distractors first.
	var offset: int = 1
	while wrong_values.size() < wrong_needed and offset <= 30:
		var delta: int = offset * spread / 3
		delta = maxi(1, delta)
		var low: int = correct_answer - delta
		var high: int = correct_answer + delta
		if low >= 0 and low != correct_answer and not wrong_values.has(low):
			wrong_values.append(low)
		if wrong_values.size() >= wrong_needed:
			break
		if high >= 0 and high != correct_answer and not wrong_values.has(high):
			wrong_values.append(high)
		offset += 1

	# Deterministic fallback to guarantee completion for any correct answer.
	var fallback: int = 0
	while wrong_values.size() < wrong_needed:
		if fallback != correct_answer and not wrong_values.has(fallback):
			wrong_values.append(fallback)
		fallback += 1

	wrong_values.shuffle()
	var options: Array[int] = [correct_answer]
	for value in wrong_values:
		options.append(value)
	options.shuffle()
	return options


func _on_answer_pressed(index: int) -> void:
	if input_locked:
		return

	input_locked = true
	stop_round_countdown()
	for i in GRID_INDEXES:
		var button := answer_buttons[i] as Button
		button.disabled = true

	var is_correct := index == current_correct_index
	if is_correct:
		correct_sfx_player.play()
		consecutive_misses = 0
	else:
		wrong_sfx_player.play()
		register_miss()
	await flash_feedback(index, is_correct)

	if is_correct:
		streak += 1
		var points_earned: int = 1
		if streak % 3 == 0:
			points_earned += 2
			combo_bonus_sfx_player.play()
			show_status_badge("Combo +2!")
		score += points_earned
		update_high_score_if_needed()
	else:
		streak = 0
		var penalty_applied: bool = apply_wrong_outcome()
		if not penalty_applied:
			update_hud()
			resume_current_round_after_shield_save(false)
			return

	update_hud()

	if chances <= 0:
		show_game_over()
		return

	if not is_correct:
		await reveal_correct_answer(CORRECT_REVEAL_DURATION)
		start_new_round()
		return

	await get_tree().create_timer(0.22).timeout
	start_new_round()

func apply_wrong_outcome() -> bool:
	if shield_armed:
		shield_armed = false
		show_status_badge("Shield saved you!")
		return false
	chances -= 1
	return true


func resume_current_round_after_shield_save(from_timeout: bool) -> void:
	if from_timeout:
		round_time_left = maxi(2, round_time_left)

	for i in GRID_INDEXES:
		var button := answer_buttons[i] as Button
		if button == null:
			continue
		if button.modulate.a < 0.5:
			continue
		button.disabled = false

	input_locked = false
	update_hud()
	start_round_countdown()


func _on_hint_powerup_pressed() -> void:
	if hint_uses <= 0 or input_locked:
		return

	var wrong_indices: Array[int] = []
	for i in GRID_INDEXES:
		if i == current_correct_index:
			continue
		var button := answer_buttons[i] as Button
		if button == null or button.disabled:
			continue
		wrong_indices.append(i)

	wrong_indices.shuffle()
	var remove_count: int = mini(2, wrong_indices.size())
	for idx in range(remove_count):
		var remove_index: int = wrong_indices[idx]
		var remove_button := answer_buttons[remove_index] as Button
		remove_button.disabled = true
		remove_button.modulate = Color(1.0, 1.0, 1.0, 0.38)

	hint_uses -= 1
	assist_item_sfx_player.play()
	show_status_badge("Hint used")
	update_hud()


func _on_slow_powerup_pressed() -> void:
	if slow_uses <= 0 or input_locked:
		return

	round_time_left = mini(round_time_left + 2, MAX_TIME_LIMIT + 2)
	round_time_limit = maxi(round_time_limit, round_time_left)
	slow_uses -= 1
	assist_item_sfx_player.play()
	show_status_badge("+2 seconds")
	update_hud()


func _on_shield_powerup_pressed() -> void:
	if shield_uses <= 0 or shield_armed or input_locked:
		return

	shield_uses -= 1
	shield_armed = true
	assist_item_sfx_player.play()
	show_status_badge("Shield ready")
	update_hud()


func _on_assist_visibility_toggled(pressed: bool) -> void:
	assist_items_visible = pressed
	if powerup_bar == null:
		return
	powerup_bar.visible = pressed and (welcome_overlay == null or not welcome_overlay.visible) and (options_overlay == null or not options_overlay.visible)
	update_board_size()
	update_hud()
	save_progress()


func _on_questions_per_level_changed(value: float) -> void:
	questions_per_level = int(value)
	save_progress()


func show_status_badge(message: String) -> void:
	if status_badge_panel == null or status_badge_label == null:
		return
	if status_badge_tween != null and status_badge_tween.is_running():
		status_badge_tween.kill()
	status_badge_label.text = message
	status_badge_panel.visible = true
	status_badge_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	status_badge_tween = create_tween()
	status_badge_tween.tween_property(status_badge_panel, "modulate:a", 1.0, 0.12)
	status_badge_tween.tween_interval(0.55)
	status_badge_tween.tween_property(status_badge_panel, "modulate:a", 0.0, 0.2)
	status_badge_tween.tween_callback(func() -> void:
		status_badge_panel.visible = false
	)



func update_high_score_if_needed() -> void:
	if score > high_score:
		high_score = score
		save_progress()


func load_progress() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	if err != OK:
		high_score = 0
		questions_per_level = 10
		assist_items_visible = false
		return
	high_score = int(cfg.get_value(SAVE_SECTION, SAVE_KEY_HIGH_SCORE, 0))
	questions_per_level = int(cfg.get_value(SAVE_SECTION, SAVE_KEY_QUESTIONS_PER_LEVEL, 10))
	questions_per_level = clampi(questions_per_level, 3, 12)
	assist_items_visible = bool(cfg.get_value(SAVE_SECTION, SAVE_KEY_ASSIST_VISIBLE, false))
	if assist_toggle_button != null:
		assist_toggle_button.button_pressed = assist_items_visible


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SAVE_SECTION, SAVE_KEY_HIGH_SCORE, high_score)
	cfg.set_value(SAVE_SECTION, SAVE_KEY_QUESTIONS_PER_LEVEL, questions_per_level)
	cfg.set_value(SAVE_SECTION, SAVE_KEY_ASSIST_VISIBLE, assist_items_visible)
	cfg.save(SAVE_PATH)


func register_miss() -> void:
	consecutive_misses += 1
	if consecutive_misses >= 2:
		assist_rounds_left = 2
		consecutive_misses = 0


func reveal_correct_answer(duration_sec: float) -> void:
	var panel := cell_panels[current_correct_index] as PanelContainer
	if panel == null:
		await get_tree().create_timer(duration_sec).timeout
		return

	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		await get_tree().create_timer(duration_sec).timeout
		return

	var original := style.duplicate() as StyleBoxFlat
	var correct_style := style.duplicate() as StyleBoxFlat
	correct_style.bg_color = Color(0.14, 0.60, 0.23)
	correct_style.border_color = Color(0.08, 0.38, 0.15)
	correct_style.border_width_left = 5
	correct_style.border_width_top = 5
	correct_style.border_width_right = 5
	correct_style.border_width_bottom = 5
	panel.add_theme_stylebox_override("panel", correct_style)

	var correct_button := answer_buttons[current_correct_index] as Button
	if correct_button != null:
		correct_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		correct_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		correct_button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		position_correct_hint_label()
		correct_hint_label.text = "Correct answer should be: %s" % correct_button.text
		correct_hint_label.visible = true
		correct_hint_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	await get_tree().create_timer(duration_sec).timeout
	panel.add_theme_stylebox_override("panel", original)
	if correct_button != null:
		correct_button.add_theme_color_override("font_color", Color(0.06, 0.10, 0.16))
		correct_button.add_theme_color_override("font_hover_color", Color(0.06, 0.10, 0.16))
		correct_button.add_theme_color_override("font_pressed_color", Color(0.06, 0.10, 0.16))
	correct_hint_label.visible = false


func flash_feedback(index: int, is_correct: bool) -> void:
	var panel := cell_panels[index] as PanelContainer
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var original := style.duplicate() as StyleBoxFlat
	var feedback := style.duplicate() as StyleBoxFlat
	feedback.bg_color = Color(0.66, 0.95, 0.66) if is_correct else Color(1.0, 0.72, 0.72)
	panel.add_theme_stylebox_override("panel", feedback)
	await get_tree().create_timer(0.18).timeout
	panel.add_theme_stylebox_override("panel", original)


func update_hud() -> void:
	score_label.text = "Score: %d" % score
	high_score_label.text = "Best: %d" % high_score
	chances_label.text = "Chances: %d" % chances
	level_label.text = "Level: %d" % level
	streak_label.text = "Streak: %d" % streak
	time_label.text = "Time: %d" % round_time_left
	hint_button.text = "Hint (%d)" % hint_uses
	slow_button.text = "+2s (%d)" % slow_uses
	shield_button.text = "Shield (%d)" % shield_uses
	hint_button.disabled = hint_uses <= 0 or input_locked
	slow_button.disabled = slow_uses <= 0 or input_locked
	shield_button.disabled = shield_uses <= 0 or shield_armed or input_locked
	refresh_assist_item_colors()
	if shield_armed:
		shield_button.text = "Shield ON"
	var time_color: Color = TIME_COLOR_URGENT if (round_time_left <= URGENT_TIME_THRESHOLD and not input_locked) else TIME_COLOR_NORMAL
	time_label.add_theme_color_override("font_color", time_color)
	if round_time_left <= URGENT_TIME_THRESHOLD and not input_locked:
		start_time_pulse()
	else:
		stop_time_pulse()


func refresh_assist_item_colors() -> void:
	var active_bg := Color(0.12, 0.62, 0.74)
	var active_text := Color(0.97, 0.99, 1.0)
	var used_bg := Color(0.64, 0.64, 0.64)
	var used_text := Color(0.18, 0.18, 0.18)

	apply_assist_item_style(hint_button, hint_uses > 0, active_bg, active_text, used_bg, used_text)
	apply_assist_item_style(slow_button, slow_uses > 0, active_bg, active_text, used_bg, used_text)
	apply_assist_item_style(shield_button, shield_uses > 0, active_bg, active_text, used_bg, used_text)


func apply_assist_item_style(button: Button, is_active: bool, active_bg: Color, active_text: Color, used_bg: Color, used_text: Color) -> void:
	if button == null:
		return
	var bg: Color = active_bg if is_active else used_bg
	var text_color: Color = active_text if is_active else used_text
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.corner_radius_bottom_left = 8
	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = bg.darkened(0.15)
	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = bg.lightened(0.08)
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("disabled", style_normal)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)


func start_time_pulse() -> void:
	if time_pulse_tween != null and time_pulse_tween.is_running():
		return
	time_label.scale = Vector2.ONE
	time_pulse_tween = create_tween()
	time_pulse_tween.set_loops()
	time_pulse_tween.tween_property(time_label, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	time_pulse_tween.tween_property(time_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_time_pulse() -> void:
	if time_pulse_tween != null and time_pulse_tween.is_running():
		time_pulse_tween.kill()
	time_pulse_tween = null
	time_label.scale = Vector2.ONE


func show_game_over() -> void:
	input_locked = true
	stop_round_countdown()
	stop_time_pulse()
	for i in GRID_INDEXES:
		var button := answer_buttons[i] as Button
		button.disabled = true
	game_over_label.text = "Game Over\nFinal Score: %d" % score
	game_over_overlay.visible = true


func _on_restart_pressed() -> void:
	game_over_overlay.visible = false
	begin_new_game()


func _on_back_to_welcome_pressed() -> void:
	if game_over_overlay != null:
		game_over_overlay.visible = false
	show_welcome_screen()
