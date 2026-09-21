extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var ui = load("res://ui.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.begin(42, "SF", "Drifter", "Standard", true)
	ui.controller.is_auto_running = false
	assert(ui.controller.simulation.purchase("dispersal") == "")
	for i in range(180):
		ui.controller._on_day_add_button_down()
		if ui.controller.simulation.state.ending != "":
			break
	assert(ui.controller.simulation.state.ending != "")
	assert(ui.results_layer.visible)
	print("PACK_RUN_OK: complete Strategy run from exported pack with empty PATH")
	quit()
