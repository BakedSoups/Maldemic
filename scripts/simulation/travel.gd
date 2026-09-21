extends RefCounted

# Allocate every departure from a frozen source population. Arrivals cannot
# depart again this tick. Dead people never enter the travel allocation.
static func apply(regions: Dictionary, modifiers: Dictionary, events: Array) -> Array:
	var deltas := {}
	var routes: Array = []
	for code in regions:
		deltas[code] = [0, 0, 0, 0, 0]
	for code in regions:
		var region: Dictionary = regions[code]
		var fraction: float = 0.006 * modifiers.travel * (1.0 - 0.2 * region.policy)
		for event in events:
			if event.kind == "Travel surge" and event.region == code:
				fraction *= 1.8
		fraction = clampf(fraction, 0.0, 0.08)
		var count: int = region.connections.size()
		for destination in region.connections:
			var passengers := [0, 0, 0, 0, 0]
			for compartment in range(4):
				passengers[compartment] = int(floor(region.population[compartment] * fraction / count))
				deltas[code][compartment] -= passengers[compartment]
				deltas[destination][compartment] += passengers[compartment]
			var total: int = passengers[0] + passengers[1] + passengers[2] + passengers[3]
			if total > 0:
				routes.append({"from": code, "to": destination, "total": total, "infected": passengers[2], "exposed": passengers[1]})
	for code in regions:
		for compartment in range(5):
			regions[code].population[compartment] += deltas[code][compartment]
	return routes
