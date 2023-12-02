extends Node2D

enum MOUSE_MODE {PAN,DRAW}

@export var dimensions: Vector2i
@export var current_img: Image
@export var view_boundary: Rect2
@export var settings: Array[float]
@export var noise_texture: NoiseTexture2D

@onready var current_image = $CurrentImage
@onready var cam = $ViewCamera
@onready var rules_container = $CanvasLayer/GridContainer

const rule_button_tscn = preload("res://CGoL/rule_button.tscn")

var time_velocity: float = 0
var saved_velocity: float = 10
var mouse_button_pressed: int
var mouse_mode := MOUSE_MODE.DRAW

var rd: RenderingDevice
var pipeline: RID
var uniform_set: RID
var out_image_rid: RID
var in_image_rid: RID
var shader_rid: RID
var params_buffer_rid: RID
var param_uniform: RDUniform
var in_is_current_image: bool
var needs_to_update_images: bool

func _ready():
	display_image(create_image())
	init_gpu()
	for i in range(18):
		var rule_button = rule_button_tscn.instantiate()
		rule_button.button_pressed = settings[i] == 0
		rule_button.on_toggled.connect(on_rule_button_toggled)
		rules_container.add_child.call_deferred(rule_button)

func on_rule_button_toggled(toggled: bool, index: int) -> void:
	settings[index] = 0 if toggled else 1
	redo_params_uniform()

func redo_params_uniform() -> void:
	var params := PackedFloat32Array(settings)
	var params_bytes := params.to_byte_array()
	params_buffer_rid = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	
	param_uniform = RDUniform.new()
	param_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	param_uniform.binding = 0 # this needs to match the "binding" in our shader file
	param_uniform.add_id(params_buffer_rid)

func update_image_rids(update_other: bool = false) -> void:
	var image_format := RDTextureFormat.new()
	image_format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	image_format.width = dimensions.x
	image_format.height = dimensions.y
	image_format.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	if in_is_current_image:
		in_image_rid = rd.texture_create(image_format, RDTextureView.new(),[create_image().get_data()])
		if update_other:
			out_image_rid = rd.texture_create(image_format,RDTextureView.new())
	else:
		out_image_rid = rd.texture_create(image_format, RDTextureView.new(),[create_image().get_data()])
		if update_other:
			in_image_rid = rd.texture_create(image_format,RDTextureView.new())

func init_gpu():
	rd = RenderingServer.create_local_rendering_device()
	
	var shader_file := load("res://CGoL/compute_example.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	
	redo_params_uniform()
	
	update_image_rids(true)

# Called when the node enters the scene tree for the first time.
func init_pipeline():
	if needs_to_update_images:
		update_image_rids()
		needs_to_update_images = false
	
	# Create a uniform to assign the buffer to the rendering device
	var in_uniform := RDUniform.new()
	in_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	in_uniform.binding = 1 if in_is_current_image else 2
	in_uniform.add_id(in_image_rid)
	
	var out_uniform := RDUniform.new()
	out_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	out_uniform.binding = 2 if in_is_current_image else 1
	out_uniform.add_id(out_image_rid)
	
	uniform_set = rd.uniform_set_create([param_uniform,in_uniform,out_uniform], shader_rid, 0)
	
	# Create a compute pipeline
	pipeline = rd.compute_pipeline_create(shader_rid)

func create_image() -> Image:
	var image: Image
	if current_img == null:
		image = Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_L8)
		image.fill(Color(255,0,0))
	else:
		image = current_img
		if image.get_format() != Image.FORMAT_L8:
			image.convert(Image.FORMAT_L8)
	return image

func compute_step():
	var start_time = Time.get_ticks_usec()
	init_pipeline()
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, dimensions.x / 32, dimensions.y / 32, 1)
	rd.compute_list_end()
	
	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()
	# Read back the data from the buffer
	var output_bytes := rd.texture_get_data(out_image_rid if in_is_current_image else in_image_rid,0)
	var output := Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_L8, output_bytes)
	
	in_is_current_image = not in_is_current_image
	display_image(output)
	$CanvasLayer/TotalTimeLabel.text = "Computation Time Per Step: %s micro-seconds" % (Time.get_ticks_usec() - start_time)


func cleanup_gpu():
	# All resources must be freed after use to avoid memory leaks.

	rd.free_rid(pipeline)
	pipeline = RID()

	rd.free_rid(uniform_set)
	uniform_set = RID()

	rd.free_rid(out_image_rid)
	out_image_rid = RID()
	
	rd.free_rid(in_image_rid)
	in_image_rid = RID()
	
	rd.free_rid(shader_rid)
	shader_rid = RID()
	
	rd.free_rid(params_buffer_rid)
	params_buffer_rid = RID()
	
	rd.free()
	rd = null

func display_image(image: Image) -> void:
	# Create ImageTexture to display original on screen.
	var image_tex := ImageTexture.create_from_image(image)
	current_image.texture = image_tex
	current_img = image

func set_image(image: Image) -> void:
	display_image(image)
	needs_to_update_images = true

func _on_view_camera_step():
	compute_step()

func _on_time_velocity_value_changed(value):
	$CanvasLayer/Label.text = "Time Scale: %s steps per second" % (value)
	if value == 0:
		time_velocity = 0
		$Timer.stop()
		return
	time_velocity = 1.0 / value
	saved_velocity = value
	if $Timer.is_stopped():
		$Timer.start(time_velocity)
	

func _on_timer_timeout():
	$Timer.start(time_velocity)
	compute_step()

func draw(pos: Vector2):
	if pos.x > dimensions.x / 2 or pos.x < -dimensions.x / 2 or pos.y < -dimensions.y / 2 or pos.y > dimensions.y / 2:
		return
	$CanvasLayer/TimeVelocity.value = 0
	current_img.set_pixel(int(pos.x+dimensions.x/2),int(pos.y+dimensions.y/2),Color(0,0,0))
	set_image(current_img)

func erase(pos: Vector2):
	if pos.x > dimensions.x / 2 or pos.x < -dimensions.x / 2 or pos.y < -dimensions.y / 2 or pos.y > dimensions.y / 2:
		return
	$CanvasLayer/TimeVelocity.value = 0
	current_img.set_pixel(int(pos.x+dimensions.x/2),int(pos.y+dimensions.y/2),Color(255,0,0))
	set_image(current_img)

func _process(_delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mouse_button_pressed = MOUSE_BUTTON_LEFT
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		mouse_button_pressed = MOUSE_BUTTON_RIGHT
	else:
		mouse_button_pressed = -1

func _input(_event):
	if _event is InputEventMouseMotion:
		if view_boundary.has_point(get_viewport().get_mouse_position()):
			if mouse_mode == MOUSE_MODE.PAN and mouse_button_pressed == MOUSE_BUTTON_LEFT:
				cam.position -= _event.relative / cam.zoom.length()
			elif mouse_mode == MOUSE_MODE.DRAW:
				if mouse_button_pressed == MOUSE_BUTTON_LEFT:
					draw(get_global_mouse_position())
				elif mouse_button_pressed == MOUSE_BUTTON_RIGHT:
					erase(get_global_mouse_position())
	if _event is InputEventMouseButton:
		if view_boundary.has_point(get_viewport().get_mouse_position()):
			if mouse_mode == MOUSE_MODE.DRAW:
				if mouse_button_pressed == MOUSE_BUTTON_LEFT:
					draw(get_global_mouse_position())
				elif mouse_button_pressed == MOUSE_BUTTON_RIGHT:
					erase(get_global_mouse_position())
	if Input.is_action_just_pressed("zoom_in"):
		cam.zoom *= 1.2
		current_image.use_parent_material = cam.zoom.x < 6
	if Input.is_action_just_pressed("zoom_out"):
		cam.zoom *= 0.8
		current_image.use_parent_material = cam.zoom.x < 6
	if Input.is_action_just_pressed("step"):
		compute_step()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://main_menu.tscn")
	if Input.is_action_just_pressed("pause"):
		if time_velocity <= 0.00000000001:
			$CanvasLayer/TimeVelocity.value = saved_velocity
		else:
			$CanvasLayer/TimeVelocity.value = 0

func _on_pan_button_pressed():
	mouse_mode = MOUSE_MODE.PAN

func _on_draw_button_pressed():
	mouse_mode = MOUSE_MODE.DRAW

func _on_clear_button_pressed():
	var image = Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_L8)
	image.fill(Color(255,0,0))
	set_image(image)

func _on_upload_button_pressed():
	$FileDialog.show()

func _on_file_dialog_file_selected(path):
	var image: Image = load(path).get_image()
	image.convert(Image.FORMAT_L8)
	set_image(image)
	cam.position = Vector2.ZERO


func _on_button_pressed():
	var option_button = $CanvasLayer/HBoxContainer/OptionButton
	if option_button.selected == -1:
		return
	var path = "res://CGoL/examples/%s.png" % option_button.get_item_text(option_button.selected).to_snake_case()
	_on_file_dialog_file_selected(path)

func _on_scramble_button_pressed():
	noise_texture.noise.seed = Time.get_ticks_msec()
	var image = noise_texture.get_image()
	set_image(image)
	cam.position = Vector2.ZERO
