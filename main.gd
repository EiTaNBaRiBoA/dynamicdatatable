extends Control

# Reference to dynamic table
@onready var dynamic_table = $DynamicTable

var headers						# array of columns header
var data						# array of data, rows and columns
var ordering = true				# default sorting direction, ascending 
var last_column = -1			# last sorted column
var selected_row = -1			# last selected row

func _ready():
	# Set table header
	headers = ["ID|C", "Name", "Lastname", "Age|r", "Job", "City", "Date"]
	dynamic_table.set_headers(headers)
	
	# Example data
	data = [
		[1, "Michael", "Smith", 34, "Engineer", "London", "10/12/2005"],
		[2, "Louis", "Johnson", 28, "Doctor", "New York", "05/11/2023"],
		[3, "Ann", "Williams", 42, "Lawyer", "Tokyo", "18/03/2025"],
		[4, "John", "Brown", 31, "Teacher", "Sydney", "02/07/2024"],
		[5, "Frances", "Jones", 25, "Designer", "Paris", "29/09/2023"],
		[6, "Robert", "", 39, "Architect", "Berlin", "14/01/2026"],
		[7, "Lucy", "Davis", 36, "Accountant", "Madrid", "07/04/2024"],
		[8, "Mark", "Miller", 44, "Entrepreneur", "Toronto", "21/08/2025"],
		[9, "Paula", "Wilson", 29, "Journalist", "Rio de Janeiro", "10/12/2023"],
		[10, "Stephen", "Moore", 33, "Programmer", "Dubai", "30/11/2024"],
		[12, "James", "Taylor", 28, "Doctor", "Chicago", "03/06/2026"],
		[13, "Carmen", "Anderson", 42, "Lawyer", "Hong Kong", "25/02/2024"],
		[14, "John", "Thomas", 39, "Architect", "Amsterdam", "17/10/2025"],
		[15, "Paul", "Jackson", 44, "Entrepreneur", "Singapore", "09/05/2023"],
		[16, "Jennifer", "White", 29, "Journalist", "Cape Town", "01/03/2023"],
		[17, "Luke", "Harris", 33, "Programmer", "Seoul", "28/04/2023"],
		[18, "Peter", "Martin", 25, "Designer", "Mexico City", "11/08/2024"],
		[19, "Matthew", "Thompson", 39, "Architect", "Moscow", "13/09/2024"],
		[20, "Louise", "Garcia", 36, "Accountant", "Istanbul", "04/12/2025"],
		[21, "Matthew", "Martinez", 44, "Entrepreneur", "Buenos Aires", "06/01/2025"],
		[22, "Stephanie", "Robinson", 29, "Journalist", "Cairo", "22/07/2023"],
		[23, "Christopher", "Clark", 51, "Architect", "Tokyo", "12/05/2021"],
		[24, "Amanda", "Rodriguez", 33, "Graphic Designer", "Sydney", "11/03/2020"],
		[25, "Daniel", "Lewis", 47, "Software Engineer", "Berlin", "03/04/2023"],
		[26, "Victoria", "Lee", 28, "Marketing Specialist", "Toronto", "04/05/2021"],
		[27, "Joseph", "Walker", 55, "Professor", "London", "12/05/2021"],
		[28, "Ashley", "Young", 39, "Chef", "Paris", "22/05/2024"],
		[29, "Kevin", "Allen", 42, "Financial Analyst", "Mexico City", "08/02/2025"],
		[30, "Elizabeth", "King", 31, "Photographer", "Rome", "11/09/2020"]
	]	

	# Insert data table
	dynamic_table.set_data(data)
	
	# Signals connections
	dynamic_table.cell_selected.connect(_on_cell_selected)
	dynamic_table.header_clicked.connect(_on_header_clicked)
	dynamic_table.column_resized.connect(_on_column_resized)

# On selected cell callback
func _on_cell_selected(row, column):
	print("Cell selected on row ", row, ", column ", column)
	print("Cell value: ", dynamic_table.get_cell_value(row, column))
	print("Row value: ", dynamic_table.get_row_value(row))
	selected_row = row

# On clicked header cell callback
func _on_header_clicked(column):
	print("Header clicked on column ", column)
	if (column == last_column):
		ordering = not ordering													# invert previous column sort direction
	else:
		ordering = true															# default sort ordering direction
	var new_row = dynamic_table.ordering_data(column, ordering, selected_row)
	selected_row = new_row														# restoring potential previous row selected
	last_column = column
	dynamic_table.set_selected_cell(new_row, last_column)						# select row at the nuew position

# On resized column callback
func _on_column_resized(column, new_width):
	print("Column ", column, " resized at width ", new_width)
	
