extends RefCounted

const STAGES = ["Unaware", "Investigating", "Containing", "Emergency"]

static func tick(state: Dictionary, modifiers: Dictionary) -> void:
	var research := 0.0
	for code in state.regions:
		var region: Dictionary = state.regions[code]
		var p: Array = region.population
		var burden: float = float(p[2]) / maxf(1, p[0] + p[1] + p[2] + p[3])
		region.awareness = minf(100.0, region.awareness + (0.08 + burden * 100.0 * modifiers.impact) * modifiers.visibility * state.difficulty.response)
		if region.pending >= 0 and state.day >= region.policy_due:
			region.policy = region.pending
			region.pending = -1
			region.policy_until = state.day + 12
			state.timeline.append("Day %d: %s — %s for at least 12 days" % [state.day, code, STAGES[region.policy]])
		var target := 0
		for threshold in [12, 35, 65]:
			if region.awareness >= threshold:
				target += 1
		if target > region.policy and region.pending < 0 and state.day >= region.policy_until:
			region.pending = region.policy + 1
			region.policy_due = state.day + 3
			state.timeline.append("Day %d: %s warns %s starts day %d; contact and travel will fall" % [state.day, code, STAGES[region.pending], region.policy_due])
		if region.policy > 0:
			if state.telemetry.detection < 0:
				state.telemetry.detection = state.day
			var contribution: float = 0.9 * region.healthcare * region.policy
			for event in state.events:
				if event.kind == "Research grant" and event.region == code:
					contribution *= 1.8
			research += contribution
	state.cure = minf(100, state.cure + research * maxf(0.4, modifiers.research) * state.difficulty.response)
