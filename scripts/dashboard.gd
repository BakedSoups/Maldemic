extends Control

const Preview = preload("res://scripts/virus_preview.gd")
const Chart = preload("res://scripts/trend_chart.gd")
const DEFAULTS = {"name": "Custom Virus", "infection_rate": 0.9, "recovery_rate": 0.4, "lethality": 0.015, "mutation_rate": 0.002, "incubation_period": 5.0, "symptom_severity": 6.0, "transmission_mode": "droplet", "seed_city": "SF"}
var draft: Dictionary = DEFAULTS.duplicate()
var saved: Dictionary = DEFAULTS.duplicate()
var dashboard: HBoxContainer
var lab: HBoxContainer
var controller: Node2D
var globe: Node3D
var preview: SubViewportContainer
var chart: Control
var city_label: Label
var city_picker: OptionButton
var day_label: Label
var status_label: Label
var strain_label: Label
var run_button: Button
var start_button: Button
var stat_labels: Array[Label] = []
var sliders: Dictionary = {}
var name_input: LineEdit
var mode_input: OptionButton
var seed_input: OptionButton
var simulation_thread: Thread
var last_day := -1
var last_city := ""
var output_path := ""
var pending_design: Dictionary = {}
var playback_buttons: Array[Button] = []

func label(text_value: String, font_size := 14, color := Color("e5edf7")) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

func style(color: Color, border := Color("25374e")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func panel(parent: Node) -> VBoxContainer:
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", style(Color("101e30")))
	parent.add_child(shell)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	shell.add_child(box)
	return box

func button(text_value: String, action: Callable, accent := false) -> Button:
	var node := Button.new()
	node.text = text_value
	node.custom_minimum_size.y = 40
	node.add_theme_stylebox_override("normal", style(Color("1c584f") if accent else Color("182b40")))
	node.add_theme_stylebox_override("hover", style(Color("287568") if accent else Color("28425d"), Color("67dcc2")))
	node.add_theme_stylebox_override("pressed", style(Color("315b68")))
	node.pressed.connect(action)
	return node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("080f1c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	brand.add_child(label("M A L D E M I C", 25))
	brand.add_child(label("GLOBAL OUTBREAK OBSERVATORY", 11, Color("6edbc1")))
	header.add_child(button("Overview", func(): show_lab(false)))
	header.add_child(button("Virus Lab", func(): show_lab(true), true))
	dashboard = HBoxContainer.new()
	dashboard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dashboard.add_theme_constant_override("separation", 18)
	layout.add_child(dashboard)
	build_dashboard()
	lab = HBoxContainer.new()
	lab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lab.add_theme_constant_override("separation", 18)
	layout.add_child(lab)
	build_lab()
	lab.hide()
	status_label = label("Drag the globe to orbit  /  Scroll to zoom  /  Select a city to inspect", 12, Color("8fa4bc"))
	layout.add_child(status_label)
	var hidden_counter := RichTextLabel.new()
	hidden_counter.name = "Day Counter"
	hidden_counter.hide()
	add_child(hidden_counter)
	controller = Node2D.new()
	controller.name = "Main_Controller"
	controller.set_script(load("res://scripts/main_controller.gd"))
	add_child(controller)
	var file := FileAccess.open("user://virus_design.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			for key in DEFAULTS:
				if parsed.has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
					saved[key] = parsed[key]
	draft = saved.duplicate()
	reset_controls()

func build_dashboard() -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 310
	sidebar.add_theme_constant_override("separation", 14)
	dashboard.add_child(sidebar)
	var timeline := panel(sidebar)
	timeline.add_child(label("SIMULATION TIMELINE", 11, Color("8fa4bc")))
	day_label = label("Day 01", 30)
	timeline.add_child(day_label)
	var controls := HBoxContainer.new()
	timeline.add_child(controls)
	var back_button := button("− Day", func(): controller._on_day_back_button_down())
	controls.add_child(back_button)
	playback_buttons.append(back_button)
	run_button = button("Run", func(): controller._on_run_stop_button_down(), true)
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(run_button)
	playback_buttons.append(run_button)
	var next_button := button("+ Day", func(): controller._on_day_add_button_down())
	controls.add_child(next_button)
	playback_buttons.append(next_button)
	var trends := panel(sidebar)
	trends.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	city_label = label("SF · POPULATION TREND", 13)
	trends.add_child(city_label)
	city_picker = OptionButton.new()
	for city in ["SF", "CHI", "LON", "MA", "WA", "PA", "NYC"]:
		city_picker.add_item(city)
	city_picker.item_selected.connect(func(index): Data.Current_City = city_picker.get_item_text(index))
	trends.add_child(city_picker)
	chart = Chart.new()
	chart.name = "Graph"
	chart.custom_minimum_size = Vector2(260, 100)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trends.add_child(chart)
	var legend := HBoxContainer.new()
	trends.add_child(legend)
	var names := ["Susceptible", "Infected", "Recovered", "Deaths"]
	for i in range(4):
		legend.add_child(label(names[i], 10, Chart.COLORS[i]))
	var strain := panel(sidebar)
	strain.add_child(label("YOUR VIRUS", 11, Color("8fa4bc")))
	strain_label = label("Custom Virus", 19)
	strain.add_child(strain_label)
	strain.add_child(label("Build a strain. Watch it spread.", 13, Color("8fa4bc")))
	strain.add_child(button("Open Virus Lab  →", func(): show_lab(true), true))
	var world_column := VBoxContainer.new()
	world_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_column.add_theme_constant_override("separation", 14)
	dashboard.add_child(world_column)
	var world_panel := panel(world_column)
	world_panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_panel.add_child(label("WORLD VIEW   /   LIVE AIR TRAFFIC", 12, Color("6edbc1")))
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(340, 260)
	world_panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	globe = load("res://scenes/Camera.tscn").instantiate()
	viewport.add_child(globe)
	globe.target_spring_length = 43.0
	globe.spring_arm_3d.spring_length = 43.0
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	world_column.add_child(stats)
	for i in range(4):
		var card := panel(stats)
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(label(names[i].to_upper(), 10, Chart.COLORS[i]))
		var value := label("—", 20)
		card.add_child(value)
		stat_labels.append(value)

func build_lab() -> void:
	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size.x = 360
	lab.add_child(left_column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(scroll)
	var form := panel(scroll)
	form.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(label("Design your strain", 24))
	form.add_child(label("Change a trait. See the specimen evolve.", 13, Color("8fa4bc")))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Strain name"
	name_input.max_length = 40
	name_input.text_changed.connect(func(value): draft.name = value)
	form.add_child(name_input)
	mode_input = OptionButton.new()
	for mode in ["droplet", "airborne", "contact"]:
		mode_input.add_item(mode.capitalize())
	mode_input.item_selected.connect(func(index): draft.transmission_mode = ["droplet", "airborne", "contact"][index]; preview.rebuild(draft))
	form.add_child(label("Transmission · body shape", 12))
	form.add_child(mode_input)
	var traits := [
		["infection_rate", "Infection · spike density", 0.0, 1.0, 0.01],
		["recovery_rate", "Recovery · shell shading", 0.0, 1.0, 0.01],
		["lethality", "Lethality · spike length", 0.0, 1.0, 0.005],
		["mutation_rate", "Mutation · surface variation", 0.0, 0.1, 0.001],
		["incubation_period", "Incubation · core size", 1.0, 21.0, 1.0],
		["symptom_severity", "Severity · shell color", 1.0, 10.0, 1.0]]
	for property_spec in traits:
		var row := HBoxContainer.new()
		form.add_child(row)
		var title := label(property_spec[1], 12)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var value_label := label("", 12, Color("6edbc1"))
		row.add_child(value_label)
		var slider := HSlider.new()
		slider.min_value = property_spec[2]
		slider.max_value = property_spec[3]
		slider.step = property_spec[4]
		slider.custom_minimum_size.y = 22
		form.add_child(slider)
		var key: String = property_spec[0]
		slider.value_changed.connect(func(value):
			draft[key] = value
			value_label.text = ("%d days" % value if key == "incubation_period" else "%d / 10" % value) if key in ["incubation_period", "symptom_severity"] else "%.1f%%" % (value * 100)
			preview.rebuild(draft))
		sliders[key] = slider
	form.add_child(label("Starting city", 12))
	seed_input = OptionButton.new()
	for city in ["SF", "CHI", "LON", "MA", "WA", "PA", "NYC"]:
		seed_input.add_item(city)
	seed_input.item_selected.connect(func(index): draft.seed_city = seed_input.get_item_text(index))
	form.add_child(seed_input)
	left_column.add_child(button("Save design", save_design, true))
	start_button = button("Start new simulation", start_simulation, true)
	left_column.add_child(start_button)
	left_column.add_child(button("Reset traits", func(): draft = DEFAULTS.duplicate(); reset_controls()))
	var specimen_panel := panel(lab)
	specimen_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	specimen_panel.add_child(label("VIRUS LAB   /   LIVE SPECIMEN", 12, Color("6edbc1")))
	preview = Preview.new()
	preview.custom_minimum_size = Vector2(320, 280)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	specimen_panel.add_child(preview)
	specimen_panel.add_child(label("Drag to rotate  ·  Traits reshape the model instantly", 13, Color("8fa4bc")))
	var note := label("Stylized trait visualization. New simulations restart at day 1.\nSave design keeps your traits without changing the current run.", 12, Color("8fa4bc"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	specimen_panel.add_child(note)

func reset_controls() -> void:
	name_input.text = draft.name
	for key in sliders:
		sliders[key].set_value_no_signal(draft[key])
		sliders[key].value_changed.emit(sliders[key].value)
	mode_input.select(maxi(0, ["droplet", "airborne", "contact"].find(draft.transmission_mode)))
	for i in range(seed_input.item_count):
		if seed_input.get_item_text(i) == draft.seed_city:
			seed_input.select(i)
	preview.rebuild(draft)

func show_lab(show_editor: bool) -> void:
	if show_editor and controller.is_auto_running:
		controller._on_run_stop_button_down()
	dashboard.visible = not show_editor
	lab.visible = show_editor
	globe.process_mode = Node.PROCESS_MODE_DISABLED if show_editor else Node.PROCESS_MODE_INHERIT
	status_label.text = "Drag the specimen to rotate · Save a design or start a new run" if show_editor else "Drag the globe to orbit / Scroll to zoom / Choose a city in the sidebar"

func save_design() -> bool:
	draft.name = name_input.text.strip_edges()
	if draft.name.is_empty():
		draft.name = "Custom Virus"
		name_input.text = draft.name
	var file := FileAccess.open("user://virus_design.json", FileAccess.WRITE)
	if not file:
		status_label.text = "Could not save design. Check storage permissions."
		return false
	file.store_string(JSON.stringify(draft))
	file.close()
	saved = draft.duplicate()
	status_label.text = "Design saved · " + saved.name
	return true

func start_simulation() -> void:
	if simulation_thread != null or controller.processing_queue:
		status_label.text = "Wait for the current simulation step to finish."
		return
	if not save_design():
		return
	pending_design = saved.duplicate()
	var run_file := FileAccess.open("user://run_virus.json", FileAccess.WRITE)
	if not run_file:
		status_label.text = "Could not prepare the simulation input."
		return
	run_file.store_string(JSON.stringify(pending_design))
	run_file.close()
	if controller.is_auto_running:
		controller._on_run_stop_button_down()
	var python := "python" if OS.get_name() == "Windows" else "python3"
	for candidate in ["res://Python_Brain/.venv/bin/python", "res://Python_Brain/.venv/Scripts/python.exe", "res://Python_Brain/venv/bin/python", "res://Python_Brain/venv/Scripts/python.exe"]:
		if FileAccess.file_exists(candidate):
			python = ProjectSettings.globalize_path(candidate)
			break
	output_path = ProjectSettings.globalize_path("user://lab_simulation.json")
	var arguments := PackedStringArray([ProjectSettings.globalize_path("res://Python_Brain/preload.py"), "CustomVirus", saved.name, ProjectSettings.globalize_path("user://run_virus.json"), output_path])
	simulation_thread = Thread.new()
	var error := simulation_thread.start(func():
		var output := []
		var code := OS.execute(python, arguments, output, true)
		return {"code": code, "output": output})
	if error != OK:
		simulation_thread = null
		status_label.text = "Could not start the simulation worker."
		return
	start_button.disabled = true
	for playback_button in playback_buttons:
		playback_button.disabled = true
	status_label.text = "Building a new simulation… You can keep exploring your specimen."

func _process(_delta: float) -> void:
	if not is_instance_valid(controller):
		return
	if simulation_thread != null and not simulation_thread.is_alive():
		var result = simulation_thread.wait_to_finish()
		simulation_thread = null
		start_button.disabled = false
		for playback_button in playback_buttons:
			playback_button.disabled = false
		if result.code == 0:
			var data = JSON.parse_string(FileAccess.get_file_as_string(output_path))
			if data is Dictionary and data.has("day_1"):
				controller.cleanup_active_terminals()
				Data.dict_names = data
				Data.day_count = 1
				Data.Current_City = pending_design.seed_city
				controller.previous_day = -1
				last_day = -1
				show_lab(false)
				controller.create_test_flight()
				status_label.text = "New simulation ready · " + pending_design.name
			else:
				status_label.text = "Simulation returned invalid data. Current run retained."
		else:
			status_label.text = "Simulation failed. Python 3, numpy and scipy are required. Current run retained."
			push_warning(str(result.output))
	run_button.text = "Pause" if controller.is_auto_running else "Run"
	day_label.text = "Day %02d" % Data.day_count
	if last_day == Data.day_count and last_city == Data.Current_City:
		return
	last_day = Data.day_count
	last_city = Data.Current_City
	city_label.text = Data.Current_City + " · POPULATION TREND"
	for index in range(city_picker.item_count):
		if city_picker.get_item_text(index) == Data.Current_City:
			city_picker.select(index)
	chart.queue_redraw()
	var day: Dictionary = Data.dict_names.get("day_" + str(Data.day_count), {})
	var totals := [0.0, 0.0, 0.0, 0.0]
	for entry in day.values():
		if entry is Dictionary and entry.has("sir_history"):
			for i in range(mini(4, entry.sir_history.size())):
				var values: Array = entry.sir_history[i]
				if not values.is_empty():
					totals[i] += values[mini(Data.day_count, values.size() - 1)]
	for i in range(4):
		stat_labels[i].text = compact_number(totals[i])
	var history: Dictionary = day.get("virus_history", {}).get("day_" + str(Data.day_count), {})
	strain_label.text = history.get("current_strain", "Custom Virus")

func compact_number(value: float) -> String:
	if value >= 1000000:
		return "%.2fm" % (value / 1000000)
	if value >= 1000:
		return "%.1fk" % (value / 1000)
	return str(int(value))

func _exit_tree() -> void:
	if simulation_thread != null:
		simulation_thread.wait_to_finish()
