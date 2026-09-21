extends Node

func _ready() -> void:
	var ui = load("res://viewer.tscn").instantiate()
	add_child(ui)
	await get_tree().create_timer(2.0).timeout
	assert(ui.stat_labels.size() == 4)
	assert(ui.status_label.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y)
	assert(Data.day_count == 1)
	assert(ui.controller.city_node_cache.size() > 0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/maldemic-overview.png")
	ui.show_lab(true)
	assert(ui.lab.visible and not ui.dashboard.visible)
	assert(ui.preset_buttons.size() == 6)
	var original_data = Data.dict_names
	for index in range(ui.PRESETS.size()):
		ui.apply_preset(index)
		assert(ui.draft.name == ui.PRESETS[index].name)
		assert(ui.name_input.text == ui.PRESETS[index].name)
		assert(ui.specimen_name.text == ui.PRESETS[index].name)
		assert(Data.dict_names == original_data)
	ui.reset_traits()
	var before: int = ui.preview.specimen.get_child(0).get_child_count()
	ui.sliders.infection_rate.value = 0.1
	assert(ui.preview.specimen.get_child(0).get_child_count() < before)
	ui.sliders.lethality.value = 0.5
	ui.sliders.mutation_rate.value = 0.1
	ui.sliders.incubation_period.value = 21
	ui.sliders.symptom_severity.value = 10
	ui.reset_traits()
	await get_tree().create_timer(0.5).timeout
	assert(ui.status_label.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/maldemic-lab.png")
	ui.show_lab(false)
	ui.controller._on_day_add_button_down()
	await get_tree().create_timer(0.5).timeout
	assert(Data.day_count == 2)
	ui.controller._on_day_back_button_down()
	assert(Data.day_count == 1)
	ui.controller._on_day_back_button_down()
	assert(Data.day_count == 1)
	if "--simulation" in OS.get_cmdline_user_args():
		ui.show_lab(true)
		ui.name_input.text = "Integration strain"
		ui.draft.transmission_mode = "contact"
		ui.draft.incubation_period = 12.0
		ui.draft.symptom_severity = 3.0
		ui.draft.mutation_rate = 0.0
		ui.draft.seed_city = "LON"
		ui.sliders.infection_rate.value = 0.2
		ui.start_simulation()
		assert(ui.simulation_thread != null)
		for attempt in range(300):
			await get_tree().create_timer(0.1).timeout
			if ui.simulation_thread == null:
				break
		assert(ui.simulation_thread == null)
		assert(Data.Current_City == "LON")
		var virus = Data.dict_names.day_1.virus_history.day_1
		assert(virus.current_strain == "Integration strain")
		var strain = virus.strains[virus.current_strain]
		assert(is_equal_approx(strain.infection_rate, 0.2))
		assert(strain.attributes.transmission_mode == "contact")
		assert(strain.attributes.incubation_period == 12)
		assert(strain.attributes.symptom_severity == 3)
		assert(is_zero_approx(virus.mutation_rate))
		print("SIMULATION_INTEGRATION_OK: edited properties reached new simulation")
	print("UI_SMOKE_OK: editor traits, navigation, city lookup and timeline")
	get_tree().quit()
