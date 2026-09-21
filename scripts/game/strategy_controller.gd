extends Node2D

signal snapshot
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Scheduler = preload("res://scripts/visuals/flight_scheduler.gd")
const Saves = preload("res://scripts/game/save_game.gd")
var simulation := Simulation.new()
var scheduler := Scheduler.new()
var clock := 0.0
var speed := 1.0
var is_auto_running := false
var city_node_cache := {}
var visible_flights := {}
var previous_city := ""

func _ready() -> void:
	var buildings = get_parent().globe.find_child("Buildings", true, false)
	for code in ["SF", "CHI", "LON", "MA", "WA", "PA", "NYC"]:
		city_node_cache[code] = buildings.get_node(code)
	simulation.changed.connect(publish)
	start()

func start(seed_value := 42, city := "SF", loadout := "Drifter", difficulty := "Standard", tutorial := true) -> void:
	is_auto_running = false
	clock = 0.0
	cleanup_active_terminals()
	scheduler.flights.clear()
	Data.Current_City = city
	simulation.start(seed_value, city, loadout, difficulty, tutorial)

func _process(delta: float) -> void:
	if is_auto_running:
		advance(delta * speed / simulation.balance.seconds_per_day)
	if previous_city != Data.Current_City:
		publish()

func advance(days: float) -> void:
	var target := clock + days
	while floor(target + 0.000000001) > simulation.state.day and simulation.state.ending == "":
		clock = simulation.state.day + 1.0
		simulation.step()
		scheduler.schedule(simulation.state.day, simulation.state.routes, simulation.state.seed)
	if simulation.state.ending != "":
		is_auto_running = false
	else:
		clock = maxf(target, simulation.state.day)
	render_flights()

func _on_day_add_button_down() -> void:
	if simulation.state.ending == "":
		advance(floor(clock) + 1.0 - clock)

func _on_day_back_button_down() -> int:
	return -1 # Strategy history is immutable; use restart to replay a seed.

func _on_run_stop_button_down() -> void:
	if simulation.state.ending == "":
		is_auto_running = not is_auto_running

func publish() -> void:
	var s: Dictionary = simulation.state
	if s.is_empty():
		return
	var day := {}
	for code in s.regions:
		var histories := [[], [], [], []]
		for entry in s.history:
			var p: Array = entry[code]
			for i in range(4):
				histories[i].append(p[[0, 2, 3, 4][i]])
		day[code] = {"sir_history": histories}
	Data.day_count = s.day + 1
	Data.dict_names = {"day_" + str(Data.day_count): day}
	previous_city = Data.Current_City
	var h: Array = day[Data.Current_City].sir_history
	Data.Current_S = h[0]
	Data.Current_I = h[1]
	Data.Current_R = h[2]
	Data.Current_D = h[3]
	snapshot.emit()

func render_flights() -> void:
	var active := scheduler.reconcile(clock)
	var keep := {}
	for flight in active:
		keep[flight.id] = true
		if not visible_flights.has(flight.id):
			var plane := MeshInstance3D.new()
			var mesh := PrismMesh.new()
			mesh.size = Vector3(0.22, 0.08, 0.4)
			plane.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("f08cba") if flight.infected > 0 else Color("8ccce2")
			plane.material_override = material
			get_parent().globe.add_child(plane)
			visible_flights[flight.id] = plane
		var from: Vector3 = city_node_cache[flight.from].global_position
		var to: Vector3 = city_node_cache[flight.to].global_position
		var direction := from.normalized().slerp(to.normalized(), flight.progress)
		var position_value := direction * (lerpf(from.length(), to.length(), flight.progress) + sin(flight.progress * PI) * 3.0)
		visible_flights[flight.id].global_position = position_value
	for id in visible_flights.keys():
		if not keep.has(id):
			visible_flights[id].queue_free()
			visible_flights.erase(id)

func cleanup_active_terminals() -> void:
	for plane in visible_flights.values():
		plane.queue_free()
	visible_flights.clear()

func save_run() -> Error:
	return Saves.write({"simulation": simulation.serialize(), "clock": clock, "speed": speed, "city": Data.Current_City, "flights": scheduler.flights})

func resume_run() -> bool:
	var data := Saves.read_save()
	if data.is_empty():
		return false
	is_auto_running = false
	cleanup_active_terminals()
	clock = data.clock
	speed = clampf(data.get("speed", 1.0), 1.0, 4.0)
	Data.Current_City = data.get("city", "SF")
	if not data.simulation.state.regions.has(Data.Current_City):
		Data.Current_City = "SF"
	scheduler.flights = data.flights
	simulation.restore(data.simulation)
	render_flights()
	return true
