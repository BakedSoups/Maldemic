extends RefCounted

signal changed
const Evolution = preload("res://scripts/game/evolution.gd")
const Travel = preload("res://scripts/simulation/travel.gd")
const Response = preload("res://scripts/game/world_response.gd")
const Events = preload("res://scripts/game/events.gd")
var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/persistent_signal.json"))
var evolution := Evolution.new()
var rng := RandomNumberGenerator.new()
var state: Dictionary = {}

func start(seed_value := 42, city := "SF", loadout := "Drifter", difficulty := "Standard", tutorial := true) -> void:
	rng.seed = seed_value
	state = {"seed": seed_value, "visual_seed": seed_value, "day": 0, "regions": {}, "points": balance.start_points + balance.difficulties[difficulty].points, "difficulty": balance.difficulties[difficulty].duplicate(), "difficulty_name": difficulty, "loadout": loadout, "loadout_effects": balance.loadouts[loadout].duplicate(), "start_city": city, "tutorial": tutorial, "tutorial_stage": 0, "purchases": [], "paid": {}, "refunds": 2, "claimed": [], "events": [], "cure": 0.0, "ending": "", "timeline": [], "history": [], "routes": [], "total": 0, "telemetry": {"first_purchase": -1, "detection": -1}, "target": balance.target}
	for item in balance.regions:
		var region: Dictionary = item.duplicate(true)
		state.total += item.population
		region.population = [int(item.population), 0, 0, 0, 0]
		region.merge({"awareness": 0.0, "policy": 0, "pending": -1, "policy_due": 0, "policy_until": 0})
		state.regions[item.code] = region
	state.regions[city].population[0] -= int(balance.start_infected)
	state.regions[city].population[2] += int(balance.start_infected)
	record()
	changed.emit()

func purchase(id: String) -> String:
	var result := evolution.purchase(state, id)
	changed.emit()
	return result

func step() -> void:
	if state.is_empty() or state.ending != "":
		return
	state.day += 1
	Events.tick(state, rng)
	var m := evolution.modifiers(state)
	for region in state.regions.values():
		var p: Array = region.population
		var living: float = p[0] + p[1] + p[2] + p[3]
		var climate: float = m.get(region.climate, 1.0)
		var contact: float = maxf(0.35, 1.0 - region.policy * 0.16 / (1.0 + m.resistance))
		for event in state.events:
			if event.kind == "Weather shift" and event.region == region.code:
				climate *= 0.8
		var exposure := mini(p[0], int(floor(p[0] * (1.0 - exp(-0.55 * m.spread * climate * contact * p[2] / maxf(1, living))))))
		var onset := int(ceil(p[1] / 3.0))
		var cleared := mini(p[2], int(ceil(p[2] * 0.035 * m.clearance)))
		var deaths := mini(cleared, int(floor(cleared * 0.02 * m.impact)))
		region.population = [p[0] - exposure, p[1] + exposure - onset, p[2] + onset - cleared, p[3] + cleared - deaths, p[4] + deaths]
	state.routes = Travel.apply(state.regions, m, state.events)
	Response.tick(state, m)
	rewards_and_ending()
	record()
	changed.emit()

func totals() -> Array:
	var result := [0, 0, 0, 0, 0]
	for region in state.regions.values():
		for i in range(5):
			result[i] += region.population[i]
	return result

func award(id: String, points: int) -> void:
	if id not in state.claimed:
		state.claimed.append(id)
		state.points += points
		state.timeline.append("Day %d: %s · +%d EP" % [state.day, id, points])

func rewards_and_ending() -> void:
	var established := 0
	for code in state.regions:
		if state.regions[code].population[2] >= balance.established:
			established += 1
			award("Established " + code, balance.region_reward)
	var t := totals()
	var fraction: float = float(t[2]) / state.total
	for milestone in balance.milestones:
		if fraction >= milestone:
			award("Infected %.1f%%" % (milestone * 100), balance.milestone_reward)
	if state.tutorial:
		var completed: Array = [not state.purchases.is_empty(), established >= 2, state.cure >= 1, state.purchases.size() >= 3]
		if state.tutorial_stage < completed.size() and completed[state.tutorial_stage]:
			award("Tutorial %d" % (state.tutorial_stage + 1), 2)
			state.tutorial_stage += 1
	if state.cure >= 100:
		state.ending = "Defeat: the cure was deployed."
	elif established == state.regions.size() and fraction >= state.target:
		state.ending = "Victory: a persistent outbreak in every region."
	elif t[1] + t[2] == 0:
		state.ending = "Defeat: the outbreak cleared."
	elif state.day >= balance.max_days:
		state.ending = "Defeat: the scenario time limit was reached."
	if state.ending != "":
		state.timeline.append("Day %d: %s" % [state.day, state.ending])

func record() -> void:
	var populations := {}
	for code in state.regions:
		populations[code] = state.regions[code].population.duplicate()
	state.history.append(populations)

func serialize() -> Dictionary:
	return {"state": state.duplicate(true), "rng": str(rng.state)}

func restore(data: Dictionary) -> void:
	state = data.state.duplicate(true)
	rng.seed = int(state.seed)
	rng.state = int(data.rng)
	changed.emit()
