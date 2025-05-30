extends Control

# Reference to dynamic table
@onready var dynamic_table = $DynamicTable

var headers						# array of columns header
var data						# array of data, rows and columns

func _ready():
	# Set table header
	headers = ["ID|C", "Name", "Lastname", "Age|r", "Job", "City", "Date", "Work|p", "Completed|check"]
	dynamic_table.set_headers(headers)
	
	# Example data
	data = [
		[1, "Michael", "Smith", 34, "Engineer", "London", "10/12/2005", 0.5, 1],
		[2, "Louis", "Johnson", 28, "Doctor", "New York", "05/11/2023", 0],
		[3, "Ann", "Williams", 42, "Lawyer", "Tokyo", "18/03/2025", 0, 0],
		[4, "John", "Brown", 31, "Teacher", "Sydney", "02/07/2024", 0, 0],
		[5, "Frances", "Jones", 25, "Designer", "Paris", "29/09/2023", 0, 0],
		[6, "Robert", "", 39, "Architect", "Berlin", "14/01/2026", 0, 0],
		[7, "Lucy", "Davis", 36, "Accountant", "Madrid", "07/04/2024", 0, 0],
		[8, "Mark", "Miller", 44, "Entrepreneur", "Toronto", "21/08/2025", 0, 0],
		[9, "Paula", "Wilson", 29, "Journalist", "Rio de Janeiro", "10/12/2023", 0, 0],
		[10, "Stephen", "Moore", 33, "Programmer", "Dubai", "30/11/2024", 0, 0],
		[11, "Mark", "Jefferson", 31, "Dentist", "Lisbona", "10/02/2018", 0.47, 1],
		[12, "James", "Taylor", 28, "Doctor", "Chicago", "03/06/2026", 0, 0],
		[13, "Carmen", "Anderson", 42, "Lawyer", "Hong Kong", "25/02/2024", 0, 0],
		[14, "John", "Thomas", 39, "Architect", "Amsterdam", "17/10/2025", 0, 0],
		[15, "Paul", "Jackson", 44, "Entrepreneur", "Singapore", "09/05/2023", 0, 0],
		[16, "Jennifer", "White", 29, "Journalist", "Cape Town", "01/03/2023", 0, 0],
		[17, "Luke", "Harris", 33, "Programmer", "Seoul", "28/04/2023", 0, 0],
		[18, "Peter", "Martin", 25, "Designer", "Mexico City", "11/08/2024", 0, 0],
		[19, "Matthew", "Thompson", 39, "Architect", "Moscow", "13/09/2024", 0, 0],
		[20, "Louise", "Garcia", 36, "Accountant", "Istanbul", "04/12/2025", 0, 0],
		[21, "Matthew", "Martinez", 44, "Entrepreneur", "Buenos Aires", "06/01/2025", 0, 0],
		[22, "Stephanie", "Robinson", 29, "Journalist", "Cairo", "22/07/2023", 0, 0],
		[23, "Christopher", "Clark", 51, "Architect", "Tokyo", "12/05/2021", 0, 0],
		[24, "Amanda", "Rodriguez", 33, "Graphic Designer", "Sydney", "11/03/2020", 0, 0],
		[25, "Daniel", "Lewis", 47, "Software Engineer", "Berlin", "03/04/2023", 0, 0],
		[26, "Victoria", "Lee", 28, "Marketing Specialist", "Toronto", "04/05/2021", 0, 0],
		[27, "Joseph", "Walker", 55, "Professor", "London", "12/05/2021", 0, 0],
		[28, "Ashley", "Young", 39, "Chef", "Paris", "22/05/2024", 0, 0],
		[29, "Kevin", "Allen", 42, "Financial Analyst", "Mexico City", "08/02/2025", 0, 0],
		[30, "Elizabeth", "King", 31, "Photographer", "Rome", "11/09/2020", 0, 0]
	]	

	# Insert data table
	dynamic_table.set_data(data)
	# Default order column 
	dynamic_table.ordering_data(0, true)  # 0 -> ID column and true -> ascending order
	
	# Signals connections
	dynamic_table.cell_selected.connect(_on_cell_selected)
	dynamic_table.cell_right_selected.connect(_on_cell_right_selected)
	dynamic_table.cell_edited.connect(_on_cell_edited)
	dynamic_table.header_clicked.connect(_on_header_clicked)
	dynamic_table.column_resized.connect(_on_column_resized)

# On selected cell callback
func _on_cell_selected(row, column):
	print("Cell selected on row ", row, ", column ", column)
	print("Cell value: ", dynamic_table.get_cell_value(row, column))
	print("Row value: ", dynamic_table.get_row_value(row))

# On right selected cell callback
func _on_cell_right_selected(row, column, mouse_pos):
	print("Cell right selected on row ", row, ", column ", column)
	print("Mouse position x: ", mouse_pos.x, " y: ", mouse_pos.y)
	
# On edited cell callback
func _on_cell_edited(row, column, old_value, new_value):
	print("Cell edited on row ", row, ", column ", column)
	print("Cell old value: ", old_value)
	print("Cell new value: ", new_value)
		
# On clicked header cell callback
func _on_header_clicked(column):
	print("Header clicked on column ", column)
	
# On resized column callback
func _on_column_resized(column, new_width):
	print("Column ", column, " resized at width ", new_width)
	
