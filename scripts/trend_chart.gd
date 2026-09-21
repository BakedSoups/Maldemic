extends Control

const COLORS = [Color("7dacf3"), Color("f08cba"), Color("74d4d5"), Color("b5a1ec")]

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
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("2b2e49"))
		var amount := peak * (1.0 - tick / 4.0)
		var caption := "%.1fm" % (amount / 1000000) if amount >= 1000000 else "%.0fk" % (amount / 1000)
		draw_string(font, Vector2(0, y + 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("969dbc"))
	for series in range(4):
		var points := PackedVector2Array()
		for index in range(histories[series].size()):
			points.append(Vector2(area.position.x + area.size.x * index / maxf(1, count - 1), area.end.y - area.size.y * histories[series][index] / peak))
		if points.size() > 1:
			# Fill each segment separately, avoiding duplicate baseline vertices
			# when a series starts at zero or stays below a subpixel height.
			for index in range(1, points.size()):
				var first := points[index - 1]
				var second := points[index]
				if area.end.y - maxf(first.y, second.y) > 0.1:
					draw_colored_polygon(PackedVector2Array([first, second, Vector2(second.x, area.end.y), Vector2(first.x, area.end.y)]), Color(COLORS[series], 0.07))
			draw_circle(points[-1], 2.5, COLORS[series])
			draw_polyline(points, COLORS[series], 2.0, true)
		elif points.size() == 1:
			draw_circle(points[0], 3, COLORS[series])
	draw_string(font, Vector2(area.position.x, size.y - 4), "DAY 0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("969dbc"))
	draw_string(font, Vector2(area.end.x - 45, size.y - 4), "DAY %d" % maxi(0, count - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("969dbc"))
