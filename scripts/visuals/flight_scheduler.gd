extends RefCounted

const MAX_VISIBLE = 35
var flights: Array = []

func schedule(day: int, routes: Array, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + day * 104729
	var queued: Array = []
	for route in routes:
		var count := clampi(int(ceil(route.total / 9000.0)), 1, 4)
		for index in range(count):
			queued.append(route.duplicate())
	# A bounded daily queue, interleaved by seeded keys to avoid route batches.
	for route in queued:
		route.order = random.randf()
	queued.sort_custom(func(a, b): return a.order < b.order)
	if queued.size() > 56:
		queued.resize(56)
	for index in range(queued.size()):
		var departure := day + (index + random.randf_range(0.1, 0.9)) / queued.size()
		var flight: Dictionary = queued[index]
		flight.departure = departure
		flight.arrival = departure + random.randf_range(0.25, 0.65)
		flight.id = "%d:%d" % [day, index]
		flights.append(flight)

func reconcile(clock: float) -> Array:
	flights = flights.filter(func(f): return f.arrival > clock)
	var active: Array = []
	for flight in flights:
		if flight.departure <= clock and active.size() < MAX_VISIBLE:
			var item: Dictionary = flight.duplicate()
			item.progress = clampf((clock - flight.departure) / (flight.arrival - flight.departure), 0, 1)
			active.append(item)
	return active
