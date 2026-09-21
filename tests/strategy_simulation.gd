extends SceneTree

const Sim = preload("res://scripts/simulation/simulation.gd")
const Scheduler = preload("res://scripts/visuals/flight_scheduler.gd")
const Save = preload("res://scripts/game/save_game.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var sim := Sim.new()
	sim.start()
	check(sim.purchase("network") != "", "Prerequisites enforced")
	var before: Dictionary = sim.state.history[0].duplicate(true)
	check(sim.purchase("dispersal") == "", "First purchase affordable")
	check(sim.state.history[0] == before, "Purchases preserve history")
	check(sim.purchase("dispersal") != "", "No duplicate purchase")
	for day in range(30):
		sim.step()
		verify_population(sim)
	var restored := Sim.new()
	restored.restore(bytes_to_var(var_to_bytes(sim.serialize())))
	for day in range(150):
		sim.step()
		restored.step()
		verify_population(sim)
		check(sim.state == restored.state, "Save/load deterministic day %d" % day)
	check(sim.state.ending != "", "Explicit ending")
	var points: int = sim.state.points
	sim.rewards_and_ending()
	check(points == sim.state.points, "No duplicate milestone rewards")
	var queue := Scheduler.new()
	queue.schedule(1, [{"from": "SF", "to": "LON", "total": 50000, "infected": 0}], 42)
	check(queue.flights.size() == 4, "Busy routes get multiple departures")
	check(queue.flights[0].departure != queue.flights[1].departure, "Staggered departure times")
	check(queue.reconcile(2.0).size() > 0, "Flights cross midnight")
	var serialized: Array = bytes_to_var(var_to_bytes(queue.flights))
	var resumed := Scheduler.new()
	resumed.flights = serialized
	check(queue.reconcile(2.1) == resumed.reconcile(2.1), "Flight resume equivalence")
	check(queue.reconcile(8).is_empty(), "Skipped flights expire without flashing")
	# Real versioned file round-trip and malformed schema rejection.
	var fresh := Sim.new()
	fresh.start()
	var payload := {"simulation": fresh.serialize(), "clock": 0.0, "flights": []}
	check(Save.write(payload, "user://test_run.save") == OK, "Atomic save")
	check(Save.read_save("user://test_run.save") == payload, "Exact disk round-trip")
	payload.simulation.state.regions.SF.population[0] = -1
	Save.write(payload, "user://invalid_run.save")
	check(Save.read_save("user://invalid_run.save").is_empty(), "Invalid save rejected")
	fresh.state.cure = 100.0
	fresh.step()
	check(fresh.state.ending.begins_with("Defeat"), "Cure defeat")
	fresh.start()
	fresh.state.regions.SF.population[0] += fresh.state.regions.SF.population[2]
	fresh.state.regions.SF.population[2] = 0
	fresh.step()
	check(fresh.state.ending.contains("cleared"), "Extinction ending")
	check(fresh.totals()[0] == fresh.state.total, "No forced infected passengers")
	var wins := 0
	for loadout in ["Drifter", "Quiet shell", "Prism"]:
		for seed_value in range(1, 7):
			var run := Sim.new()
			run.start(seed_value, "SF", loadout)
			var picks: Array = ["dispersal", "affinity", "carrier", "network"] if loadout == "Drifter" else (["cold", "disruption", "resilience", "dispersal"] if loadout == "Quiet shell" else ["signal", "burden", "crisis", "pressure"])
			for day in range(180):
				for id in picks:
					if run.purchase(id) == "":
						break
				run.step()
				verify_population(run)
				for event in run.state.events:
					check(event.expires > run.state.day, "Expired events removed")
				if run.state.ending != "":
					break
			if run.state.ending.begins_with("Victory"):
				wins += 1
			print("BALANCE ", loadout, " seed=", seed_value, " day=", run.state.day, " cure=", run.state.cure, " ending=", run.state.ending)
	check(wins >= 12, "Multiple viable builds")
	print("STRATEGY_SIMULATION: ", failures, " failures; ", wins, "/18 wins")
	quit(1 if failures else 0)

func verify_population(sim: RefCounted) -> void:
	var total := 0
	for region in sim.state.regions.values():
		for count in region.population:
			check(count >= 0 and count == floor(count), "Nonnegative integer compartments")
			total += int(count)
	check(total == sim.state.total, "Population conserved")
