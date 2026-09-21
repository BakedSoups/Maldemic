extends Area3D

var rich_text_label = null

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	

func _on_body_entered(body):
	if is_camera_related(body):
		update_text(name)
	
func _on_body_exited(body):
	if is_camera_related(body):
		update_text(name)
		
func _on_area_entered(area):
	if is_camera_related(area):
		update_text(name)
		
func _on_area_exited(area):
	if is_camera_related(area):
		update_text(name)
		
func is_camera_related(node):
	var current = node

	while current:
		if current.name == "Camera3D":
			return true
		current = current.get_parent()
	return false

func update_text(message):
	Data.Current_City = str(message).to_upper()
