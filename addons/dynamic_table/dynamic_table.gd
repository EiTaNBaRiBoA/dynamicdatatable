@tool
extends Control
class_name DynamicTable

signal cell_selected(row, column)
signal header_clicked(column)
signal column_resized(column, new_width)

# Table properties
@export var headers: Array[String] = []
@export var header_height: float = 35.0
@export var header_color: Color = Color(0.2, 0.2, 0.2)
@export var default_minimum_column_width: float = 100.0
@export var row_height: float = 30.0
@export var grid_color: Color = Color(0.8, 0.8, 0.8)
@export var selected_back_color: Color = Color(0.0, 0.0, 1.0, 0.5)
@export var selected_mode_row : bool = true
@export var font_color: Color = Color(1.0, 1.0, 1.0)
@export var row_color: Color = Color(0.55, 0.55, 0.55, 1.0) 
@export var alternate_row_color: Color = Color(0.45, 0.45, 0.45, 1.0)

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

# Node references
var _h_scroll: HScrollBar
var _v_scroll: VScrollBar

var font = get_theme_default_font()
var font_size = get_theme_default_font_size()

func _ready():
		
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
	# controlla che le righe abbiano la dimensione del numero di colonne, al contrario aggiunge un valore predefinito per riportare
	# il numero delle colonne della riga coincidente con quello delle colonne totali (definite dall'header)
	var blank = null
	for row in _data:
		while row.size() < _total_columns:
			row.append(blank)
	
	for row in range(_total_rows):
		for col in range (_total_columns):
			var header_size = font.get_string_size(str(headers[col]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var data_size = font.get_string_size(str(_data[row][col]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			if (_column_widths[col] < max(header_size.x, data_size.x)):
				_column_widths[col] = max(header_size.x, data_size.x) + font_size * 4
				_min_column_widths[col] = _column_widths[col]
			
	_update_scrollbars()
	queue_redraw()

func _is_date_string(value: String) -> bool:
	var date_regex = RegEx.new()
	date_regex.compile("^\\d{2}/\\d{2}/\\d{4}$")
	return date_regex.search(value) != null

func _is_date_column(column_index: int) -> bool:
	# Controlla se la maggior parte dei valori della colonna sono date nel formato gg/mm/aaaa
	var match_count = 0
	var total = 0
	for row in _data:
		if column_index >= row.size():
			continue
		var value = str(row[column_index])
		total += 1
		if _is_date_string(value):
			match_count += 1
	return (total > 0 and match_count > total / 2) # soglia: più della metà sono date

func _parse_date(date_str: String) -> Array:
	var parts = date_str.split("/")
	if parts.size() != 3:
		return [0, 0, 0]
	var day = int(parts[0])
	var month = int(parts[1])
	var year = int(parts[2])
	return [year, month, day]

func ordering_data(column_index: int, ascending: bool = true, selected_row: int = -1) -> int:
	_last_column_sorted = column_index
	if _is_date_column(column_index):
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
	else:
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
	if selected_row >= 0:
		var sel_val = _data[selected_row]
		for i in range(_data.size()):
			if _data[i] == sel_val:
				return i
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
	var total_height = int(_total_rows) * float(row_height)  # Converti esplicitamente
	_v_scroll.visible = total_height > visible_height
	if _v_scroll.visible:
		_v_scroll.max_value = total_height 
		_v_scroll.page = visible_height
		_v_scroll.step = row_height
	
	
func _on_h_scroll_changed(value):
	_h_scroll_position = value
	queue_redraw()

func _on_v_scroll_changed(value):
	_v_scroll_position = value
	_visible_rows_range[0] = floor(value / row_height) 
	_visible_rows_range[1] = _visible_rows_range[0] + floor((size.y - header_height) / row_height) + 1
	_visible_rows_range[1] = min(_visible_rows_range[1], _total_rows) 
	queue_redraw()

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
		if x_pos + _column_widths[col] > 0 and x_pos  < visible_width:
			# Disegna il bordo dell'header
			draw_line(Vector2(x_pos, 0), Vector2(x_pos, header_height), grid_color)
			var rectwidth = x_pos + _column_widths[col]
			if (rectwidth  > visible_width ):
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
			if (divider_x  < visible_width):
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
			cell_x += _column_widths[col]
			
			# Se la cella è visibile
			if cell_x  < visible_width:
				# Disegna il bordo sinistro della cella
				draw_line(Vector2(cell_x, row_y), Vector2(cell_x, row_y + row_height), grid_color)
				
				# Disegna il bordo destro dell'ultima colonna
				#if col == _total_columns - 1:
					#draw_line(Vector2(cell_x + _column_widths[col], row_y), 
							 # Vector2(cell_x + _column_widths[col], row_y + row_height), grid_color)
						
				# Evidenzia la cella selezionata
				if _selected_cell[0] == row and _selected_cell[1] == col:
					if (!selected_mode_row):			# evidenzia cella singola
						draw_rect(Rect2(cell_x, row_y, _column_widths[col], row_height-1), selected_back_color)
					else:								# evidenzia intera riga
						var dimx = 0
						for c in range(_column_widths.size()):
							dimx += _column_widths[c]
						draw_rect(Rect2(x_offset, row_y, visible_width - x_offset, row_height-1), selected_back_color)
				
				# Disegna il testo della cella
				var cell_value = ""
				if row < _data.size() and col < _data[row].size():
					cell_value = str(_data[row][col])
				
				var h_align = _align_text_in_cell(col)[1]
				var x_margin = _align_text_in_cell(col)[2]
				
				if (!selected_mode_row):			# scrive cella singola
					var text_size = font.get_string_size(cell_value, h_align, _column_widths[col], font_size)
					draw_string(font, Vector2(cell_x + x_margin, row_y + row_height/2 + text_size.y/2 - (font_size/2 - 2)), cell_value, h_align, _column_widths[col], font_size, font_color)
				else:
					if (col == 0): # scrive una sola volta
						_selected_cell[1] = 0
						var c_x = x_offset
						for c in range(_total_columns):
							var c_value = ""
							if row < _data.size() and c < _data[row].size():
								c_value = str(_data[row][c])
							h_align = _align_text_in_cell(c)[1]
							x_margin = _align_text_in_cell(c)[2]
							var text_size = font.get_string_size(c_value, h_align, _column_widths[c], font_size)
							if c_x  < visible_width:
								draw_string(font, Vector2(c_x + x_margin, row_y + row_height/2 + text_size.y/2 - (font_size/2 - 2)), c_value, h_align, _column_widths[c], font_size, font_color)
								c_x += _column_widths[c]
							
func _align_text_in_cell(col: int):
	var header_content = headers[col].split("|")
	var _h_alignment = header_content[1] if (header_content.size() > 1 and header_content[1].length() == 1) else ""
	var header_text = header_content[0]
	var h_align = HORIZONTAL_ALIGNMENT_LEFT
	var x_margin = 5
	if (_h_alignment == "c" or _h_alignment == "C"):		# cener
		h_align = HORIZONTAL_ALIGNMENT_CENTER
		x_margin = 0
	elif (_h_alignment == "r" or _h_alignment == "R"):	# right
		h_align = HORIZONTAL_ALIGNMENT_RIGHT
		x_margin = -5
	return [header_text, h_align, x_margin]

func _on_gui_input(event):
	# Gestisce il clic sull'header o sulle celle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = event.position
				
				# Verifica se il clic è sull'header
				if mouse_pos.y < header_height:
					_handle_header_click(mouse_pos)
				else:
					_handle_cell_click(mouse_pos)
				
				# Inizia il ridimensionamento della colonna
				if _mouse_over_divider >= 0:
					_resizing_column = _mouse_over_divider
					_resizing_start_pos = mouse_pos.x
					_resizing_start_width = _column_widths[_resizing_column]
			else:
				# Fine del ridimensionamento
				_resizing_column = -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_v_scroll.value = max(0, _v_scroll.value - _v_scroll.step * 1) # scorri su (originale -> * 3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_v_scroll.value = min(_v_scroll.max_value, _v_scroll.value + _v_scroll.step * 1) # scorri giu	(originale -> * 3)
			
	# Gestisce il trascinamento per ridimensionare le colonne
	elif event is InputEventMouseMotion:
		var mouse_pos = event.position
		# Verifica il ridimensionamento della colonna
		
		if (_resizing_column >= 0 and _resizing_column < headers.size() - 1):
			var delta_x = mouse_pos.x - _resizing_start_pos
			var new_width = max(_resizing_start_width + delta_x, _min_column_widths[_resizing_column])
			_column_widths[_resizing_column] = new_width
			_update_scrollbars()
			column_resized.emit(_resizing_column, new_width)
			queue_redraw()
		# Altrimenti verifica se il mouse è sopra un divisore di colonna
		else: #elif mouse_pos.y < header_height:
			_check_mouse_over_divider(mouse_pos)

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
				row =  _visible_rows_range[1] - _visible_rows_range[0] + row - 1
				_v_scroll.value = min(_v_scroll.max_value,  _v_scroll.value + (row - _visible_rows_range[1] + 1) * _v_scroll.step * 1 )
			else:
				row = _data.size() - 1
				_v_scroll.value = _v_scroll.max_value 
		# Key Page Up
		if event.pressed and event.keycode == KEY_PAGEUP: 
			if (row > _visible_rows_range[0] - 1 and _visible_rows_range[0] > 0):
				row = - _visible_rows_range[1] + _visible_rows_range[0] + row + 1
				_v_scroll.value = max(0, _v_scroll.value + (row - _visible_rows_range[1] + 1) * _v_scroll.step * 1 )
			else:
				row = 0
				_v_scroll.value = 0
		# Key Home
		elif event.pressed and event.keycode == KEY_HOME:
			row = 0
			_v_scroll.value = 0 
		# Key End
		elif event.pressed and event.keycode == KEY_END:
			row = _data.size() - 1
			_v_scroll.value = _v_scroll.max_value 
		# Key ESC
		elif event.pressed and event.keycode == KEY_ESCAPE:
			row = -1
			col = -1
		_selected_cell = [row, col]
		cell_selected.emit(row, col)
		queue_redraw()
	
func _check_mouse_over_divider(mouse_pos):
	_mouse_over_divider = -1
	var x_offset = -_h_scroll_position
	
	for col in range(_total_columns - 1):
		var divider_x = x_offset + _column_widths[col]
		if abs(mouse_pos.x - divider_x) < _divider_width:
			_mouse_over_divider = col
			mouse_default_cursor_shape = Control.CURSOR_HSPLIT
			break
		x_offset += _column_widths[col]
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		
	queue_redraw()

func _handle_header_click(mouse_pos):
	var x_offset = -_h_scroll_position
	
	for col in range(_total_columns):
		var col_x = x_offset
		var col_width = _column_widths[col]
		
		if mouse_pos.x >= col_x + _divider_width and mouse_pos.x < col_x + col_width - _divider_width:
			header_clicked.emit(col)
			break
		
		x_offset += col_width

func _handle_cell_click(mouse_pos):
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
	
	if col >= 0 and row >= 0:
		_selected_cell = [row, col]
		cell_selected.emit(row, col)
		queue_redraw()
