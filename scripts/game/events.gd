extends RefCounted

static func tick(state: Dictionary, rng: RandomNumberGenerator) -> void:
	state.events = state.events.filter(func(event): return event.expires > state.day)
	if state.day < 10 or int(state.day) % 10 != 0 or rng.randf() > 0.8:
		return
	var kinds := ["Travel surge", "Research grant", "Weather shift"]
	var code: String = state.regions.keys()[rng.randi_range(0, state.regions.size() - 1)]
	var eligible := [0, 2]
	if state.regions[code].policy > 0:
		eligible.append(1)
	var index: int = eligible[rng.randi_range(0, eligible.size() - 1)]
	var summaries := ["outbound travel +80%", "research contribution +80%", "local growth −20%"]
	var event := {"kind": kinds[index], "region": code, "expires": state.day + 8, "summary": summaries[index]}
	state.events.append(event)
	state.timeline.append("Day %d: %s in %s, %s until day %d" % [state.day, event.kind, code, event.summary, event.expires])
