extends Node2D

@export var boid_cluster_count := 400
const boid_cluster_size := 128

var rd : RenderingDevice
var shader : RID
var uniform : RDUniform
var pipeline : RID
var buffer : RID
var uniform_set : RID

var data : PackedByteArray

@export var separation := 1.
@export var alignment := 1.
@export var cohesion := 1.
@export var speed := 1.
@export var max_speed := 5.

@export var friction := 0.99

@export var ease_separation := 10.
@export var ease_alignment := 1.

@export var edge_padding := 10.
@export var edge_influence := 1.

@export var influence_dist := 50.

@export var speed_variation := 0.

@export var reset := false
@export var display := true


func _ready() -> void:
	print("Boid count: ", boid_cluster_count * boid_cluster_size)
	
	_setup_data()
	_setup_compute()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	_sync_compute()
	
	if reset:
		reset = false
		_setup_data()
	
	_run_compute()
	
	if display:
		queue_redraw()


func _draw() -> void:
	var data_f = data.to_float32_array()
	
	var data_vec = PackedVector2Array([])
	 
	for i in boid_cluster_count * boid_cluster_size:
		var pos = Vector2(data_f[i * 4], data_f[i * 4 + 1])
		var vel = Vector2(data_f[i * 4 + 2], data_f[i * 4 + 3])
		
		data_vec.append(pos)
		data_vec.append(pos - vel.normalized() * 3)
	
	draw_multiline(data_vec, Color(1, 1, 1))

func _setup_data():
	randomize()
	
	var data_f := PackedFloat32Array([])
	
	data_f.resize(boid_cluster_count * boid_cluster_size * 4)
	data_f.fill(0)
	
	# Randomize positions
	for i in boid_cluster_count * boid_cluster_size:
		data_f[i * 4] = randf() * get_window().size.x
		data_f[i * 4 + 1] = randf() * get_window().size.y
		data_f[i * 4 + 2] = randf() * 2 - 1
		data_f[i * 4 + 3] = randf() * 2 - 1

	data = data_f.to_byte_array()


func _run_compute():
	rd.buffer_update(buffer, 0, data.size(), data)
	
	var push_constants = \
			PackedInt32Array([boid_cluster_count * boid_cluster_size]).to_byte_array() + \
			PackedFloat32Array([
				separation,
				alignment,
				cohesion,
				speed,
				friction,
				max_speed,
				ease_separation,
				ease_alignment,
				edge_influence,
				edge_padding,
				influence_dist,
				get_window().size.x,
				get_window().size.y,
				speed_variation, 0
			]).to_byte_array()
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_dispatch(compute_list, boid_cluster_count, 1, 1)
	rd.compute_list_end()
	
	rd.submit()


func _sync_compute():
	rd.sync()
	
	data = rd.buffer_get_data(buffer)


func _setup_compute():
	rd = RenderingServer.create_local_rendering_device()
	
	var spriv := preload("res://boids/boid_compute.glsl").get_spirv()
	shader = rd.shader_create_from_spirv(spriv)
	
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0
	
	pipeline = rd.compute_pipeline_create(shader)
	
	buffer = rd.storage_buffer_create(data.size(), data)
	uniform.add_id(buffer)
	
	uniform_set = rd.uniform_set_create([uniform], shader, 0)
	
	_run_compute()
