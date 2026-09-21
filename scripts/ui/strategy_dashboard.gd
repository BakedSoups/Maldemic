extends "res://scripts/dashboard.gd"

const Profile = preload("res://scripts/visuals/visual_profile.gd")
var economy_label: Label
var region_detail: Label
var objective_label: Label
var feed: Label
var upgrade_buttons := {}
var setup_layer: PanelContainer
var results_layer: PanelContainer
var setup_feedback: Label
var setup_seed: LineEdit
var setup_city: OptionButton
var setup_loadout: OptionButton
var setup_difficulty: OptionButton
var setup_tutorial: CheckButton
var reduced_motion: CheckButton
var displayed_build := ""
var results_shown := false

func _ready() -> void:
	controller_script = "res://scripts/game/strategy_controller.gd"
	super._ready()
	playback_buttons[0].hide()
	chart.custom_minimum_size.y = 60
	strain_label.get_parent().get_parent().hide()
	dashboard.get_child(0).add_theme_constant_override("separation", 8)
	controller.snapshot.connect(refresh)
	var layout = status_label.get_parent()
	layout.add_theme_constant_override("separation", 6)
	globe.get_parent().get_parent().custom_minimum_size.y = 210
	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	layout.move_child(toolbar, 1)
	for rate in [1, 2, 4]:
		toolbar.add_child(button("%d×" % rate, func(): controller.speed = rate))
	toolbar.add_child(button("Save", func(): status_label.text = "Run saved." if controller.save_run() == OK else "Save failed; previous save retained."))
	toolbar.add_child(button("Resume", resume))
	toolbar.add_child(button("New game", open_setup))
	toolbar.add_child(button("Sandbox / Viewer", func(): get_tree().change_scene_to_file("res://viewer.tscn")))
	economy_label = label("", 15, Color("8ccce2"))
	layout.add_child(economy_label)
	layout.move_child(economy_label, 2)
	region_detail = label("", 11)
	region_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size.y = 84
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dashboard.get_child(0).add_child(detail_scroll)
	region_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(region_detail)
	objective_label = label("", 12, Color("c3b0ee"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(objective_label)
	feed = label("", 11, Color("efaacb"))
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.max_lines_visible = 2
	feed.custom_minimum_size.y = 34
	layout.add_child(feed)
	build_setup()
	refresh()
	open_setup()

func panel(parent: Node) -> VBoxContainer:
	var box := super.panel(parent)
	box.add_theme_constant_override("separation", 6)
	return box

func build_presets(parent: Node) -> void:
	preset_strip = VBoxContainer.new()
	parent.add_child(preset_strip)

func reset_controls() -> void:
	pass

func build_lab() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 400
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lab.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	list.add_child(label("EVOLVE · changes affect future days", 15))
	var evolution = preload("res://scripts/game/evolution.gd").new()
	for branch in ["Spread", "Impact", "Adaptation"]:
		list.add_child(label(branch.to_upper(), 17, Color("c3b0ee")))
		for item in evolution.definitions:
			if item.branch != branch:
				continue
			var purchase_button := button(item.name, func():
				var reason: String = controller.simulation.purchase(item.id)
				status_label.text = reason if reason != "" else item.name + " assembled. Effects begin next day.")
			list.add_child(purchase_button)
			upgrade_buttons[item.id] = purchase_button
			var description := label(item.explanation + "\n" + item.visual, 11)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(description)
	list.add_child(button("Reverse last purchase · 50% refund · 2 per run", func():
		var done: bool = controller.simulation.evolution.refund(controller.simulation.state)
		status_label.text = "Purchase reversed." if done else "No reversals available."
		refresh()))
	var specimen_panel := panel(lab)
	specimen_panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	specimen_name = label("", 24)
	specimen_panel.add_child(specimen_name)
	preview = Preview.new()
	preview.custom_minimum_size = Vector2(240, 180)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	specimen_panel.add_child(preview)
	specimen_summary = label("", 12)
	specimen_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	specimen_panel.add_child(specimen_summary)
	specimen_panel.add_child(label("Fictional game statistics · stylized geometry\nDrag to rotate · scroll to zoom", 12))
	specimen_panel.add_child(button("Reset view", func(): preview.reset_view()))
	reduced_motion = CheckButton.new()
	reduced_motion.text = "Reduced motion"
	reduced_motion.toggled.connect(func(value): preview.reduced_motion = value; preview.spin = not value)
	specimen_panel.add_child(reduced_motion)

func show_lab(show_editor: bool) -> void:
	if not is_instance_valid(controller):
		return
	if show_editor:
		controller.is_auto_running = false
	dashboard.visible = not show_editor
	lab.visible = show_editor
	preset_strip.hide()
	status_label.text = "Paused · choose an adaptation, then return to Overview and Run." if show_editor else "Drag the globe to orbit · scroll to zoom · select a region."

func _process(_delta: float) -> void:
	if is_instance_valid(controller) and is_instance_valid(economy_label):
		run_button.text = "Pause" if controller.is_auto_running else "Run"
		day_label.text = "Day %02d · %d×" % [controller.simulation.state.day, controller.speed]

func refresh() -> void:
	if not is_instance_valid(economy_label):
		return
	var sim = controller.simulation
	var s: Dictionary = sim.state
	economy_label.text = "%d EP   ·   Cure %.1f%%   ·   %s / %s" % [s.points, s.cure, s.loadout, s.difficulty_name]
	var totals: Array = sim.totals()
	for i in range(4):
		stat_labels[i].text = compact_number(totals[[0, 2, 3, 4][i]])
	var r: Dictionary = s.regions[Data.Current_City]
	city_label.text = Data.Current_City + " · POPULATION TREND"
	for i in range(city_picker.item_count):
		if city_picker.get_item_text(i) == Data.Current_City:
			city_picker.select(i)
	region_detail.text = "%s · healthcare %.0f%%\n%s · awareness %.0f / 100\nExposed: %s · connections: %s" % [r.climate.capitalize(), r.healthcare * 100, sim.Response.STAGES[r.policy], r.awareness, compact_number(r.population[1]), ", ".join(r.connections)]
	if r.pending >= 0:
		region_detail.text += "\n%s on day %d" % [sim.Response.STAGES[r.pending], r.policy_due]
	for event in s.events:
		if event.region == Data.Current_City:
			region_detail.text += "\n%s: %s (to day %d)" % [event.kind, event.summary, event.expires]
	chart.queue_redraw()
	strain_label.text = s.loadout
	var established := 0
	for region in s.regions.values():
		if region.population[2] >= sim.balance.established:
			established += 1
	objective_label.text = "OBJECTIVE · %d/7 regions with ≥%d infected · %.1f%% / %.0f%% global infection before cure" % [established, sim.balance.established, float(totals[2]) / s.total * 100, s.target * 100]
	if s.tutorial:
		var hints := ["Open Virus Lab and buy your first upgrade.", "Reach two regions; travel affinity increases outbound travel.", "Watch for detection and the first cure research.", "Buy three upgrades; compare growth against visibility.", "Tutorial complete. Keep adapting before cure reaches 100%."]
		objective_label.text += "\n" + hints[mini(s.tutorial_stage, 4)]
	feed.text = "\n".join(s.timeline.slice(maxi(0, s.timeline.size() - 2)))
	for id in upgrade_buttons:
		var item: Dictionary = sim.evolution.definition(id)
		var reason: String = sim.evolution.reason(s, item)
		upgrade_buttons[id].text = "%s · %d EP%s" % [item.name, sim.evolution.cost(s, item), " · " + reason if reason != "" else ""]
		upgrade_buttons[id].disabled = reason != ""
		var before: Dictionary = sim.evolution.modifiers(s)
		var hypothetical: Dictionary = s.duplicate(true)
		hypothetical.purchases.append(id)
		var after: Dictionary = sim.evolution.modifiers(hypothetical)
		var lines: Array[String] = []
		for key in item.effects:
			lines.append("%s: %.2f → %.2f" % [key.capitalize(), before[key], after[key]])
		upgrade_buttons[id].tooltip_text = "\n".join(lines)
	var build: String = str(s.purchases) + s.loadout + str(s.visual_seed)
	if build != displayed_build:
		preview.apply_profile(Profile.derive(s, sim.evolution), displayed_build != "")
		displayed_build = build
	specimen_name.text = s.loadout
	specimen_summary.text = "%d adaptations · %d reversals left\nSpread %.2f× · Visibility %.2f×" % [s.purchases.size(), s.refunds, sim.evolution.modifiers(s).spread, sim.evolution.modifiers(s).visibility]
	if s.ending != "" and not results_shown:
		show_results()

func overlay() -> PanelContainer:
	var layer := PanelContainer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_theme_stylebox_override("panel", style(Color("171a32")))
	add_child(layer)
	return layer

func build_setup() -> void:
	setup_layer = overlay()
	var center := CenterContainer.new()
	setup_layer.add_child(center)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 540
	center.add_child(form)
	form.add_child(label("Persistent signal", 32))
	setup_feedback = label("", 12, Color("efaacb"))
	form.add_child(setup_feedback)
	form.add_child(label("Establish ≥100 infected in all seven regions and infect 25%\nof the global population before the cure is deployed.", 16))
	form.add_child(label("One fictional archetype · three starting loadouts", 13, Color("8ccce2")))
	setup_loadout = OptionButton.new()
	for title in ["Drifter", "Quiet shell", "Prism"]:
		setup_loadout.add_item(title)
	form.add_child(setup_loadout)
	form.add_child(label("Drifter: growth +12%, visibility +4%\nQuiet shell: visibility −18%, growth −3%\nPrism: response resistance +20%, travel −10%", 12))
	setup_city = OptionButton.new()
	for code in controller.simulation.state.regions:
		setup_city.add_item(code)
	form.add_child(label("Starting region", 12))
	form.add_child(setup_city)
	setup_difficulty = OptionButton.new()
	for title in ["Guided", "Standard", "Expert"]:
		setup_difficulty.add_item(title)
	form.add_child(label("Difficulty", 12))
	form.add_child(setup_difficulty)
	setup_seed = LineEdit.new()
	setup_seed.text = "42"
	form.add_child(label("Seed · same seed and actions reproduce the run", 12))
	form.add_child(setup_seed)
	setup_tutorial = CheckButton.new()
	setup_tutorial.text = "Tutorial objectives"
	setup_tutorial.button_pressed = true
	form.add_child(setup_tutorial)
	form.add_child(button("Start strategy", func(): begin(setup_seed.text.to_int(), setup_city.get_item_text(setup_city.selected), setup_loadout.get_item_text(setup_loadout.selected), setup_difficulty.get_item_text(setup_difficulty.selected), setup_tutorial.button_pressed), true))
	form.add_child(button("Resume saved run", resume))
	form.add_child(button("Back to current run", func(): setup_layer.hide()))

func open_setup() -> void:
	controller.is_auto_running = false
	setup_layer.show()

func begin(seed_value: int, city: String, loadout: String, difficulty: String, tutorial: bool) -> void:
	results_shown = false
	if is_instance_valid(results_layer):
		results_layer.queue_free()
	controller.start(seed_value, city, loadout, difficulty, tutorial)
	setup_layer.hide()
	show_lab(false)
	controller.is_auto_running = true

func resume() -> void:
	results_shown = false
	if is_instance_valid(results_layer):
		results_layer.queue_free()
	if controller.resume_run():
		setup_layer.hide()
		show_lab(false)
		status_label.text = "Saved run restored, paused."
	else:
		status_label.text = "No valid strategy save found."
		setup_feedback.text = "No valid strategy save found."

func show_results() -> void:
	results_shown = true
	controller.is_auto_running = false
	results_layer = overlay()
	var scroll := ScrollContainer.new()
	results_layer.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var s: Dictionary = controller.simulation.state
	content.add_child(label(s.ending, 25))
	var score := int(maxf(0, (100 - s.cure) * 10 + s.points * 5 + (1000 if s.ending.begins_with("Victory") else 0)))
	content.add_child(label("Score %d · cure headroom ×10 + unspent EP ×5 + victory 1000" % score, 13))
	var reached: int = s.claimed.filter(func(id): return id.begins_with("Established ")).size()
	content.add_child(label("Day %d · %d/7 regions reached · Cure %.1f%% · %d unspent EP\nSeed %d · %s · %s\nFirst purchase day %d · Detection day %d\nBuild: %s" % [s.day, reached, s.cure, s.points, s.seed, s.loadout, s.difficulty_name, s.telemetry.first_purchase, s.telemetry.detection, ", ".join(s.purchases)], 15))
	content.add_child(button("Retry same seed", func(): begin(s.seed, s.start_city, s.loadout, s.difficulty_name, s.tutorial), true))
	content.add_child(button("Retry new seed", func(): begin(randi_range(1, 1000000), s.start_city, s.loadout, s.difficulty_name, s.tutorial)))
	content.add_child(button("Review world", func(): results_layer.hide()))
	content.add_child(label("\n".join(s.timeline), 13))

func configure_globe() -> void:
	# Strategy owns flight scheduling; do not initialize the viewer's path cache.
	var terminal := globe.find_child("Airport_Terminal", true, false)
	if terminal:
		terminal.free()
