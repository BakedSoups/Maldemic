extends Control

var tint := Color("8c9dff")
var variant := 0

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.25
	var count := 8 + variant * 2
	draw_circle(center, radius * 1.5, Color(tint, 0.07))
	for index in range(count):
		var angle := TAU * index / count
		var direction := Vector2(cos(angle), sin(angle))
		var tip := center + direction * radius * (1.55 + 0.15 * sin(index * 3.0))
		draw_line(center + direction * radius * 0.7, tip, Color(tint, 0.8), 1.5, true)
		draw_circle(tip, 2.0, tint)
	draw_circle(center, radius, Color(tint, 0.2))
	draw_arc(center, radius, 0, TAU, 40, tint, 1.2, true)
	for index in range(5):
		var point := center + Vector2(cos(index * 2.4), sin(index * 2.4)) * radius * 0.55
		draw_circle(point, 1.7, tint.lightened(0.25))
