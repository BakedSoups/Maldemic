extends Node

func _ready() -> void:
	var ui = load("res://ui.tscn").instantiate()
	add_child(ui)
	await get_tree().create_timer(0.3).timeout
	assert(ui.setup_layer.visible)
	ui.begin(42, "SF", "Drifter", "Standard", true)
	ui.controller.is_auto_running = false
	await get_tree().process_frame
	assert(ui.status_label.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y)
	assert(ui.feed.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y)
	ui.show_lab(true)
	assert(ui.lab.visible)
	assert(ui.upgrade_buttons.size() == 12)
	ui.preview.specimen.rotation.y = 1.2
	ui.preview.specimen_camera.size = 4.0
	assert(ui.controller.simulation.purchase("dispersal") == "")
	assert(is_equal_approx(ui.preview.specimen.rotation.y, 1.2))
	assert(ui.preview.specimen_camera.size == 4.0)
	ui.show_lab(false)
	for i in range(35):
		ui.controller.advance(0.1)
	assert(ui.controller.simulation.state.day == 3)
	assert(ui.controller.visible_flights.size() > 0)
	var frozen: Dictionary = ui.controller.simulation.serialize()
	var flight_clock: float = ui.controller.clock
	await get_tree().create_timer(0.2).timeout
	assert(ui.controller.clock == flight_clock)
	assert(ui.controller.simulation.serialize() == frozen)
	assert(ui.controller.save_run() == OK)
	ui.controller.advance(1.5)
	var expected: Dictionary = ui.controller.simulation.serialize()
	var expected_flights: Array = ui.controller.scheduler.flights.duplicate(true)
	assert(ui.controller.resume_run())
	ui.controller.advance(1.5)
	assert(ui.controller.simulation.serialize() == expected)
	assert(ui.controller.scheduler.flights == expected_flights)
	# Same elapsed simulation time at every playback speed.
	for rate in [1, 2, 4]:
		ui.begin(42, "SF", "Drifter", "Standard", true)
		ui.controller.is_auto_running = false
		for frame in range(120 / rate):
			ui.controller.advance(rate / 10.0)
		assert(ui.controller.simulation.state.day == 12)
		if rate == 1:
			expected = ui.controller.simulation.serialize()
		else:
			assert(ui.controller.simulation.serialize() == expected)
	ui.controller.simulation.state.cure = 100
	ui.controller._on_day_add_button_down()
	assert(ui.results_layer.visible)
	ui.begin(42, "SF", "Prism", "Guided", true)
	ui.controller.is_auto_running = false
	assert(ui.controller.simulation.state.day == 0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/maldemic-strategy-world.png")
		ui.show_lab(true)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/maldemic-strategy-lab.png")
	print("STRATEGY_SMOKE_OK: purchases, pause, save/resume, speeds, traffic, ending, restart")
	get_tree().quit()
