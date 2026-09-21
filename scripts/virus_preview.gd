extends SubViewportContainer

var specimen := Node3D.new()
var elapsed := 0.0
var dragging := false
var spin := true
var reduced_motion := false
var assembly: Tween
var specimen_camera: Camera3D

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
	camera.position = Vector3(0, 0, 5.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	specimen_camera = camera
	viewport.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("191b36")
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
	result.metallic = 0.12
	result.roughness = 0.48
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
	var base_color := Color("609adb").lerp(Color("c47aca"), severity)
	var shell := SphereMesh.new()
	shell.radius = 0.78 + properties.incubation_period * 0.012
	shell.height = shell.radius * 2
	specimen_camera.size = (shell.radius + 0.24 + properties.lethality * 0.65 + properties.mutation_rate * 2.3) * 2.5
	if properties.transmission_mode == "airborne":
		specimen_camera.size *= 1.15
	shell.radial_segments = 8 if properties.transmission_mode == "contact" else 48
	shell.rings = 24
	var body := mesh_node(shell, material(base_color.darkened(properties.recovery_rate * 0.35)), specimen)
	body.scale = Vector3(1, 1.15 if properties.transmission_mode == "airborne" else 1.0, 0.85 if properties.transmission_mode == "contact" else 1.0)
	for plate_index in range(int(properties.get("plates", 0)) * 3):
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(0.25, 0.1, 0.3)
		var angle_value := plate_index * 2.399963
		var plate := mesh_node(plate_mesh, material(Color("a99ddb")), body)
		plate.position = Vector3(cos(angle_value), sin(angle_value * 0.7) * 0.65, sin(angle_value)).normalized() * shell.radius
		plate.quaternion = Quaternion(Vector3.UP, plate.position.normalized())
	var count := int(18 + properties.infection_rate * 65)
	var spike_material := material(base_color.lightened(0.25))
	var tip_material := material(Color("b9f3df").lerp(Color("ffbd77"), properties.lethality))
	for index in range(count):
		var y := 1.0 - 2.0 * (index + 0.5) / count
		var angle := index * 2.399963 + float(int(properties.get("visual_seed", 0)) % 1000) * 0.01
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
	if spin and not dragging and not reduced_motion:
		specimen.rotation.y += delta * 0.22
	specimen.scale = Vector3.ONE if reduced_motion else Vector3.ONE * (1.0 + sin(elapsed * 1.6) * 0.012)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			specimen_camera.size = maxf(1.5, specimen_camera.size - 0.2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			specimen_camera.size = minf(7.0, specimen_camera.size + 0.2)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if event is InputEventMouseMotion and dragging:
		specimen.rotation.y += event.relative.x * 0.01
		specimen.rotation.x += event.relative.y * 0.01

func apply_profile(profile: Dictionary, animate := true) -> void:
	var zoom := specimen_camera.size
	rebuild(profile)
	specimen_camera.size = zoom
	if assembly:
		assembly.kill()
	if animate and not reduced_motion:
		assembly = create_tween().set_parallel(true)
		var body := specimen.get_child(0)
		for index in range(body.get_child_count()):
			var part := body.get_child(index)
			part.scale = Vector3.ONE * 0.05
			assembly.tween_property(part, "scale", Vector3.ONE, 0.3).set_delay(index * 0.002)

func reset_view() -> void:
	specimen.rotation = Vector3.ZERO
	specimen_camera.size = 3.6
