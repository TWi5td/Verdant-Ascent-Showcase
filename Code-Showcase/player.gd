extends CharacterBody3D

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var input_dir: Vector2 = Vector2.ZERO	# Initialize 2D Direction traject

#region variables
# velocity
@export_group("velocity")
@export var jump_velocity: float = 4.0
@export var ground_friciton: float = 5
@export var air_friciton: float = 2
@export var air_strafe_control: float = 0.7			# control for left/right/backward in the air
@export var air_strafe_acceleration: float = 4.0	# how fast you can strafe in the air

# speed
@export_group("speed")
@export var speed: float = 8.0
@export var crouch_speed: float = 5.0

# sprint
@export_group("sprint")
@export var sprint_factor: float = 1.0
@export var sprint_acceleration: float = 0.95
var is_sprinting: bool = false

# input buffer time
@export_group("input buffer")
@export var jump_buffer_time: float = 150.0		# time in ms

# capsule collision height
@export_group("capsule height")
var cached_shape: CapsuleShape3D
@export var capsule_height: float = 2.0
@export var capsule_crouch_height: float = 1.0
var target_capsule_height: float
var current_capsule_height: float

# camera height
@export_group("camera height")
@export var camera_height: float = 1.0
@export var camera_crouch_height: float = 0.3
#@export var camera_crouch_offset: float = 0.5	#lowers camera when crouching
#var target_camera_height: float
#var current_camera_height: float
var is_crouching: bool = false

# slide
@export_group("slide")
@export var slide_duration: float = 0.8
@export var slide_speed: float = 0.2	# initial slide boost
@export var slide_friction: float = 0.8
@export var slide_cooldown: float = 0.5
@export var min_sprint_with_slide: float = 0.5
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0
var sprint_timer: float = 0.0

# wall mechanics
@export_group("wall mechanics")
@export var wall_attach_distance: float = 0.7		# how close to stick to wall
@export var wall_detach_distance: float = 1.0		# how far before you detach
@export var wall_stick_speed: float = 6.0			# wall ride speed
@export var wall_gravity: float = 2.0				# reduce gravity while wall riding
@export var wall_perch_gravity: float = 0.1			# slow fall when perching
@export var perch_slide_speed: float = 0.5 			# slow slide acceleration when perching
@export var wall_jump_up: float = 6.0 				# upward force
@export var wall_jump_push: float = 8.0 			# horizontal push away from wall
@export var wall_jump_input_blend: float = 0.5		# how much player input affects direction
@export var wall_jump_camera_blend: float = 0.1		# how much camera direction affects direction
@export var wall_jump_keep_momentum: float = 0.4 	# how much speed to keep from wall riding
var is_wall_riding: bool = false
var is_perching: bool = false
var wall_normal: Vector3 = Vector3.ZERO 			# stores the wall surface
var wall_surface: Vector3 = Vector3.ZERO			# stores current surface
var can_wall_jump: bool = false

# wall ride camera
@export_group("wall ride camera")
@export var wall_ride_tilt_angle: float = deg_to_rad(10.0)
@export var wall_ride_tilt_speed: float = 4.0
@export var wall_ride_dynamic_tilt: bool = true
@export var wall_ride_speed_tilt_multiplier: float = 0.4
@export var wall_ride_height_tilt_multiplier: float = 0.2
@export var wall_ride_transition_curve: float = 2.0
@export var wall_ride_camera_shake: bool = true
@export var wall_ride_shake_intensity: float = 0.02
@export var wall_ride_shake_speed: float = 15.0
@export var wall_ride_look_ahead: bool = true
@export var wall_ride_look_ahead_amount: float = 0.15
@export var wall_ride_vertical_offset: bool = true
@export var wall_ride_vertical_offset_amount: float = 0.1
var current_wall_tilt: float = 0.0
var wall_ride_time: float = 0.0
var previous_wall_normal: Vector3 = Vector3.ZERO
var wall_transition_progress: float = 0.0
var camera_shake_offset: Vector3 = Vector3.ZERO
var look_ahead_offset: Vector3 = Vector3.ZERO
var wall_vertical_offset: float = 0.0

# camera FOV
@export_group("FOV")
@export var player_fov: float = 75.0
@export var fov_transition_speed: float = 5.0
@export var wall_ride_fov_change: float = 0.5
var sprint_fov_change: float = 10.0

# camera tilt
@export_group("camera tilt")
@export var tilt_lower_limit: float = deg_to_rad(-90.0)
@export var tilt_upper_limit: float = deg_to_rad(90.0)
@export var mouse_sensitivity: float = 0.1

# camera bobbing
@export_group("camera bobbing")
@export var bob_amp: float = 0.06
@export var bob_x_amp: float = 0.03
@export var bobbing: float = 8.0
@export var bob_speed: float = 50.0
@export var bob_tilt_amp: float = deg_to_rad(1.5)
@export var bob_tilt_speed: float = 8.0
var bob_time: float = 0.0
var debug_bob: bool = false

# sprint boost
var active_boost_timer: float = 0.0
var base_sprint_factor: float = 2.0

# wall coyote time
var wall_coyote_time: float = 0.25 # seconds after leaving wall
var wall_coyote_timer: float = 0.0

# onready varibles
@onready var pivot: Node3D = $Pivot
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var initial_collider_pos: Vector3 = collider.position
@onready var mesh: MeshInstance3D = $Pivot/MeshInstance3D
@onready var initial_mesh_position: Vector3 = mesh.position
@onready var head_rig: Node3D = $Pivot/HeadRig
@onready var camera_3d: Camera3D = $Pivot/HeadRig/Camera3D
@onready var wall_check_ray: RayCast3D = $WallCheckRay
#endregion

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED	# lock mouse to center of window
	#print(camera_control.global_transform.origin)   # see where camera is
	
	mesh.visible = false
	
	# initialize capsule height
	current_capsule_height = capsule_height
	target_capsule_height = capsule_height
	
	## initialize camera height
	#current_camera_height = camera_height
	#target_camera_height = camera_height
	
	# wall check
	wall_check_ray.target_position = Vector3(0, 0, -wall_attach_distance)
	wall_check_ray.enabled = true
	
	cached_shape = collider.shape as CapsuleShape3D
	# pre-calculate constants
	set_physics_process(true)
	set_process_unhandled_input(true)

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	update_camera(delta)
	 
	input_dir.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_dir.y = Input.get_action_strength("forward") - Input.get_action_strength("backward")
	
	# check wall contact and update wall normal
	check_wall_contact()
	
	if wall_coyote_timer > 0.0:
		wall_coyote_timer -= delta
	
	# handle boost timer
	if active_boost_timer > 0.0:
		active_boost_timer -= delta
		if active_boost_timer <= 0.0:
			sprint_factor = base_sprint_factor
	
		# check Sprint input
	if Input.is_action_pressed("sprint") and not is_crouching and not is_perching and not is_wall_riding:
		is_sprinting = true
		sprint_factor = lerp(sprint_factor, 2.0, delta * sprint_acceleration)
		sprint_timer += delta
	else:
		is_sprinting = false
		sprint_factor = lerp(sprint_factor, 1.0, delta * sprint_acceleration)
		sprint_timer = 0.0
	
		# check Crouch input only when on floor
	if Input.is_action_pressed("crouch") and not is_sliding:
		if is_on_floor():
			is_crouching = true
			is_perching = false
			is_wall_riding = false
			target_capsule_height = capsule_crouch_height
		# wall perching
		elif is_on_wall() and can_wall_jump:
			is_perching = true
			is_crouching = false
			is_wall_riding = false
	elif not is_sliding:
		is_crouching = false
		is_perching = false
		target_capsule_height = capsule_height
	
	# check slide input
	if is_on_floor() and not is_sliding and slide_cooldown_timer <= 0.0:
		if Input.is_action_pressed("crouch") and is_sprinting and sprint_timer >=min_sprint_with_slide:
			start_slide()
	
	# wall movement
	if is_wall_riding:
		# project input on wall plane
		wall_ride_time += delta		# track time on wall
		var input_move: Vector3 = get_movement_direction()
		var wall_parallel: Vector3 = input_move - wall_normal * input_move.dot(wall_normal)
		
		if wall_parallel.length() > 0.1:
			wall_parallel = wall_parallel.normalized()
			var target_velocity: Vector3 = wall_parallel * wall_stick_speed
			velocity.x = lerp(velocity.x, target_velocity.x, delta * 12.0)
			velocity.z = lerp(velocity.z, target_velocity.z, delta * 12.0)
		else:
			velocity.x = lerp(velocity.x, 0.0, delta * 3.0)
			velocity.z = lerp(velocity.z, 0.0, delta * 3.0)
		velocity.y -= wall_gravity * delta
	else:
		wall_ride_time = 0.0
		
	if is_perching:
		velocity.y -= gravity * wall_perch_gravity
		velocity.y = max(velocity.y, -perch_slide_speed)
		# horizontal decay
		velocity.x = lerp(velocity.x, 0.0, delta * 2.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 2.0)
	
	if input_dir.length() > 0 and not is_perching and not is_sliding:	# Aceleration
		input_dir = input_dir.normalized()		# check that diagonal movement is fixed to 1
		var move_direction: Vector3 = get_movement_direction()
		var move_speed: float = (crouch_speed if is_crouching else speed) * sprint_factor
		if is_on_floor():
			# full control
			velocity.x = move_direction.x * move_speed
			velocity.z = move_direction.z * move_speed
		else:
			handle_air_control(move_speed, delta)
	
	elif not is_sliding:
		if is_wall_riding:
			velocity.x = lerp(velocity.x, 0.0, delta * 2.0) # weight of deceleration in the x direction
			velocity.z = lerp(velocity.z, 0.0, delta * 2.0) # weight of deceleration in the z direction
		else:
			var friction: float = air_friciton if not is_on_floor() else ground_friciton
			velocity.x = lerp(velocity.x, 0.0, delta * friction) # weight of deceleration in the x direction
			velocity.z = lerp(velocity.z, 0.0, delta * friction) # weight of deceleration in the z direction
	
	# handle jump input buffer
	if Input.is_action_just_pressed("jump"):
		InputBuffer.buffer_action("jump")
	# execute jumps
	handle_jumping()
	
	# apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# slow down when sliding
	if is_sliding:
		slide_timer -= delta
		velocity.x = lerp(velocity.x, 0.0, delta * slide_friction)
		velocity.z = lerp(velocity.z, 0.0, delta * slide_friction)
		if slide_timer <= 0.0 or not is_on_floor():
			end_slide()
		elif not Input.is_action_pressed("crouch"):
			end_slide()
	
	update_player_height(delta)
	
	# slide cooldown
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer -= delta
	
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")

var mouse_input: bool = false
var mouse_rotation: Vector3
var rotation_input: float
var tilt_input: float
func _unhandled_input(event: InputEvent) -> void:		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:	# check if mouse is being moved
		rotation_input = -event.relative.x * mouse_sensitivity	# look horizontal direction
		tilt_input = -event.relative.y * mouse_sensitivity		# look verticle direction
		# prevent accumulation
		get_viewport().set_input_as_handled()

func update_camera(delta: float) -> void:
	# controller look input
	if ControllerManager.is_controller_connected() and ControllerManager.use_controller:
		var controller_look := ControllerManager.get_look_input()
		if controller_look.length() > 0.01:  # Small deadzone to prevent drift
			rotation_input -= controller_look.x / get_process_delta_time()
			tilt_input -= controller_look.y / get_process_delta_time()
	
	mouse_rotation.x += tilt_input * delta											# tilt velocity
	mouse_rotation.x = clamp(mouse_rotation.x, tilt_lower_limit, tilt_upper_limit)	# lock max and min look to straight up and down
	mouse_rotation.y += rotation_input * delta										# horizontal (yaw)
	
	# apply player yaw rotation
	pivot.transform.basis = Basis.from_euler(Vector3(0.0, mouse_rotation.y, 0.0))
	
	# apply camera pitch tilt
	camera_3d.transform.basis = Basis.from_euler(Vector3(mouse_rotation.x, 0.0, 0.0))
	
	# wall riding camera tilt
	var target_tilt: float = 0.0
	var target_verticle_offset: float = 0.0
	
	if can_wall_jump and wall_normal != Vector3.ZERO:
		# tilt toward wall side
		var player_wall_side: Vector3 = (wall_surface - global_position).normalized()
		var camera_right: Vector3 = get_camera_right()
		var dot: float = player_wall_side.dot(camera_right)
		var tilt_direction: float = sign(dot)
		
		# base tilt angle
		target_tilt = tilt_direction * wall_ride_tilt_angle
		
		# dynamic tilt based on speed
		if wall_ride_dynamic_tilt:
			var speed_factor: float = get_horizontal_velocity().length() / speed
			speed_factor = clamp(speed_factor, 0.0, 2.0)
			target_tilt *= (1.0 + (speed_factor * wall_ride_speed_tilt_multiplier))
			
			# height based tilt modifier
			var height_factor: float = clamp((global_position.y - wall_surface.y) / 5.0, 0.0, 1.0)
			target_tilt *= (1.0 + (height_factor * wall_ride_height_tilt_multiplier))
		
		# smooth wall to wall transition
		if previous_wall_normal != wall_normal and previous_wall_normal != Vector3.ZERO:
			wall_transition_progress = 0.0
		previous_wall_normal = wall_normal
		
		if wall_transition_progress < 1.0:
			wall_transition_progress = min(wall_transition_progress + (delta * wall_ride_tilt_speed), 1.0)
			var t: float = ease(wall_transition_progress, wall_ride_transition_curve)
			target_tilt *= t
		
		# camera shake
		if is_wall_riding and wall_ride_camera_shake and get_horizontal_velocity().length() > speed * 0.5:
			var shake_time: float = wall_ride_time * wall_ride_shake_speed
			camera_shake_offset = Vector3((sin(shake_time * 1.3) * wall_ride_shake_intensity), (cos(shake_time * 0.9) * wall_ride_shake_intensity * 0.5), 0.0)
		else:
			camera_shake_offset = camera_shake_offset.lerp(Vector3.ZERO, delta * 10.0)
		
		# look ahead in movement direction
		if wall_ride_look_ahead and velocity.length() > 0.1:
			var velocity_normalized: Vector3 = velocity.normalized()
			look_ahead_offset = velocity_normalized * wall_ride_look_ahead_amount
			look_ahead_offset.y *= 0.3		# reduce vertical look ahead
		
		# vertical camera offset based on wall position
		if wall_ride_vertical_offset:
			# shift camera away from wall
			target_verticle_offset = wall_normal.y * wall_ride_vertical_offset_amount
	
	elif is_perching:
		target_tilt = 0.0
		camera_shake_offset = camera_shake_offset.lerp(Vector3.ZERO, delta * 10.0)
		look_ahead_offset = look_ahead_offset.lerp(Vector3.ZERO, delta * 5.0)
	
	else:
		# reset all effects
		wall_transition_progress = 1.0
		previous_wall_normal = Vector3.ZERO
		camera_shake_offset = camera_shake_offset.lerp(Vector3.ZERO, delta * 10.0)
		look_ahead_offset = look_ahead_offset.lerp(Vector3.ZERO, delta * 5.0)
	
	# apply tilt
	current_wall_tilt = lerp(current_wall_tilt, target_tilt, delta * wall_ride_tilt_speed)
	wall_vertical_offset = lerp(wall_vertical_offset, target_verticle_offset, delta * wall_ride_tilt_speed)
	
	# FOV
	var target_fov: float = player_fov
	if is_sprinting:
		target_fov = player_fov + sprint_fov_change
	elif is_wall_riding:
		var speed_fov_factor: float = clamp(get_horizontal_velocity().length() / (speed * 2.0), 0.0, 1.0)
		target_fov = player_fov + (sprint_fov_change * wall_ride_fov_change * (1.0 + (speed_fov_factor * 0.5)))
	camera_3d.fov = lerp(camera_3d.fov, target_fov, delta * fov_transition_speed)
	
	var target_head_y: float
	if is_sliding:
		target_head_y = camera_crouch_height * 0.3
	elif is_crouching or is_perching:
		target_head_y = camera_crouch_height * 0.6
	else:
		target_head_y = camera_height * 0.75
	# prevent camera floor clipping
	target_head_y += wall_vertical_offset
	target_head_y = max(target_head_y, 0.1)
	
	# camera bobbing
	var head_bob_y: float = 0.0
	var head_bob_x: float = 0.0
	var head_bob_tilt: float = 0.0
	if (not is_sliding and not is_crouching and not is_perching and input_dir.length() and is_on_floor()):
		bob_time += delta * bobbing * (sprint_factor if is_sprinting else 1.0)
		head_bob_y = sin(bob_time) * bob_amp
		head_bob_x = sin(bob_time) * bob_x_amp
		head_bob_tilt = cos(bob_time) * bob_tilt_amp
	else:
		bob_time = 0.0
	
	# apply camera transformations
	var final_head_x: float = head_bob_x + camera_shake_offset.x + look_ahead_offset.x
	var final_head_y: float = head_bob_y + camera_shake_offset.y + look_ahead_offset.y
	head_rig.position.x = lerp(head_rig.position.x, final_head_x, delta * 10.0)
	head_rig.position.y = lerp(head_rig.position.y, final_head_y, delta * 10.0)
	head_rig.rotation.z = lerp(head_rig.rotation.z, current_wall_tilt + head_bob_tilt, delta * wall_ride_tilt_speed)
	
	# prevent camera drift
	rotation_input = 0.0
	tilt_input = 0.0
	

func start_slide() -> void:
	is_sliding = true
	is_crouching = true
	slide_timer = slide_duration
	slide_cooldown_timer = slide_cooldown
	target_capsule_height = capsule_crouch_height
	
	# maintain velocity & add slide boost
	var horizontal_velocity: Vector3 = get_horizontal_velocity()
	if horizontal_velocity.length() > 0:
		velocity.x = horizontal_velocity.x * slide_speed
		velocity.z = horizontal_velocity.z * slide_speed
	else:
		# if no velocity
		var forward: Vector3 = get_camera_forward()
		velocity.x = forward.x * speed * slide_speed
		velocity.z = forward.z * speed * slide_speed

func end_slide() -> void:
	is_sliding = false
	if not Input.is_action_pressed("crouch"):
		is_crouching = false
		target_capsule_height = capsule_height

func check_wall_contact() -> void:
	can_wall_jump = false
	is_wall_riding = false
	is_perching = false
	wall_normal = Vector3.ZERO
	wall_surface = Vector3.ZERO
	
	# collision from move_and_slide()
	if is_on_wall():
		# get wall normal from previous collision
		for i in range(get_slide_collision_count()):
			var collision: KinematicCollision3D = get_slide_collision(i)
			var normal: Vector3 = collision.get_normal()
			# not floor
			if normal.y < 0.7:
				wall_normal = normal
				wall_surface = collision.get_position()
				can_wall_jump = true
				break
	
	# Raycast check for wall proximity
	if wall_check_ray.is_colliding():
		var point: Vector3 = wall_check_ray.get_collision_point()
		var distance: float = global_position.distance_to(point)
		var normal: Vector3 = wall_check_ray.get_collision_normal()
		if normal.y < 0.7 and distance <= wall_attach_distance:
			wall_normal = normal
			wall_surface = point
			can_wall_jump = true
	
	# wall ride logic (attach/detach)
	if can_wall_jump and wall_normal != Vector3.ZERO:
		var to_wall: Vector3 = (wall_surface - global_position)
		to_wall.y = 0
		var lateral_input: float = input_dir.x	# only strafe left/right
		
		# attach when moving into wall
		if lateral_input != 0 and sign(lateral_input) == sign(to_wall.normalized().dot(pivot.global_transform.basis.x)):
			if to_wall.length() <= wall_attach_distance:
				is_wall_riding = true
				wall_coyote_timer = wall_coyote_time
		
		# detach if moving too far from wall
		if is_wall_riding:
			if to_wall.length() > wall_detach_distance:
				is_wall_riding = false
				wall_coyote_timer = wall_coyote_time
			elif sign(lateral_input) != sign(to_wall.normalized().dot(pivot.global_transform.basis.x)):
				is_wall_riding = false
				wall_coyote_timer = wall_coyote_time
		
		# perch with crouch override
		if Input.is_action_pressed("crouch") and not is_on_floor():
			is_perching = true
			is_wall_riding = false
			wall_coyote_timer = wall_coyote_time
	else:
		is_wall_riding = false
		is_perching = false

func get_camera_forward() -> Vector3:
	var forward: Vector3 = -pivot.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

func get_camera_right() -> Vector3:
	return pivot.global_transform.basis.x

func get_movement_direction() -> Vector3:
	if input_dir.length() == 0:
		return Vector3.ZERO
	var forward: Vector3 = -pivot.global_transform.basis.z
	var right: Vector3 = pivot.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	# safety check
	if forward.length() > 0.001:
		forward = forward.normalized()
	if right.length() > 0.001:
		right = right.normalized()
	return ((forward * input_dir.y) + (right * input_dir.x)).normalized()

func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)

func handle_air_control(move_speed: float, delta: float) -> void:
			# seperate forward and strafe
			var forward: Vector3 = -pivot.global_transform.basis.z
			var right: Vector3 = pivot.global_transform.basis.x
			forward.y = 0.0
			right.y = 0.0
			forward = forward.normalized()
			right = right.normalized()
			
			var forward_component: Vector3 = forward * input_dir.y * move_speed * air_strafe_control	# forward movement
			var strafe_component: Vector3 = right * input_dir.x * move_speed * air_strafe_control		# strafe movement
			# project current velocity on axes
			var current_forward: float = Vector3(velocity.x, 0, velocity.z).dot(forward)
			var current_strafe: float = Vector3(velocity.x, 0, velocity.z).dot(right)
			
			# full control forward
			var target_forward: float = forward_component.dot(forward)
			var new_forward: float = lerp(current_forward, target_forward, delta * air_strafe_acceleration)
			
			# limited strafe
			var target_strafe: float = strafe_component.dot(right)
			var new_strafe: float = lerp(current_strafe, target_strafe, delta * air_strafe_acceleration)
			
			velocity.x = (forward.x * new_forward) + (right.x * new_strafe)
			velocity.z = (forward.z * new_forward) + (right.z * new_strafe)

func apply_sprint_boost(multiplier: float, time: float) -> void:
	sprint_factor *= multiplier
	active_boost_timer = time

func handle_jumping() -> void:
	# check for buffered input
	var wants_to_jump := InputBuffer.consume_action("jump", (jump_buffer_time / 1000))
	
	if not wants_to_jump:
		return
	
	if is_on_floor():
		perform_regular_jump()
	elif (is_on_wall() and can_wall_jump) or wall_coyote_timer > 0.0:
		perform_wall_jump()
	elif is_perching:
		perform_perch_jump()
	else:
		# rebuffer input
		InputBuffer.buffer_action("action")

func perform_regular_jump() -> void:
	velocity.y = jump_velocity
	is_perching = false
	# print("regular jump executed")

func perform_wall_jump() -> void:
	# apply positive y force
	velocity.y = wall_jump_up
	
	# push away from wall using wall normal
	var push_direction: Vector3 = wall_normal
	push_direction.y = 0 # keep wall push horizontal
	push_direction = push_direction.normalized()
	
	# blend wall normal with camera forward direction for more control
	var camera_forward: Vector3 = get_camera_forward()
	
	var input_dir_3d: Vector3 = Vector3.ZERO
	if input_dir.length() > 0:
		input_dir_3d = get_movement_direction()
	
	var final_dir: Vector3 = push_direction
	if input_dir_3d.length() > 0:
		final_dir = (push_direction * (1.0 - wall_jump_input_blend - wall_jump_camera_blend) + (input_dir_3d * wall_jump_input_blend) + (camera_forward * wall_jump_camera_blend)).normalized()
	else:
		final_dir = ((push_direction * 0.7) + (camera_forward * 0.3))
	
	var horizontal_velocity: Vector3 = get_horizontal_velocity()
	var keep_speed: float = horizontal_velocity.length() * wall_jump_keep_momentum
	var push_speed: float = wall_jump_push + keep_speed
	
	velocity.x = final_dir.x * push_speed
	velocity.z = final_dir.z * push_speed
	
	is_perching = false
	is_wall_riding = false
	can_wall_jump = false
	
	# print("wall jump executed")

func perform_perch_jump() -> void:
	velocity.y = jump_velocity * 0.8
	is_perching = false
	# print("perch jump executed")

func update_player_height(delta: float) -> void:
	# Interpolate capsule height
	current_capsule_height = lerp(current_capsule_height, target_capsule_height, delta * crouch_speed)
	# adjust collider position keeping feet fixed on ground
	var capsule_height_diff: float = capsule_height - current_capsule_height
	var capsule_half_diff: float = capsule_height_diff * 0.5
	# update collision shape
	cached_shape.height = current_capsule_height
	# update collider position
	collider.position.y = initial_collider_pos.y - capsule_half_diff
	# adjust mesh scale to match crouch height
	var height_ratio: float = current_capsule_height / capsule_height
	mesh.scale.y = height_ratio
	# adjust mesh postion to heep feet fixed on ground
	mesh.position.y = initial_mesh_position.y - capsule_half_diff

func reset_movement_stats() -> void:
	is_perching = false
	is_crouching = false
	is_wall_riding = false
