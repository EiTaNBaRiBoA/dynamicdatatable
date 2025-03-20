# DynamicDataTable for Godot 4

DynamicDataTable is a GDScript plugin for Godot 4 that allows you to create and manage dynamic data tables easily and flexibly.

![Table example](https://github.com/jospic/dynamicdatatable/blob/master/ex_table_1.png))

## Features

* Dynamically create tables with customizable headers and data.
* Dynamic resizing column widths.
* Support for various data types (strings, numbers).
* Column sorting in ascending or descending order.
* Independent horizontal alignment for columns (left, center or right)
* Mouse events on headers and data cells
* Keyboard events on selected row (cursor up/down, page up/down, home, end)
* Appearance customization through themes and styles.
* Compatibility from Godot 4.3.

## Installation

1.  Download the plugin as a ZIP archive.
2.  Extract the archive to the `addons` folder of your Godot project.
3.  Enable the plugin from the `Project Settings > Plugins` menu.

## Usage

1.  Add a `DynamicDataTable` node to your scene, as child of a Control node.
2.  Add script to Control node and create a data array representing the table rows.
3.  Set the column headers using the `set_headers()` method.
4.  Set the table data using the `set_data()` method.
5.  Customize the table appearance through the Inspector properties.

or

Download this entire Godot Project and run the main scene (example.tscn)

## Code Example

```gdscript
extends Control

# Reference to dynamic table
@onready var dynamic_table = $DynamicTable

var headers				# array of columns header
var data				# array of data, rows and columns
var ordering = true		# default sorting direction, ascending 
var last_column = -1	# last sorted column
var selected_row = -1	# last selected row

func _ready():
	# Set table header
	headers = ["ID|C", "Name", "Lastname", "Age|r", "Job", "City"] # use |align for alignment columns (l, c, r or L, C, R)
	dynamic_table.set_headers(headers)
	
	# Example data
	data = [
		[1, "Michael", "Smith", 34, "Engineer", "London"],
		[2, "Louis", "Johnson", 28, "Doctor", "New York"],
		[3, "Ann", "Williams", 42, "Lawyer", "Tokyo"],
		[4, "John", "Brown", 31, "Teacher", "Sydney"],
		[5, "Frances", "Jones", 25, "Designer", "Paris"],
		[6, "Robert", "", 39, "Architect", "Berlin"],
		[7, "Lucy", "Davis", 36, "Accountant", "Madrid"],
		[8, "Mark", "Miller", 44, "Entrepreneur", "Toronto"],
		[9, "Paula", "Wilson", 29, "Journalist", "Rio de Janeiro"],
		[10, "Stephen", "Moore", 33, "Programmer", "Dubai"],
		[12, "James", "Taylor", 28, "Doctor", "Chicago"],
		[13, "Carmen", "Anderson", 42, "Lawyer", "Hong Kong"],
		[14, "John", "Thomas", 39, "Architect", "Amsterdam"],
		[15, "Paul", "Jackson", 44, "Entrepreneur", "Singapore"],
		[16, "Jennifer", "White", 29, "Journalist", "Cape Town"],
		[17, "Luke", "Harris", 33, "Programmer", "Seoul"],
		[18, "Peter", "Martin", 25, "Designer", "Mexico City"],
		[19, "Matthew", "Thompson", 39, "Architect", "Moscow"],
		[20, "Louise", "Garcia", 36, "Accountant", "Istanbul"],
		[21, "Matthew", "Martinez", 44, "Entrepreneur", "Buenos Aires"],
		[22, "Stephanie", "Robinson", 29, "Journalist", "Cairo"],
		[23, "Christopher", "Clark", 51, "Architect", "Tokyo"],
		[24, "Amanda", "Rodriguez", 33, "Graphic Designer", "Sydney"],
		[25, "Daniel", "Lewis", 47, "Software Engineer", "Berlin"],
		[26, "Victoria", "Lee", 28, "Marketing Specialist", "Toronto"],
		[27, "Joseph", "Walker", 55, "Professor", "London"],
		[28, "Ashley", "Young", 39, "Chef", "Paris"],
		[29, "Kevin", "Allen", 42, "Financial Analyst", "Mexico City"],
		[30, "Elizabeth", "King", 31, "Photographer", "Rome"]
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
		ordering = not ordering			# invert previous column sort direction
	else:
		ordering = true				# default sort ordering direction
	var new_row = dynamic_table.ordering_data(column, ordering, selected_row)
	selected_row = new_row				# restoring potential previous row selected
	last_column = column 
	dynamic_table._selected_cell = [new_row, last_column] # select row at the nuew position

# On resized column callback
func _on_column_resized(column, new_width):
	print("Column ", column, " resized at width ", new_width)
	
