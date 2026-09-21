extends RefCounted

const PATH = "user://strategy_run.save"
const VERSION = 1

static func write(payload: Dictionary, path := PATH) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({"version": VERSION, "payload": payload}, false)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)

static func read_save(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > 16000000:
		return {}
	var data = file.get_var(false)
	if not data is Dictionary or data.get("version") != VERSION:
		return {}
	var payload = data.get("payload", {})
	if not payload is Dictionary or not payload.get("simulation") is Dictionary:
		return {}
	var simulation: Dictionary = payload.simulation
	var state = simulation.get("state")
	if not state is Dictionary or not simulation.get("rng") is String:
		return {}
	for key in ["regions", "history", "purchases", "claimed", "events", "difficulty", "loadout_effects", "paid", "telemetry", "timeline", "routes", "seed", "visual_seed", "day", "points", "refunds", "cure", "ending", "target", "total", "tutorial", "tutorial_stage", "start_city", "loadout", "difficulty_name"]:
		if not state.has(key):
			return {}
	if not payload.get("flights") is Array or not payload.get("clock") is float:
		return {}
	if not state.regions is Dictionary or state.regions.size() != 7 or not state.history is Array:
		return {}
	if not valid_state(state, payload):
		return {}
	var total := 0.0
	for region in state.regions.values():
		if not region is Dictionary or not region.get("population") is Array or region.population.size() != 5:
			return {}
		for number in region.population:
			if not (number is float or number is int) or not is_finite(number) or number < 0 or number != floor(number):
				return {}
			total += number
	if total != state.total or not is_finite(payload.clock) or payload.clock < state.day or payload.clock >= state.day + 1:
		return {}
	return payload

static func valid_state(state: Dictionary, payload: Dictionary) -> bool:
	var sim = preload("res://scripts/simulation/simulation.gd").new()
	sim.start()
	for key in sim.state:
		if typeof(state[key]) != typeof(sim.state[key]):
			return false
	for key in ["day", "points", "refunds", "cure", "target", "total", "tutorial_stage"]:
		if not is_finite(state[key]) or state[key] < 0:
			return false
	if state.day > 180 or state.history.size() != state.day + 1 or state.refunds > 2 or state.tutorial_stage > 4 or state.cure > 100 or state.target > 1:
		return false
	if not sim.balance.loadouts.has(state.loadout) or not sim.balance.difficulties.has(state.difficulty_name) or not state.regions.has(state.start_city):
		return false
	for key in sim.state.difficulty:
		if not state.difficulty.has(key) or not (state.difficulty[key] is float or state.difficulty[key] is int) or not is_finite(state.difficulty[key]):
			return false
	if state.difficulty.cost <= 0 or state.difficulty.response <= 0:
		return false
	for key in state.loadout_effects:
		if not sim.evolution.modifiers(sim.state).has(key) or not (state.loadout_effects[key] is float or state.loadout_effects[key] is int):
			return false
	var seen := []
	for id in state.purchases:
		if not id is String or sim.evolution.definition(id).is_empty() or id in seen or not state.paid.has(id):
			return false
		if not (state.paid[id] is float or state.paid[id] is int) or state.paid[id] < 0:
			return false
		seen.append(id)
	for entry in state.claimed + state.timeline:
		if not entry is String:
			return false
	for key in ["first_purchase", "detection"]:
		if not state.telemetry.get(key) is int:
			return false
	for code in sim.state.regions:
		if not state.regions.get(code) is Dictionary:
			return false
		var region: Dictionary = state.regions[code]
		for key in sim.state.regions[code]:
			if not region.has(key) or typeof(region[key]) != typeof(sim.state.regions[code][key]):
				return false
		if region.code != code or region.connections != sim.state.regions[code].connections or region.policy < 0 or region.policy > 3 or region.pending < -1 or region.pending > 3:
			return false
		for entry in state.history:
			if not entry is Dictionary or not entry.get(code) is Array or entry[code].size() != 5:
				return false
			for value in entry[code]:
				if not value is int or value < 0:
					return false
	for event in state.events:
		if not event is Dictionary or event.get("kind", "") not in ["Travel surge", "Research grant", "Weather shift"] or not state.regions.has(event.get("region", "")) or not event.get("expires") is int or not event.get("summary") is String:
			return false
	for flight in payload.flights:
		if not flight is Dictionary or not state.regions.has(flight.get("from", "")) or not state.regions.has(flight.get("to", "")) or not flight.get("id") is String:
			return false
		for key in ["departure", "arrival", "infected", "total"]:
			if not (flight.get(key) is float or flight.get(key) is int) or not is_finite(flight[key]) or flight[key] < 0:
				return false
		if flight.arrival <= flight.departure:
			return false
	return true
