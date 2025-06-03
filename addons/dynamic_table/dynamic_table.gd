@tool
extends Control
class_name DynamicTable

signal cell_selected(row, column)
signal cell_right_selected(row, column, mousepos)
signal header_clicked(column)
signal column_resized(column, new_width)
signal progress_changed(row, column, new_value)
signal cell_edited(row, column, old_value, new_value)

# Table properties
@export var headers: Array[String] = []
@export var header_height: float = 35.0
@export var header_color: Color = Color(0.2, 0.2, 0.2)
@export var default_minimum_column_width: float = 50.0
@export var row_height: float = 30.0
@export var grid_color: Color = Color(0.8, 0.8, 0.8)
@export var selected_back_color: Color = Color(0.0, 0.0, 1.0, 0.5)
@export var selected_mode_row : bool = true
@export var font_color: Color = Color(1.0, 1.0, 1.0)
@export var row_color: Color = Color(0.55, 0.55, 0.55, 1.0)
@export var alternate_row_color: Color = Color(0.45, 0.45, 0.45, 1.0)
@export var checkbox_checked_color: Color = Color(0.0, 0.8, 0.0)
@export var checkbox_unchecked_color: Color = Color(0.8, 0.0, 0.0)
@export var checkbox_border_color: Color = Color(0.8, 0.8, 0.8)

# Progress bar properties
@export var progress_bar_start_color: Color = Color.RED
@export var progress_bar_middle_color: Color = Color.ORANGE
@export var progress_bar_end_color: Color = Color.FOREST_GREEN
@export var progress_background_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var progress_border_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var progress_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)

# Internal variables
var _data = []
var _column_widths = []
var _min_column_widths = []
var _total_rows = 0
var _total_columns = 0
var _visible_rows_range = [0, 0]
var _h_scroll_position = 0
var _v_scroll_position = 0
var _selected_cell = [-1, -1]
var _resizing_column = -1
var _resizing_start_pos = 0
var _resizing_start_width = 0
var _mouse_over_divider = -1
var _divider_width = 5
var _icon_sort = " ▼ "
var _last_column_sorted = -1
var _ascending = true
var _dragging_progress = false
var _progress_drag_row = -1
var _progress_drag_col = -1

# Editing variables
var _editing_cell = [-1, -1]
var _edit_line_edit: LineEdit
var _double_click_timer: Timer
var _click_count = 0
var _last_click_pos = Vector2.ZERO
var _double_click_threshold = 400 # milliseconds
var _click_position_threshold = 5 # pixels

# Node references
var _h_scroll: HScrollBar
var _v_scroll: VScrollBar

var font = get_theme_default_font()
var font_size = get_theme_default_font_size()

func _ready():
	# Initialize editing components
	_setup_editing_components()
		
	# Initialize scrollbars
	_h_scroll = HScrollBar.new()
	_h_scroll.name = "HScrollBar"
	_h_scroll.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_h_scroll.offset_top = -12
	_h_scroll.value_changed.connect(_on_h_scroll_changed)
	
	_v_scroll = VScrollBar.new()
	_v_scroll.name = "VScrollBar"
	_v_scroll.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	_v_scroll.offset_left = -12
	_v_scroll.value_changed.connect(_on_v_scroll_changed)
	
	add_child(_h_scroll)
	add_child(_v_scroll)
	
	# Set default column widths
	_update_column_widths()
	
	# Connect signals
	resized.connect(_on_resized)
	gui_input.connect(_on_gui_input)
	
	# Maximize area from parent control node
	self.anchor_left = 0.0
	self.anchor_top = 0.0
	self.anchor_right = 1.0
	self.anchor_bottom = 1.0
		
	# Force refresh drawing
	queue_redraw()

func _setup_editing_components():
	# Setup LineEdit for cell editing
	_edit_line_edit = LineEdit.new()
	_edit_line_edit.visible = false
	_edit_line_edit.text_submitted.connect(_on_edit_text_submitted)
	_edit_line_edit.focus_exited.connect(_on_edit_focus_exited)
	add_child(_edit_line_edit)
	
	# Setup double-click timer
	_double_click_timer = Timer.new()
	_double_click_timer.wait_time = _double_click_threshold / 1000.0
	_double_click_timer.one_shot = true
	_double_click_timer.timeout.connect(_on_double_click_timeout)
	add_child(_double_click_timer)

func _on_resized():
	_update_scrollbars()
	queue_redraw()

func _update_column_widths():
	_column_widths.resize(headers.size())
	_min_column_widths.resize(headers.size())
	for i in range(headers.size()):
		if i >= _column_widths.size() or _column_widths[i] == 0 or _column_widths[i] == null:
			_column_widths[i] = default_minimum_column_width
			_min_column_widths[i] = default_minimum_column_width
	_total_columns = headers.size()

func _is_date_string(value: String) -> bool:
	var date_regex = RegEx.new()
	date_regex.compile("^\\d{2}/\\d{2}/\\d{4}$")
	return date_regex.search(value) != null

func _is_date_column(column_index: int) -> bool:
	# Check if most of the column values ​​are dates in dd/mm/yyyy format
	var match_count = 0
	var total = 0
	for row in _data:
		if column_index >= row.size():
			continue
		var value = str(row[column_index])
		total += 1
		if _is_date_string(value):
			match_count += 1
	return (total > 0 and match_count > total / 2) # threshold: more than half are dates

func _is_progress_column(column_index: int) -> bool:
	# Check if header contains progress bar marker
	if column_index >= headers.size():
		return false
	var header_parts = headers[column_index].split("|")
	return header_parts.size() > 1 and (header_parts[1].to_lower().contains("p") or header_parts[1].to_lower().contains("progress"))

func _is_checkbox_column(column_index: int) -> bool:
	# Check if header contains checkbox marker
	if column_index >= headers.size():
		return false
	var header_parts = headers[column_index].split("|")
	return header_parts.size() > 1 and (header_parts[1].to_lower().contains("check") or header_parts[1].to_lower().contains("checkbox"))

func _is_numeric_value(value) -> bool:
	if value == null:
		return false
	var str_val = str(value)
	return str_val.is_valid_float() or str_val.is_valid_int()

func _get_progress_value(value) -> float:
	# Converts the value to a float between 0.0 and 1.0
	if value == null:
		return 0.0
	
	var num_val = 0.0
	if _is_numeric_value(value):
		num_val = float(str(value))
	
	# If the value is already between 0 and 1, we use it directly
	if num_val >= 0.0 and num_val <= 1.0:
		return num_val
	# If it's between 0 and 100, we convert it to a percentage.
	elif num_val >= 0.0 and num_val <= 100.0:
		return num_val / 100.0
	# Otherwise we limit it between 0 and 1
	else:
		return clamp(num_val, 0.0, 1.0)

func _parse_date(date_str: String) -> Array:
	var parts = date_str.split("/")
	if parts.size() != 3:
		return [0, 0, 0]
	var day = int(parts[0])
	var month = int(parts[1])
	var year = int(parts[2])
	return [year, month, day]

#-------------------------------------------------
#	Public methods
#-------------------------------------------------

func set_headers(new_headers: Array):
	var typed_headers: Array[String] = []
	for header in new_headers:
		typed_headers.append(String(header))

	headers = typed_headers
	_update_column_widths()
	_update_scrollbars()
	queue_redraw()

func set_data(new_data: Array):
	_data = new_data
	_total_rows = _data.size()
	_visible_rows_range = [0, min(_total_rows, floor(self.size.y / row_height))]
	# checks that the size of the rows coincides with the number of columns, 
	# otherwise it adds a default value to have the number of columns of the row 
	# coincide with total columns (defined by the header)
	var blank = false		# null value for compatibility with checkbox cell
	for row in _data:
		while row.size() < _total_columns:
			row.append(blank)
	
	for row in range(_total_rows):
		for col in range (_total_columns):
			var header_size = font.get_string_size(str(_get_header_text(col)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var data_size = Vector2.ZERO
			
			# Per le colonne progress e checkbox, consideriamo una larghezza minima maggiore
			if _is_progress_column(col):
				data_size = Vector2(default_minimum_column_width + 20, font_size) # Larghezza minima per progress bar
			elif _is_checkbox_column(col):
				data_size = Vector2(default_minimum_column_width - 50, font_size) # Larghezza minima per checkbox
			else:
				data_size = font.get_string_size(str(_data[row][col]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			
			if (_column_widths[col] < max(header_size.x, data_size.x)):
				_column_widths[col] = max(header_size.x, data_size.x) + font_size * 4
				_min_column_widths[col] = _column_widths[col]
			
	_update_scrollbars()
	queue_redraw()
	
func ordering_data(column_index: int, ascending: bool = true) -> int:
	# Termina l'editing se attivo
	_finish_editing(false)
	
	_last_column_sorted = column_index
		
	if _is_date_column(column_index):
		# Dates ordering
		_data.sort_custom(func(a, b):
			var a_val = _parse_date(str(a[column_index]))
			var b_val = _parse_date(str(b[column_index]))
			if ascending:
				_set_icon_down()
				return a_val < b_val
			else:
				_set_icon_up()
				return a_val > b_val
		)
	elif _is_progress_column(column_index):
		# Progress bar ordering
		_data.sort_custom(func(a, b):
			var a_val = _get_progress_value(a[column_index])
			var b_val = _get_progress_value(b[column_index])
			if ascending:
				_set_icon_down()
				return a_val < b_val
			else:
				_set_icon_up()
				return a_val > b_val
		)
	elif _is_checkbox_column(column_index):
		# Checkbox ordering (true before false, or vice-versa)
		_data.sort_custom(func(a, b):
			var a_val = bool(a[column_index])
			var b_val = bool(b[column_index])
			if ascending:
				_set_icon_down()
				# True values come first in ascending order
				return a_val and not b_val
			else:
				_set_icon_up()
				# False values come first in descending order
				return not a_val and b_val
		)
	else:
		# Text (or number) ordering
		_data.sort_custom(func(a, b):
			var a_val = a[column_index]
			var b_val = b[column_index]
			if ascending:
				_set_icon_down()
				return a_val < b_val
			else:
				_set_icon_up()
				return a_val > b_val
		)
	queue_redraw()
	return -1

func add_row(row_data: Array):
	_data.append(row_data)
	_total_rows += 1
	_update_scrollbars()
	queue_redraw()

func update_cell(row: int, column: int, value):
	if row >= 0 and row < _data.size() and column >= 0 and column < _total_columns:
		# Assicurati che la riga abbia abbastanza colonne
		while _data[row].size() <= column:
			_data[row].append("")
		_data[row][column] = value
		queue_redraw()

func get_cell_value(row: int, column: int):
	if row >= 0 and row < _data.size() and column >= 0 and column < _data[row].size():
		return _data[row][column]
	return null

func get_row_value(row: int):
	if row >= 0 and row < _data.size():
		return _data[row]
	return null

func set_selected_cell(row: int, col: int):
	_selected_cell = [row, col]

# Funzioni di utilità per le progress bar
func set_progress_value(row: int, column: int, value: float):
	if row >= 0 and row < _data.size() and column >= 0 and column < _total_columns:
		if _is_progress_column(column):
			_data[row][column] = clamp(value, 0.0, 1.0)
			queue_redraw()

func get_progress_value(row: int, column: int) -> float:
	if row >= 0 and row < _data.size() and column >= 0 and column < _data[row].size():
		if _is_progress_column(column):
			return _get_progress_value(_data[row][column])
	return 0.0

func set_progress_colors(bar_start_color: Color, bar_middle_color: Color, bar_end_color: Color, background_color: Color, border_color: Color, text_color: Color):
	progress_bar_start_color = bar_start_color
	progress_bar_middle_color = bar_middle_color
	progress_bar_end_color = bar_end_color
	progress_background_color = background_color
	progress_border_color = border_color
	progress_text_color = text_color
	queue_redraw()

#-------------------------------------------------

#-------------------------------------------------
#	Internal Methods
#-------------------------------------------------

# Editing methods

func _start_cell_editing(row: int, col: int):
	if _is_progress_column(col) or _is_checkbox_column(col):
		return # Do not permit editing on the progress bar or checkbox through text
	
	_editing_cell = [row, col]
	
	# Get cell position
	var cell_rect = _get_cell_rect(row, col)
	if cell_rect == Rect2():
		return # cell not visible
	
	# Set LineEdit on the cell
	_edit_line_edit.position = cell_rect.position
	_edit_line_edit.size = cell_rect.size
	_edit_line_edit.text = str(get_cell_value(row, col)) if get_cell_value(row, col) != null else ""
	_edit_line_edit.visible = true
	_edit_line_edit.grab_focus()
	_edit_line_edit.select_all()

func _finish_editing(save_changes: bool = true):
	if _editing_cell[0] >= 0 and _editing_cell[1] >= 0:
		if save_changes and _edit_line_edit.visible:
			var old_value = get_cell_value(_editing_cell[0], _editing_cell[1])
			var new_value = _edit_line_edit.text
			
			# Converti il valore se necessario
			if new_value.is_valid_int():
				new_value = int(new_value)
			elif new_value.is_valid_float():
				new_value = float(new_value)
			
			update_cell(_editing_cell[0], _editing_cell[1], new_value)
			cell_edited.emit(_editing_cell[0], _editing_cell[1], old_value, new_value)
		
		_editing_cell = [-1, -1]
		_edit_line_edit.visible = false
		queue_redraw()

func _get_cell_rect(row: int, col: int) -> Rect2:
	if row < _visible_rows_range[0] or row >= _visible_rows_range[1]:
		return Rect2() # Cella non visibile
	
	var x_offset = -_h_scroll_position
	var cell_x = x_offset
	
	# Calcola la posizione X della colonna
	for c in range(col):
		cell_x += _column_widths[c]
	
	# Verifica se la cella è visibile orizzontalmente
	var visible_width = size.x - (_v_scroll.size.x if _v_scroll.visible else 0)
	if cell_x + _column_widths[col] <= 0 or cell_x >= visible_width:
		return Rect2() # Cella non visibile
	
	# Calcola la posizione Y della riga
	var row_y = header_height + (row - _visible_rows_range[0]) * row_height
	
	return Rect2(cell_x, row_y, _column_widths[col], row_height)

func _on_edit_text_submitted(text: String):
	_finish_editing(true)

func _on_edit_focus_exited():
	_finish_editing(true)

func _on_double_click_timeout():
	_click_count = 0

#-------------------------------------------------
	
func _set_icon_down():
	_icon_sort = " ▼ "

func _set_icon_up():
	_icon_sort = " ▲ "
		
func _update_scrollbars():
	if not is_inside_tree():
		return

	# Controllo preventivo sui valori
	if _total_rows == null or row_height == null:
		_total_rows = 0 if _total_rows == null else _total_rows
		row_height = 30.0 if row_height == null else row_height

	var visible_width = size.x - (_v_scroll.size.x if _v_scroll.visible else 0)
	var visible_height = size.y - (_h_scroll.size.y if _h_scroll.visible else 0) - header_height

	# Calcola la larghezza totale della tabella
	var total_width = 0
	for width in _column_widths:
		if width != null:
			total_width += width

	# Aggiorna la barra di scorrimento orizzontale
	_h_scroll.visible = total_width > visible_width
	if _h_scroll.visible:
		_h_scroll.max_value = total_width
		_h_scroll.page = visible_width
		_h_scroll.step = default_minimum_column_width / 2

	# Aggiorna la barra di scorrimento verticale
	var total_height = int(_total_rows) * float(row_height) # Converti esplicitamente
	_v_scroll.visible = total_height > visible_height
	if _v_scroll.visible:
		_v_scroll.max_value = total_height
		_v_scroll.page = visible_height
		_v_scroll.step = row_height
	
func _on_h_scroll_changed(value):
	_h_scroll_position = value
	# Nascondi l'editor se è visibile durante lo scorrimento
	if _edit_line_edit.visible:
		_finish_editing(false)
	queue_redraw()

func _on_v_scroll_changed(value):
	_v_scroll_position = value
	_visible_rows_range[0] = floor(value / row_height)
	_visible_rows_range[1] = _visible_rows_range[0] + floor((size.y - header_height) / row_height) + 1
	_visible_rows_range[1] = min(_visible_rows_range[1], _total_rows)
	# Nascondi l'editor se è visibile durante lo scorrimento
	if _edit_line_edit.visible:
		_finish_editing(false)
	queue_redraw()

func _get_header_text(col: int) -> String:
	if col >= headers.size():
		return ""
	var header_content = headers[col].split("|")
	return header_content[0]

func _draw():
	if not is_inside_tree():
		return
	
	var x_offset = -_h_scroll_position
	var y_offset = header_height
	var visible_width = size.x - (_v_scroll.size.x if _v_scroll.visible else 0)
	
	# Disegna l'header
	draw_rect(Rect2(0, 0, size.x, header_height), header_color)
	
	# Disegna le celle dell'header
	for col in range(_total_columns):
		var x_pos = x_offset
		for c in range(col):
			x_pos += _column_widths[c]
		
		# Se la colonna è visibile
		if x_pos + _column_widths[col] > 0 and x_pos < visible_width:
			# Disegna il bordo dell'header
			draw_line(Vector2(x_pos, 0), Vector2(x_pos, header_height), grid_color)
			var rectwidth = x_pos + _column_widths[col]
			if (rectwidth > visible_width):
				rectwidth = visible_width
			draw_line(Vector2(x_pos, header_height), Vector2(rectwidth, header_height), grid_color)
			
			# Disegna il testo dell'header
			if col < headers.size():
				var header_text = _align_text_in_cell(col)[0]
				var h_align = _align_text_in_cell(col)[1]
				var x_margin = _align_text_in_cell(col)[2]
				var text_size = font.get_string_size(header_text, h_align, _column_widths[col], font_size)
				draw_string(font, Vector2(x_pos + x_margin, header_height/2 + text_size.y/2 - (font_size/2 - 2)), header_text, h_align, _column_widths[col], font_size, font_color)
				if (col == _last_column_sorted):
					var icon_align = HORIZONTAL_ALIGNMENT_LEFT
					if (h_align == HORIZONTAL_ALIGNMENT_LEFT or h_align == HORIZONTAL_ALIGNMENT_CENTER):
						icon_align = HORIZONTAL_ALIGNMENT_RIGHT
					draw_string(font, Vector2(x_pos, header_height/2 + text_size.y/2 - (font_size/2 - 1)), _icon_sort, icon_align, _column_widths[col], font_size/1.3, font_color)
	
			# Disegna il divisore trascinabile
			var divider_x = x_pos + _column_widths[col]
			if (divider_x < visible_width):
				draw_line(Vector2(divider_x, 0), Vector2(divider_x, header_height), grid_color, 2.0 if _mouse_over_divider == col else 1.0)
				
	# Disegna le righe di dati
	for row in range(_visible_rows_range[0], _visible_rows_range[1]):
		var row_y = y_offset + (row - _visible_rows_range[0]) * row_height
		
		# Set the row background color (thanks to BaconEggsRL)
		var bg_color = alternate_row_color if row % 2 == 1 else row_color
		draw_rect(Rect2(0, row_y, visible_width, row_height), bg_color)
		
		# Disegna il bordo inferiore della riga
		draw_line(Vector2(0, row_y + row_height), Vector2(visible_width, row_y + row_height), grid_color)
		
		# Disegna le celle
		x_offset = -_h_scroll_position
		var cell_x = x_offset
		for col in range(_total_columns):
			
			
			# Se la cella è visibile
			if cell_x < visible_width:
				# Disegna il bordo sinistro della cella
				draw_line(Vector2(cell_x, row_y), Vector2(cell_x, row_y + row_height), grid_color)
						
				# Evidenzia la cella selezionata (ma non se è in editing)
				if _selected_cell[0] == row and _selected_cell[1] == col and not (_editing_cell[0] == row and _editing_cell[1] == col):
					if (!selected_mode_row):			# evidenzia cella singola
						draw_rect(Rect2(cell_x, row_y, _column_widths[col], row_height-1), selected_back_color)
					else:								# evidenzia intera riga
						var dimx = 0
						for c in range(_column_widths.size()):
							dimx += _column_widths[c]
						draw_rect(Rect2(x_offset, row_y, visible_width - x_offset, row_height-1), selected_back_color)
				
				# Disegna il contenuto della cella solo se non è in editing
				if not (_editing_cell[0] == row and _editing_cell[1] == col):
					if _is_progress_column(col):
						_draw_progress_bar(cell_x, row_y, col, row)
					elif _is_checkbox_column(col):
						_draw_checkbox(cell_x, row_y, col, row)
					else:
						_draw_cell_text(cell_x, row_y, col, row)
				
				if (!selected_mode_row):			# scrive cella singola
					# Il contenuto è già disegnato sopra
					pass
				else:
					if (col == 0): # scrive una sola volta per tutte le colonne
						_selected_cell[1] = 0
						var c_x = x_offset
						for c in range(_total_columns):
							if c_x < visible_width:
								if not (_editing_cell[0] == row and _editing_cell[1] == c):
									if _is_progress_column(c):
										_draw_progress_bar(c_x, row_y, c, row)
									elif _is_checkbox_column(c):
										_draw_checkbox(c_x, row_y, c, row)
									else:
										_draw_cell_text(c_x, row_y, c, row)
								c_x += _column_widths[c]
				cell_x += _column_widths[col]
				# disegna il bordo destro della cella
				draw_line(Vector2(cell_x, row_y), Vector2(cell_x, row_y + row_height), grid_color)
				
func _draw_progress_bar(cell_x: float, row_y: float, col: int, row: int):
	
	var cell_value = 0.0
	if row < _data.size() and col < _data[row].size():
		cell_value = _get_progress_value(_data[row][col])
	
	var margin = 4
	var bar_x = cell_x + margin
	var bar_y = row_y + margin
	var bar_width = _column_widths[col] - (margin * 2)
	var bar_height = row_height - (margin * 2)
	
	# Disegna lo sfondo della progress bar
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), progress_background_color)
	
	# Disegna il bordo
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), progress_border_color, false, 1.0)
	
	# Disegna la barra di progresso
	var progress_width = bar_width * cell_value
	if progress_width > 0:
		draw_rect(Rect2(bar_x, bar_y, progress_width, bar_height), _get_interpolated_three_colors(progress_bar_start_color, progress_bar_middle_color, progress_bar_end_color, cell_value))
		
	# Disegna il testo percentuale
	var percentage_text = str(int(round(cell_value * 100))) + "%"
	var text_size = font.get_string_size(percentage_text, HORIZONTAL_ALIGNMENT_CENTER, bar_width, font_size)
	draw_string(font, Vector2(bar_x + bar_width/2 - text_size.x/2, bar_y + bar_height/2 + text_size.y/2 - 5), percentage_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, progress_text_color)

func _draw_checkbox(cell_x: float, row_y: float, col: int, row: int):
	var cell_value = false
	if row < _data.size() and col < _data[row].size():
		cell_value = bool(_data[row][col])
	
	var checkbox_size = min(row_height, _column_widths[col]) * 0.6
	var x_offset_centered = cell_x + (_column_widths[col] - checkbox_size) / 2
	var y_offset_centered = row_y + (row_height - checkbox_size) / 2
	
	var checkbox_rect = Rect2(x_offset_centered, y_offset_centered, checkbox_size, checkbox_size)
	
	# Draw checkbox background
	draw_rect(checkbox_rect, checkbox_border_color, false, 1.0)
	
	# Draw checkmark if true
	if cell_value:
		var fill_rect = checkbox_rect.grow(-checkbox_size * 0.15)
		draw_rect(fill_rect, checkbox_checked_color)
	else:
		var fill_rect = checkbox_rect.grow(-checkbox_size * 0.15)
		draw_rect(fill_rect, checkbox_unchecked_color)

func _get_interpolated_three_colors(start_color: Color, mid_color: Color, end_color: Color, t: float) -> Color:
	# Clampa il valore 't' per assicurarti che sia sempre tra 0.0 e 1.0
	var clamped_t = clampf(t, 0.0, 1.0)

	if clamped_t <= 0.5:
		# Se t è nella prima metà (da 0.0 a 0.5), interpola tra start_color e mid_color.
		# Dobbiamo "normalizzare" t per questa metà, moltiplicandolo per 2.
		# Esempio: se clamped_t è 0.25, il fattore per lerp sarà 0.5.
		var new_t = clamped_t * 2.0
		return start_color.lerp(mid_color, new_t)
	else:
		# Se t è nella seconda metà (da 0.5 a 1.0), interpola tra mid_color e end_color.
		# Dobbiamo sottrarre 0.5 e poi moltiplicare per 2 per normalizzare t per questa metà.
		# Esempio: se clamped_t è 0.75, (0.75 - 0.5) = 0.25, e 0.25 * 2.0 = 0.5.
		var new_t = (clamped_t - 0.5) * 2.0
		return mid_color.lerp(end_color, new_t)

func _draw_cell_text(cell_x: float, row_y: float, col: int, row: int):
	var cell_value = ""
	if row < _data.size() and col < _data[row].size():
		cell_value = str(_data[row][col])
	
	var h_align = _align_text_in_cell(col)[1]
	var x_margin = _align_text_in_cell(col)[2]
	
	var text_size = font.get_string_size(cell_value, h_align, _column_widths[col], font_size)
	draw_string(font, Vector2(cell_x + x_margin, row_y + row_height/2 + text_size.y/2 - (font_size/2 - 2)), cell_value, h_align, _column_widths[col], font_size, font_color)
			
func _align_text_in_cell(col: int):
	var header_content = headers[col].split("|")
	var _h_alignment = ""
	if header_content.size() > 1:
		# Estrae solo il carattere di allineamento, ignorando "p" o "progress" o "check"
		for char in header_content[1].to_lower():
			if char in ["l", "c", "r"]:
				_h_alignment = char
				break
	
	var header_text = header_content[0]
	var h_align = HORIZONTAL_ALIGNMENT_LEFT
	var x_margin = 5
	if (_h_alignment == "c"):		# center
		h_align = HORIZONTAL_ALIGNMENT_CENTER
		x_margin = 0
	elif (_h_alignment == "r"):	# right
		h_align = HORIZONTAL_ALIGNMENT_RIGHT
		x_margin = -5
	return [header_text, h_align, x_margin]

func _on_gui_input(event):
	# Gestisce il clic sull'header o sulle celle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = event.position
				
				# Gestione del doppio click
				if _click_count == 1 and _double_click_timer.time_left > 0 and _last_click_pos.distance_to(mouse_pos) < _click_position_threshold:
					_click_count = 0
					_double_click_timer.stop()
					_handle_double_click(mouse_pos)
				else:
					_click_count = 1
					_last_click_pos = mouse_pos
					_double_click_timer.start()

					# Verifica se il clic è sull'header
					if mouse_pos.y < header_height:
						_handle_header_click(mouse_pos)
					else:
						# Verifica se il clic è su una checkbox
						if _handle_checkbox_click(mouse_pos):
							pass # La checkbox ha gestito il clic
						else:
							_handle_cell_click(mouse_pos)
							# Verifica se il clic è su una progress bar
							if _is_clicking_progress_bar(mouse_pos):
								_dragging_progress = true
					
					# Inizia il ridimensionamento della colonna
					if _mouse_over_divider >= 0:
						_resizing_column = _mouse_over_divider
						_resizing_start_pos = mouse_pos.x
						_resizing_start_width = _column_widths[_resizing_column]
			else:
				# Fine del ridimensionamento e del trascinamento progress
				_resizing_column = -1
				_dragging_progress = false
				_progress_drag_row = -1
				_progress_drag_col = -1
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: 
				var mouse_pos = event.position
				_handle_right_click(mouse_pos)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_v_scroll.value = max(0, _v_scroll.value - _v_scroll.step * 1) # scorri su (originale -> * 3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_v_scroll.value = min(_v_scroll.max_value, _v_scroll.value + _v_scroll.step * 1) # scorri giu	(originale -> * 3)
			
	# Gestisce il trascinamento per ridimensionare le colonne e modificare progress bar
	elif event is InputEventMouseMotion:
		var mouse_pos = event.position
		
		# Gestisce il trascinamento delle progress bar
		if _dragging_progress and _progress_drag_row >= 0 and _progress_drag_col >= 0:
			_handle_progress_drag(mouse_pos)
		# Verifica il ridimensionamento della colonna
		elif (_resizing_column >= 0 and _resizing_column < headers.size() - 1):
			var delta_x = mouse_pos.x - _resizing_start_pos
			var new_width = max(_resizing_start_width + delta_x, _min_column_widths[_resizing_column])
			_column_widths[_resizing_column] = new_width
			_update_scrollbars()
			column_resized.emit(_resizing_column, new_width)
			queue_redraw()
		# Altrimenti verifica se il mouse è sopra un divisore di colonna
		else:
			_check_mouse_over_divider(mouse_pos)

func _is_clicking_progress_bar(mouse_pos: Vector2) -> bool:
	if mouse_pos.y < header_height:
		return false
	
	var row = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
	if row >= _total_rows:
		return false
	
	var x_offset = -_h_scroll_position
	var col = -1
	
	for c in range(_total_columns):
		if mouse_pos.x >= x_offset and mouse_pos.x < x_offset + _column_widths[c]:
			col = c
			break
		x_offset += _column_widths[c]
	
	if col >= 0 and _is_progress_column(col):
		_progress_drag_row = row
		_progress_drag_col = col
		return true
	
	return false

func _handle_progress_drag(mouse_pos: Vector2):
	if _progress_drag_row < 0 or _progress_drag_col < 0:
		return
	
	# Calcola la posizione relativa nella progress bar
	var x_offset = -_h_scroll_position
	for c in range(_progress_drag_col):
		x_offset += _column_widths[c]
	
	var margin = 4
	var bar_x = x_offset + margin
	var bar_width = _column_widths[_progress_drag_col] - (margin * 2)
	
	# Calcola il nuovo valore della progress bar
	var relative_x = mouse_pos.x - bar_x
	var new_progress = clamp(relative_x / bar_width, 0.0, 1.0)
	
	# Aggiorna il valore nella tabella
	if _progress_drag_row < _data.size() and _progress_drag_col < _data[_progress_drag_row].size():
		_data[_progress_drag_row][_progress_drag_col] = new_progress
		progress_changed.emit(_progress_drag_row, _progress_drag_col, new_progress)
		queue_redraw()

func _handle_checkbox_click(mouse_pos: Vector2) -> bool:
	if mouse_pos.y < header_height:
		return false
	
	var row = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
	if row >= _total_rows:
		return false
	
	var x_offset = -_h_scroll_position
	var col = -1
	
	for c in range(_total_columns):
		if mouse_pos.x >= x_offset and mouse_pos.x < x_offset + _column_widths[c]:
			col = c
			break
		x_offset += _column_widths[c]
	
	if col >= 0 and _is_checkbox_column(col):
		var old_value = get_cell_value(row, col)
		var new_value = not bool(old_value)
		update_cell(row, col, new_value)
		cell_edited.emit(row, col, old_value, new_value)
		return true
	
	return false

func _unhandled_input(event):
	if event is InputEventKey and _selected_cell[0] >= 0:
		var row = _selected_cell[0]
		var col = _selected_cell[1]
		# Key Down
		if event.pressed and event.keycode == KEY_DOWN and row < _data.size() - 1:
			row += 1
			if (row > _visible_rows_range[1] - 1):
				_v_scroll.value = min(_v_scroll.max_value, _v_scroll.value + _v_scroll.step * 1)
		# Key Up
		elif event.pressed and event.keycode == KEY_UP and row > 0:
			row -= 1
			if (row < _visible_rows_range[0]):
				_v_scroll.value = max(0, _v_scroll.value - _v_scroll.step * 1)
		# Key Page Down
		if event.pressed and event.keycode == KEY_PAGEDOWN:
			if (row < _data.size() - _visible_rows_range[1] + _visible_rows_range[0] - 1):
				row = _visible_rows_range[1] - _visible_rows_range[0] + row - 1
				_v_scroll.value = min(_v_scroll.max_value, _v_scroll.value + (row - _visible_rows_range[1] + 1) * _v_scroll.step * 1 )
			else:
				row = _data.size() - 1
				_v_scroll.value = _v_scroll.max_value
		# Key Page Up
		elif event.pressed and event.keycode == KEY_PAGEUP:
			if (row > _visible_rows_range[1] - _visible_rows_range[0] - 1):
				row = row - (_visible_rows_range[1] - _visible_rows_range[0] - 1)
				_v_scroll.value = max(0, _v_scroll.value - (_visible_rows_range[0] - row) * _v_scroll.step * 1 )
			else:
				row = 0
				_v_scroll.value = 0
		# Key Right
		elif event.pressed and event.keycode == KEY_RIGHT and col < _total_columns - 1:
			col += 1
		# Key Left
		elif event.pressed and event.keycode == KEY_LEFT and col > 0:
			col -= 1
		# Key Home
		elif event.pressed and event.keycode == KEY_HOME:
			row = 0
			col = 0
			_v_scroll.value = 0
		# Key End
		elif event.pressed and event.keycode == KEY_END:
			row = _data.size() - 1
			col = _total_columns - 1
			_v_scroll.value = _v_scroll.max_value
		# Key ESC
		elif event.pressed and event.keycode == KEY_ESCAPE:
			row = -1
			col = -1
		_selected_cell = [row, col]
		queue_redraw()

#-------------------------------------------------
#  Muse button events
#-------------------------------------------------

# Header click
func _handle_header_click(mouse_pos: Vector2):
	var x_offset = -_h_scroll_position
	var clicked_column = -1
	
	for col in range(_total_columns):
		if mouse_pos.x >= x_offset + _divider_width and mouse_pos.x < x_offset + _column_widths[col] - _divider_width:
			clicked_column = col
			break
		x_offset += _column_widths[col]
	
	if clicked_column >= 0:
		if _last_column_sorted == clicked_column:
			_ascending = !(_ascending)
			if (_ascending):
				_set_icon_down()
			else:
				_set_icon_up()
		else:
			_ascending = true
		
		var selected_row = _selected_cell[0]
		var last_data = null
		if selected_row >= 0 and selected_row < _data.size():
			last_data = _data[selected_row]

		ordering_data(clicked_column, _ascending)
		
		if selected_row >= 0 and last_data != null:
			for i in range(_data.size()):
				if _data[i] == last_data:
					_selected_cell = [i, 0]
					break
			
		header_clicked.emit(clicked_column)
		queue_redraw()

# Click on cell
func _handle_cell_click(mouse_pos: Vector2):
	var row = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
	if row >= _total_rows:
		return
	
	var x_offset = -_h_scroll_position
	var col = -1
	
	for c in range(_total_columns):
		if mouse_pos.x >= x_offset and mouse_pos.x < x_offset + _column_widths[c]:
			col = c
			break
		x_offset += _column_widths[c]
	
	if col >= 0:
		_selected_cell = [row, col]
		cell_selected.emit(row, col)
		queue_redraw()

# Double click on cell
func _handle_double_click(mouse_pos: Vector2):
	# Determina se il doppio click è avvenuto su una cella di dati
	if mouse_pos.y >= header_height:
		var row = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
		var col = -1
		var x_offset = -_h_scroll_position
		for c in range(_total_columns):
			if mouse_pos.x >= x_offset and mouse_pos.x < x_offset + _column_widths[c]:
				col = c
				break
			x_offset += _column_widths[c]
		
		if row >= 0 and row < _total_rows and col >= 0 and col < _total_columns:
			# Avvia l'editing della cella se non è una colonna progress o checkbox
			if not (_is_progress_column(col) or _is_checkbox_column(col)):
				_start_cell_editing(row, col)
	# Se il doppio click è sull'header, puoi aggiungere logica specifica qui se necessario
	elif mouse_pos.y < header_height:
		# Potresti voler implementare un'azione specifica per il doppio click sull'header
		# ad esempio, reset della larghezza della colonna o ordinamento avanzato.
		print("Double click on header")

# Right click on cell
func _handle_right_click(mouse_pos: Vector2):
	var row = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
	if row >= _total_rows or row < 0:  # (row < 0) exscludes header row
		return
	
	var x_offset = -_h_scroll_position
	var col = -1
	
	for c in range(_total_columns):
		if mouse_pos.x >= x_offset and mouse_pos.x < x_offset + _column_widths[c]:
			col = c
			break
		x_offset += _column_widths[c]
	
	if col >= 0:
		_selected_cell = [row, col]
		cell_right_selected.emit(row, col, mouse_pos)
		queue_redraw()
		
func _check_mouse_over_divider(mouse_pos):
	_mouse_over_divider = -1
	var x_offset = -_h_scroll_position
	
	for col in range(_total_columns - 1):
		var divider_x = x_offset + _column_widths[col]
		if abs(mouse_pos.x - divider_x) < _divider_width:
			_mouse_over_divider = col
			mouse_default_cursor_shape = Control.CURSOR_HSPLIT
			return
		x_offset += _column_widths[col]
	mouse_default_cursor_shape = Control.CURSOR_ARROW

	queue_redraw()
