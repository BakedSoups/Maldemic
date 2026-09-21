extends SubViewportContainer

var specimen := Node3D.new()
var elapsed := 0.0
var dragging := false
var spin := true

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var viewport := SubViewport.new()
	viewport.size = Vector2i(500, 500)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(specimen)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 3.2)
	viewport.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0b1626")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("7fadc5")
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	for position_value in [Vector3(3, 4, 4), Vector3(-3, -1, 2)]:
		var light := OmniLight3D.new()
		light.position = position_value
		light.light_color = Color("b9fff1") if position_value.x > 0 else Color("a699ff")
		light.light_energy = 2.4
		light.omni_range = 12
		viewport.add_child(light)

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.25
	result.roughness = 0.32
	return result

func mesh_node(mesh: Mesh, surface: Material, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = surface
	parent.add_child(node)
	return node

func rebuild(properties: Dictionary) -> void:
	for child in specimen.get_children():
		specimen.remove_child(child)
		child.queue_free()
	var severity: float = properties.symptom_severity / 10.0
	var base_color := Color.from_hsv(0.46 - severity * 0.43, 0.68, 0.88)
	var shell := SphereMesh.new()
	shell.radius = 0.78 + properties.incubation_period * 0.012
	shell.height = shell.radius * 2
	shell.radial_segments = 48
	shell.rings = 24
	var body := mesh_node(shell, material(base_color.darkened(properties.recovery_rate * 0.35)), specimen)
	body.scale = Vector3(1, 1.15 if properties.transmission_mode == "airborne" else 1.0, 0.85 if properties.transmission_mode == "contact" else 1.0)
	var count := int(18 + properties.infection_rate * 65)
	var spike_material := material(base_color.lightened(0.25))
	var tip_material := material(Color("b9f3df").lerp(Color("ffbd77"), properties.lethality))
	for index in range(count):
		var y := 1.0 - 2.0 * (index + 0.5) / count
		var angle := index * 2.399963
		var direction := Vector3(cos(angle) * sqrt(1 - y * y), y, sin(angle) * sqrt(1 - y * y))
		var length_value: float = 0.18 + properties.lethality * 0.65 + sin(index * 7.1) * properties.mutation_rate * 2.0
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.025
		stalk.bottom_radius = 0.05
		stalk.height = length_value
		stalk.radial_segments = 8
		var spike := mesh_node(stalk, spike_material, body)
		spike.position = direction * (shell.radius + length_value / 2)
		spike.quaternion = Quaternion(Vector3.UP, direction)
		var tip := SphereMesh.new()
		tip.radius = 0.055 + properties.mutation_rate * 0.3
		tip.height = tip.radius * 2
		tip.radial_segments = 12
		tip.rings = 6
		mesh_node(tip, tip_material, body).position = direction * (shell.radius + length_value)

func _process(delta: float) -> void:
	elapsed += delta
	if spin and not dragging:
		specimen.rotation.y += delta * 0.22
	specimen.scale = Vector3.ONE * (1.0 + sin(elapsed * 1.6) * 0.012)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if event is InputEventMouseMotion and dragging:
		specimen.rotation.y += event.relative.x * 0.01
		specimen.rotation.x += event.relative.y * 0.01
