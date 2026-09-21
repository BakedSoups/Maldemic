extends RefCounted

var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrades/strategy.json"))

func definition(id: String) -> Dictionary:
	for item in definitions:
		if item.id == id:
			return item
	return {}

func cost(state: Dictionary, item: Dictionary) -> int:
	return int(ceil((item.cost + state.purchases.size() * 0.5) * state.difficulty.cost))

func reason(state: Dictionary, item: Dictionary) -> String:
	if item.is_empty():
		return "Unknown upgrade"
	if state.ending != "":
		return "Run finished"
	if item.id in state.purchases:
		return "Purchased"
	for id in item.prerequisites:
		if id not in state.purchases:
			return "Requires " + definition(id).name
	for id in item.exclusions:
		if id in state.purchases:
			return "Excludes " + definition(id).name
	if state.points < cost(state, item):
		return "Need %d EP" % cost(state, item)
	return ""

func modifiers(state: Dictionary) -> Dictionary:
	var result := {"spread": 1.0, "clearance": 1.0, "impact": 1.0, "visibility": 1.0, "travel": 1.0, "cold": 1.0, "hot": 1.0, "resistance": 0.0, "research": 1.0}
	for source in [state.loadout_effects] + state.purchases.map(func(id): return definition(id).effects):
		for key in source:
			result[key] += source[key]
	for key in result:
		result[key] = clampf(result[key], 0.0 if key == "resistance" else 0.3, 2.5)
	return result

func purchase(state: Dictionary, id: String) -> String:
	var item := definition(id)
	var blocked := reason(state, item)
	if blocked != "":
		return blocked
	var price := cost(state, item)
	state.points -= price
	state.purchases.append(id)
	state.paid[id] = price
	state.timeline.append("Day %d: %s (%d EP)" % [state.day, item.name, price])
	if state.telemetry.first_purchase < 0:
		state.telemetry.first_purchase = state.day
	return ""

func refund(state: Dictionary) -> bool:
	if state.refunds <= 0 or state.purchases.is_empty() or state.ending != "":
		return false
	var id: String = state.purchases.pop_back()
	state.points += int(floor(state.paid[id] * 0.5))
	state.paid.erase(id)
	state.refunds -= 1
	state.timeline.append("Day %d: reversed %s (50%% refund)" % [state.day, definition(id).name])
	return true
