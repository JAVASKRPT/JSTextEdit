extends Control

@onready var tab_container: TabContainer = $TabContainer
@onready var new_button: Button = $VBoxContainer/HBoxContainer/New
@onready var open_button: Button = $VBoxContainer/HBoxContainer/OpenButton
@onready var save_button: Button = $VBoxContainer/HBoxContainer/SaveButton
@onready var close_button: Button = $VBoxContainer/HBoxContainer/CloseButton
@onready var search_bar: LineEdit = $VBoxContainer/HBoxContainer/SearchBar
@onready var search_next_button: Button = $VBoxContainer/HBoxContainer/SearchNext
@onready var background: TextureRect = $Background
@onready var toggle_theme_button: Button = $VBoxContainer/HBoxContainer/ToggleThemeButton

var light_texture = preload("res://bg.png")
var dark_texture = preload("res://bgdark.png")
var using_dark = false

var file_paths: Dictionary = {}

func _ready() -> void:
	new_button.pressed.connect(_on_new_pressed)
	open_button.pressed.connect(_on_open_pressed)
	save_button.pressed.connect(_on_save_pressed)
	close_button.pressed.connect(_on_close_pressed)
	search_bar.text_submitted.connect(_on_search_submitted)
	search_next_button.pressed.connect(_on_find_next_pressed)
	toggle_theme_button.pressed.connect(_on_toggle_theme_pressed)
	background.texture = light_texture

func _on_toggle_theme_pressed() -> void:
	using_dark = !using_dark
	background.texture = dark_texture if using_dark else light_texture


func _on_new_pressed() -> void:
	_add_script_tab("New", "")

func _on_open_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.gd"]
	add_child(dialog)
	dialog.popup_centered()
	dialog.file_selected.connect(func(path: String):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			_add_script_tab(path.get_file(), content, path)
	)

func _on_save_pressed() -> void:
	var current_tab = tab_container.current_tab
	var editor = tab_container.get_child(current_tab) as CodeEdit
	var path = file_paths.get(current_tab, "")

	if path == "":
		var dialog := FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = ["*.gd"]
		add_child(dialog)
		dialog.popup_centered()
		dialog.file_selected.connect(func(p: String):
			var file := FileAccess.open(p, FileAccess.WRITE)
			file.store_string(editor.text)
			file_paths[current_tab] = p
		)
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(editor.text)

func _on_close_pressed() -> void:
	var current_tab := tab_container.current_tab
	if current_tab == -1:
		return
	_on_tab_close_requested(current_tab)

func _add_script_tab(name: String, content: String, path: String = "") -> void:
	var editor := CodeEdit.new()
	editor.name = name
	editor.text = content
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.custom_minimum_size = Vector2(1520, 1130)

	tab_container.add_child(editor)
	var index := tab_container.get_child_count() - 1
	tab_container.set_tab_title(index, name + "  ✖")
	tab_container.current_tab = index
	file_paths[index] = path

func _on_tab_close_requested(tab_index: int) -> void:
	file_paths.erase(tab_index)
	var tab = tab_container.get_child(tab_index)
	tab_container.remove_child(tab)
	tab.queue_free()
	var new_paths := {}
	for i in range(tab_container.get_child_count()):
		new_paths[i] = file_paths.get(i, "")
	file_paths = new_paths

func _on_search_submitted(query: String) -> void:
	_find_and_jump_to(query, true)

func _on_find_next_pressed() -> void:
	var query = search_bar.text
	_find_and_jump_to(query, false)

func _find_and_jump_to(query: String, from_start: bool = false) -> void:
	if query == "":
		return

	var editor = tab_container.get_current_tab_control()
	if editor == null or not editor is CodeEdit:
		return

	var text = editor.text
	var start_index = 0

	if not from_start:
		var current_line = editor.get_caret_line()
		var current_column = editor.get_caret_column()
		var offset = 0
		for i in range(current_line):
			var line_text = editor.get_line(i)
			offset += line_text.length() + 1
		offset += current_column
		start_index = offset

	var found = text.find(query, start_index)
	if found == -1 and not from_start:
		found = text.find(query)

	if found >= 0:
		var running_index = 0
		for i in range(editor.get_line_count()):
			var line_text = editor.get_line(i)
			var line_len = line_text.length() + 1
			if running_index + line_len > found:
				var column = found - running_index
				editor.set_caret_line(i)
				editor.set_caret_column(column)
				editor.select(i, column, i, column + query.length())
				editor.grab_focus()
				return
			running_index += line_len

	print("No match found.")
