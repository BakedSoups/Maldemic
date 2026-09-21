extends Control

const COLORS = [Color("70b8ff"), Color("ff718a"), Color("52dfb3"), Color("bca6ed")]

func update_graph() -> void:
	queue_redraw()

func _draw() -> void:
	var histories := [Data.Current_S, Data.Current_I, Data.Current_R, Data.Current_D]
	var peak := 1.0
	var count := 1
	for values in histories:
		for value in values:
			peak = maxf(peak, value)
		count = maxi(count, values.size())
	var area := Rect2(42, 12, maxf(1, size.x - 54), maxf(1, size.y - 38))
	var font := ThemeDB.fallback_font
	for tick in range(5):
		var y := area.position.y + area.size.y * tick / 4.0
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("23364b"))
		var amount := peak * (1.0 - tick / 4.0)
		var caption := "%.1fm" % (amount / 1000000) if amount >= 1000000 else "%.0fk" % (amount / 1000)
		draw_string(font, Vector2(0, y + 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8299b1"))
	for series in range(4):
		var points := PackedVector2Array()
		for index in range(histories[series].size()):
			points.append(Vector2(area.position.x + area.size.x * index / maxf(1, count - 1), area.end.y - area.size.y * histories[series][index] / peak))
		if points.size() > 1:
			draw_polyline(points, COLORS[series], 2.0, true)
		elif points.size() == 1:
			draw_circle(points[0], 3, COLORS[series])
	draw_string(font, Vector2(area.position.x, size.y - 4), "DAY 0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8299b1"))
	draw_string(font, Vector2(area.end.x - 45, size.y - 4), "DAY %d" % maxi(0, count - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8299b1"))
