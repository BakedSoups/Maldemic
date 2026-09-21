extends Node2D
var DIR = OS.get_executable_path().get_base_dir()
var interpreter_path = "res://Python_Brain/venv/Scripts/python"
var script_path = "res://Python_Brain/preload.py"
var is_day_processing := false
@onready var graph_node = get_parent().chart
@onready var current_city := "SF"
var previous_city := ""
var previous_day := -1
var debug_flight_processing = true
var city_node_cache = {}

var queued_days := 0
var max_queued_days := 5
var processing_queue := false
var active_terminals := []

var is_auto_running := false
var auto_run_timer: Timer

func _ready():
	if !OS.has_feature("standalone"):
		interpreter_path = ProjectSettings.globalize_path("res://Python_Brain/venv/Scripts/python")
		script_path = ProjectSettings.globalize_path("res://Python_Brain/preload.py")
	
	print("Starting simulation...")
	var cached = JSON.parse_string(FileAccess.get_file_as_string("res://Python_Brain/pandemic_simulation.json"))
	if cached is Dictionary:
		Data.dict_names = cached
	
	cache_city_nodes()
	
	var timer = get_tree().create_timer(0.5)
	await timer.timeout
	
	if Data.day_count <= 0:
		_on_day_add_button_down()
		await get_tree().create_timer(0.5).timeout
	
	Data.Current_City = "SF"
	
	_show_sf_graph()

func process_day_queue() -> void:
	processing_queue = true
	
	while queued_days > 0:
		queued_days -= 1
		
		cleanup_active_terminals()
		
		Data.day_count += 1
		var rich_text = $"../Day Counter"
		rich_text.text = "Days: " + str(Data.day_count)
		
		create_test_flight()
		
		await get_tree().create_timer(0.3).timeout
	
	processing_queue = false

func cleanup_active_terminals() -> void:
	var terminals_to_remove = []
	
	for terminal in active_terminals:
		if is_instance_valid(terminal):
			terminals_to_remove.append(terminal)
	
	for terminal in terminals_to_remove:
		terminal.queue_free()
	
	active_terminals.clear()

func _show_sf_graph():
	if !graph_node:
		return
		
	graph_node.visible = true
	
	var current_city = "SF"  
	var current_day = "day_" + str(Data.day_count)
	
	if Data.day_count <= 0 or not Data.dict_names.has(current_day):
		print("No day data available yet")
		return
		
	var city_day = Data.dict_names[current_day]
	
	if not city_day.has(current_city):
		print("No SF data for day " + str(Data.day_count))
		return

	var city_stats = city_day[current_city]["sir_history"]

	Data.Current_S = city_stats[0]
	Data.Current_I = city_stats[1]
	Data.Current_R = city_stats[2]
	Data.Current_D = city_stats[3]
	
	for child in graph_node.get_children():
		child.queue_free()

	graph_node.update_graph()
	print("SF graph displayed for day " + str(Data.day_count))
		
func _process(_delta):
	var current_city = Data.Current_City
	var current_day = Data.day_count
	

	if current_city != previous_city or current_day != previous_day:
		_update_graph_if_valid(current_city, current_day)
		previous_city = current_city
		previous_day = current_day
		
func notify(title="", subtitle="", body=""):
	var output = []
	var exit_code = OS.execute(interpreter_path, [script_path, title, subtitle, body], output, true)
	var names = FileAccess.get_file_as_string("res://Python_Brain/pandemic_simulation.json")
	var dict_names = JSON.parse_string(names)
	print("Exit code: ", exit_code)
	print("Output: ", output)
	
	Data.dict_names = dict_names

func cache_city_nodes():
	var city_codes = ["SF", "CHI", "NYC", "LA", "MA", "WA", "LON", "PA"]
	var buildings_node = get_parent().globe.find_child("Buildings", true, false)
	
	if not buildings_node:
		return
	
	for code in city_codes:
		var city_node = buildings_node.get_node_or_null(code)
		if city_node:
			city_node_cache[code] = city_node

# Updated day add button handler
func _on_day_add_button_down() -> void:
	if not Data.dict_names.has("day_" + str(Data.day_count + queued_days + 1)):
		if is_auto_running:
			_on_run_stop_button_down()
		return
	if queued_days >= max_queued_days:
		print("Maximum days queued. Please wait.")
		return
	
	queued_days += 1
	
	if not processing_queue:
		process_day_queue()

func _update_graph_if_valid(city: String, day: int) -> void:
	if day <= 0:
		return

	var current_day = "day_" + str(day)
	var dict_day = Data.dict_names.get(current_day, null)
	if not dict_day or not dict_day.has(city):
		return

	var city_stats = dict_day[city]["sir_history"]

	Data.Current_S = city_stats[0]
	Data.Current_I = city_stats[1]
	Data.Current_R = city_stats[2]
	Data.Current_D = city_stats[3]

	if graph_node:
		for child in graph_node.get_children():
			child.queue_free()
		graph_node.update_graph()

func _on_show_graph_button_down() -> void:
	if graph_node:
		graph_node.visible = not graph_node.visible
		
		if graph_node.visible:
			var current_city = Data.Current_City
			var current_day = "day_" + str(Data.day_count)
			
			if Data.day_count <= 0 or not Data.dict_names.has(current_day):
				return
				
			var city_day = Data.dict_names[current_day]
			
			if not city_day.has(current_city):
				return

			var city_stats = city_day[current_city]["sir_history"]

			Data.Current_S = city_stats[0]
			Data.Current_I = city_stats[1]
			Data.Current_R = city_stats[2]
			Data.Current_D = city_stats[3]
			
			for child in graph_node.get_children():
				child.queue_free()

			graph_node.update_graph()

func _on_day_back_button_down() -> int:
	if processing_queue or Data.day_count <= 1:
		print("Already at the first day, or a step is processing")
		return -1
	
	Data.day_count -= 1
	var rich_text = $"../Day Counter"
	
	rich_text.text = "Days: " + str(Data.day_count) 
	return 0

func process_sir_values(transit_data, from_city, to_city, passengers_per_plane, plane_terminal):
	var s_count = passengers_per_plane
	var i_count = 0
	var r_count = 0
	
	for transit in transit_data:
		if transit["from_city"] == from_city and transit["to_city"] == to_city:
			var ratio = passengers_per_plane / transit["total"]
			s_count = transit["s_count"] * ratio
			i_count = transit["i_count"] * ratio
			r_count = transit["r_count"] * ratio
			
			#print("Route: " + from_city + " -> " + to_city)
			#print("Source data: S=" + str(transit["s_count"]) + ", I=" + str(transit["i_count"]) + ", R=" + str(transit["r_count"]))
			break
	
	var original_total = s_count + i_count + r_count
	i_count = i_count * 4  
	s_count = max(0, s_count + (original_total - (s_count + i_count + r_count)))
	
	plane_terminal.passenger_count = s_count + i_count + r_count
	plane_terminal.s_count = s_count
	plane_terminal.i_count = i_count
	plane_terminal.r_count = r_count
	
	var infection_percent = (i_count / plane_terminal.passenger_count * 100) if plane_terminal.passenger_count > 0 else 0
	if infection_percent >= 10.0:
		print("HIGH INFECTION: " + from_city + "->" + to_city + " (" + str(infection_percent) + "%)")
	
	return infection_percent

# Updated create_test_flight function
func create_test_flight() -> void:
	var buildings_node = get_parent().globe.find_child("Buildings", true, false)
	if not buildings_node:
		buildings_node = load("res://scenes/buildings/buildings.tscn").instantiate()
		add_child(buildings_node)
	
	var airport_terminal = buildings_node.get_node_or_null("Airport_Terminal")
	if not airport_terminal:
		print("ERROR: Could not find Airport_Terminal within buildings node")
		return
	
	var current_day = "day_" + str(Data.day_count)
	if not Data.dict_names.has(current_day) or not Data.dict_names[current_day].has("movements"):
		print("No movement data for day: " + current_day)
		return
	
	var movements = Data.dict_names[current_day]["movements"][current_day]
	var in_transit_data = Data.dict_names[current_day]["in_transit"]
	
	var flight_data = []
	var total_planes = 0
	var MAX_TOTAL_PLANES = 35
	var MAX_PLANES_PER_ROUTE = 5
	
	movements.sort_custom(func(a, b): return a.total > b.total)
	
	for movement in movements:
		if movement["total"] < 5000:
			continue
			
		var num_planes = min(max(1, int(movement["total"] / 7000)), MAX_PLANES_PER_ROUTE)
		
		if total_planes + num_planes > MAX_TOTAL_PLANES:
			num_planes = max(0, MAX_TOTAL_PLANES - total_planes)
			if num_planes == 0:
				continue
		
		total_planes += num_planes
		flight_data.append({
			"from": movement["from_city"],
			"to": movement["to_city"],
			"total": movement["total"],
			"planes": num_planes
		})
		
		if total_planes >= MAX_TOTAL_PLANES:
			break
	
	var terminals = []
	
	for flight in flight_data:
		var passengers_per_plane = flight.total / flight.planes
		
		for i in range(flight.planes):
			var new_terminal = airport_terminal.duplicate()
			new_terminal.name = "Terminal_" + flight.from + "_to_" + flight.to + "_" + str(i) + "_" + str(Data.day_count)
			new_terminal.debug_mode = false
			new_terminal.auto_start_flight = false
			buildings_node.add_child(new_terminal)
			
			process_sir_values(in_transit_data, flight.from, flight.to, passengers_per_plane, new_terminal)
			
			new_terminal.plane_directions(flight.from, flight.to, 1.0)
			terminals.append(new_terminal)
			active_terminals.append(new_terminal)  # Track this terminal
			
		await get_tree().create_timer(0.05).timeout
	
	for terminal in terminals:
		if is_instance_valid(terminal):
			terminal.is_flight_active = true
		await get_tree().create_timer(0.05).timeout
	

func create_instant_flight() -> void:
	var buildings_node = get_parent().globe.find_child("Buildings", true, false)
	if not buildings_node:
		buildings_node = load("res://scenes/buildings/buildings.tscn").instantiate()
		add_child(buildings_node)
	
	var airport_terminal = buildings_node.get_node_or_null("Airport_Terminal")
	if not airport_terminal:
		print("ERROR: Could not find Airport_Terminal within buildings node")
		return
	
	var current_day = "day_" + str(Data.day_count)
	if not Data.dict_names.has(current_day) or not Data.dict_names[current_day].has("movements"):
		print("No movement data for day: " + current_day)
		return
	
	var movements = Data.dict_names[current_day]["movements"][current_day]
	var in_transit_data = Data.dict_names[current_day]["in_transit"]
	
	movements.sort_custom(func(a, b): return a.total > b.total)
	
	var flight_data = []
	var flight_count = min(5, movements.size())
	
	for i in range(flight_count):
		if i >= movements.size():
			break
			
		var movement = movements[i]
		if movement["total"] < 5000:
			continue
		
		flight_data.append({
			"from": movement["from_city"],
			"to": movement["to_city"],
			"total": movement["total"],
			"planes": 1
		})
	
	for flight in flight_data:
		var total_passengers = flight.total
		var passengers_per_plane = 1000.0
		
		var num_planes = int(ceil(total_passengers / passengers_per_plane))
		num_planes = clamp(num_planes, 1, 8)
		
		var passengers_per_actual_plane = total_passengers / num_planes
		
		for i in range(num_planes):
			var new_terminal = airport_terminal.duplicate()
			new_terminal.name = "Terminal_" + flight.from + "_to_" + flight.to + "_" + str(i) + "_" + str(Data.day_count)
			new_terminal.debug_mode = false 
			new_terminal.auto_start_flight = false
			new_terminal.current_destination = flight.to
			buildings_node.add_child(new_terminal)
			active_terminals.append(new_terminal)  
			
			process_sir_values(in_transit_data, flight.from, flight.to, passengers_per_actual_plane, new_terminal)
			
			new_terminal.plane_directions(flight.from, flight.to, 1.0)
			new_terminal.is_flight_active = true
			
			_schedule_cleanup(new_terminal, 10.0 + i * 0.5)
			await get_tree().create_timer(0.05).timeout
	
	print("Created instant flight for day " + str(Data.day_count))

func _schedule_cleanup(terminal, delay):
	var timer = get_tree().create_timer(delay)
	await timer.timeout
	if is_instance_valid(terminal):
		terminal.queue_free()
		var index = active_terminals.find(terminal)
		if index != -1:
			active_terminals.remove_at(index)

func print_node_hierarchy(node, indent = "- "):
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		print_node_hierarchy(child, indent + "  ")
func _on_run_stop_button_down() -> void:
	# Playback state is reflected by the dashboard.
	
	if is_auto_running:
		is_auto_running = false
		if auto_run_timer:
			auto_run_timer.stop()
			auto_run_timer.queue_free()
			auto_run_timer = null
		print("Auto-run stopped")
	else:
		is_auto_running = true
		auto_run_timer = Timer.new()
		auto_run_timer.wait_time = 1.0  
		auto_run_timer.one_shot = false
		auto_run_timer.timeout.connect(_on_auto_run_timer_timeout)
		add_child(auto_run_timer)
		auto_run_timer.start()
		print("Auto-run started")

func _on_auto_run_timer_timeout() -> void:
	if is_auto_running:
		if is_day_processing or processing_queue:
			print("Day processing in progress, waiting...")
			return
			
		var all_flights_completed = true
		var terminals_to_remove = []
		for terminal in active_terminals:
			if !is_instance_valid(terminal):
				terminals_to_remove.append(terminal)
				
		for terminal in terminals_to_remove:
			var index = active_terminals.find(terminal)
			if index != -1:
				active_terminals.remove_at(index)
		
		for terminal in active_terminals:
			if !terminal.flight_completed:
				all_flights_completed = false
				break
				
		if !all_flights_completed:
			print("Waiting for flights to complete...")
			return
			
		_on_day_add_button_down()
