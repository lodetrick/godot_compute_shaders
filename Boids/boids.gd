extends Node2D

const boid_texture = preload("res://Boids/boid.png")

@export var parameters: Array[float]
#num boids
#max speed
#acceleration
#rule 1 distance
#rule 1 strength
#rule 2 distance
#rule 2 strength
#rule 3 distance
#rule 3 strength
#time velocity
@export var boid_buffer: PackedFloat32Array
#posx
#posy
#velx
#vely

var swapped: bool = false
var rd: RenderingDevice
var pipeline: RID
var uniform_set: RID
var shader_rid: RID
var boid_in_buffer_rid: RID
var boid_out_buffer_rid: RID
var params_buffer_rid: RID
var param_uniform: RDUniform

var saved_velocity: float = 50
var is_ready: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	boid_buffer.resize(int(4 * parameters[0]))
	for i in range(parameters[0]):
		boid_buffer[4*i] = randf_range(0,700)
		boid_buffer[4*i+1] = randf_range(0,500)
		boid_buffer[4*i+2] = randf_range(-1,1)
		boid_buffer[4*i+3] = randf_range(-1,1)
	
	init_gpu()
	$CanvasLayer/GridContainer/Rule_One_Distance.value = parameters[3]
	$CanvasLayer/GridContainer/Rule_One_Strength.value = parameters[4]
	$CanvasLayer/GridContainer/Rule_Two_Distance.value = parameters[5]
	$CanvasLayer/GridContainer/Rule_Two_Strength.value = parameters[6]
	$CanvasLayer/GridContainer/Rule_Three_Distance.value = parameters[7]
	$CanvasLayer/GridContainer/Rule_Three_Strength.value = parameters[8]
	is_ready = true
	
func _draw():
	if not is_ready:
		await ready
	seed(10)
	draw_rect(Rect2(400,100,700,500),Color.BLACK,false)
	if $BoidInstances.multimesh.get_instance_count() != parameters[0]:
		$BoidInstances.multimesh.set_instance_count(parameters[0])
	
	for i in range(parameters[0]):
		var transform = Transform2D().scaled(Vector2(10, 10)).rotated(Vector2(boid_buffer[i*4+3],-boid_buffer[i*4+2]).angle()).translated(Vector2(400+boid_buffer[i*4],100+boid_buffer[i*4+1]))
		$BoidInstances.multimesh.set_instance_transform_2d(i, transform)
		$BoidInstances.multimesh.set_instance_color(i, Color(abs(boid_buffer[i*4+2]),0,abs(boid_buffer[i*4+3])))
		if i % 256 == 0:
			var xform = Transform2D().rotated(Vector2(-boid_buffer[i*4+3],boid_buffer[i*4+2]).angle()).translated(Vector2(400+boid_buffer[i*4],100+boid_buffer[i*4+1]))
			draw_set_transform_matrix(xform)
			draw_arc(Vector2.ZERO,parameters[3],0,TAU,50,Color.RED)
			draw_arc(Vector2.ZERO,parameters[5],0,TAU,50,Color.GREEN)
			draw_arc(Vector2.ZERO,parameters[7],0,TAU,50,Color.BLUE)
	#	var xform = Transform2D().rotated(Vector2(-boid_buffer[i*4+3],boid_buffer[i*4+2]).angle()).translated(Vector2(400+boid_buffer[i*4],100+boid_buffer[i*4+1]))
	#	draw_set_transform_matrix(xform)
	#	draw_colored_polygon(PackedVector2Array([Vector2(0,-6),Vector2(4,6),Vector2(-4,6)]),Color(abs(boid_buffer[i*4+2]),0,abs(boid_buffer[i*4+3])))
	#	#draw_texture(boid_texture,Vector2(-8,-8),Color(abs(boid_buffer[i*4+2]),0,abs(boid_buffer[i*4+3])))
	#	draw_circle(Vector2.ZERO,1,Color.BLACK)
	#	draw_line(Vector2.ZERO,Vector2(0,-1) * Vector2(boid_buffer[i*4+2],boid_buffer[i*4+3]).length() * 10,Color.GREEN)
	#	if i % 256 == 0:
	#		draw_arc(Vector2.ZERO,parameters[3],0,TAU,50,Color.RED)
	#		draw_arc(Vector2.ZERO,parameters[5],0,TAU,50,Color.GREEN)
	#		draw_arc(Vector2.ZERO,parameters[7],0,TAU,50,Color.BLUE)

func init_gpu():
	rd = RenderingServer.create_local_rendering_device()
	
	var shader_file := load("res://Boids/boids.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	
	set_params_uniform()
	
	var boid_in_buffer_bytes := boid_buffer.to_byte_array()
	boid_in_buffer_rid = rd.storage_buffer_create(boid_in_buffer_bytes.size(), boid_in_buffer_bytes)
	
	var empty_buffer := PackedFloat32Array()
	empty_buffer.resize(boid_buffer.size())
	var boid_out_buffer_bytes := empty_buffer.to_byte_array()
	boid_out_buffer_rid = rd.storage_buffer_create(boid_out_buffer_bytes.size(), boid_out_buffer_bytes)

func set_params_uniform() -> void:
	var params := PackedFloat32Array(parameters)
	var params_bytes := params.to_byte_array()
	params_buffer_rid = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	
	param_uniform = RDUniform.new()
	param_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	param_uniform.binding = 0 # this needs to match the "binding" in our shader file
	param_uniform.add_id(params_buffer_rid)

func init_pipeline():
	var boid_in_buffer_uniform := RDUniform.new()
	boid_in_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	boid_in_buffer_uniform.binding = 2 if swapped else 1 # this needs to match the "binding" in our shader file
	boid_in_buffer_uniform.add_id(boid_in_buffer_rid)
	
	var boid_out_buffer_uniform := RDUniform.new()
	boid_out_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	boid_out_buffer_uniform.binding = 1 if swapped else 2# this needs to match the "binding" in our shader file
	boid_out_buffer_uniform.add_id(boid_out_buffer_rid)
	
	uniform_set = rd.uniform_set_create([param_uniform,boid_in_buffer_uniform,boid_out_buffer_uniform], shader_rid, 0)
	pipeline = rd.compute_pipeline_create(shader_rid)

func compute_step():
	var start_time = Time.get_ticks_usec()
	init_pipeline()
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, parameters[0] / 512, 1, 1)
	rd.compute_list_end()
	
	rd.submit()
	rd.sync()
	
	#get output
	var output_bytes := rd.buffer_get_data(boid_in_buffer_rid if swapped else boid_out_buffer_rid)
	boid_buffer = output_bytes.to_float32_array()
	queue_redraw()
	swapped = not swapped
	$CanvasLayer/TotalTimeLabel.text = "Computation Time Per Step: %s micro-seconds" % (Time.get_ticks_usec() - start_time)

func _input(_event):
	if Input.is_action_just_pressed("step"):
		compute_step()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://main_menu.tscn")
	if Input.is_action_just_pressed("pause"):
		if parameters[9] <= 0:
			$CanvasLayer/HSlider.value = saved_velocity
		else:
			$CanvasLayer/HSlider.value = 0

func _on_h_slider_value_changed(value):
	parameters[9] = value
	if value != 0:
		saved_velocity = value
		$Timer.start(1 / value)

func _on_timer_timeout():
	if parameters[9] != 0:
		$Timer.start(1 / parameters[9])
	compute_step()

func _on_rule_one_distance_value_changed(value):
	parameters[3] = value
	set_params_uniform()

func _on_rule_one_strength_value_changed(value):
	parameters[4] = value
	set_params_uniform()

func _on_rule_two_distance_value_changed(value):
	parameters[5] = value
	set_params_uniform()

func _on_rule_two_strength_value_changed(value):
	parameters[6] = value
	set_params_uniform()

func _on_rule_three_distance_value_changed(value):
	parameters[7] = value
	set_params_uniform()

func _on_rule_three_strength_value_changed(value):
	parameters[8] = value
	set_params_uniform()
