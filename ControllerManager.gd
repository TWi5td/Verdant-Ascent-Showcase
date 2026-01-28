extends Node
## Manages gamepad/controller support for the game
## Handles analog stick input, deadzones, vibration, and device detection
## Note: Button inputs are handled through Godot's Input Map in Project Settings

signal controller_connected(device_id: int)
signal controller_disconnected(device_id: int)

# Controller settings
var use_controller := true
var current_device_id := 0
var connected_controllers: Array[int] = []

# Deadzone settings
var left_stick_deadzone := 0.15
var right_stick_deadzone := 0.15
var trigger_deadzone := 0.1

# Sensitivity settings
var look_sensitivity := 3.0  # Camera look sensitivity for right stick
var move_sensitivity := 1.0  # Movement sensitivity for left stick

# Camera settings
var invert_y_axis := false  # Invert Y-axis for camera look

# Vibration settings
var vibration_enabled := true
var vibration_strength := 1.0  # 0.0 to 1.0

# Axis mappings
var axis_map := {
	"move_left_right": JOY_AXIS_LEFT_X,
	"move_forward_back": JOY_AXIS_LEFT_Y,
	"look_left_right": JOY_AXIS_RIGHT_X,
	"look_up_down": JOY_AXIS_RIGHT_Y,
	"trigger_left": JOY_AXIS_TRIGGER_LEFT,
	"trigger_right": JOY_AXIS_TRIGGER_RIGHT
}

const SETTINGS_PATH := "user://controller_settings.cfg"
var config := ConfigFile.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_controller_settings()  # Load settings first
	_detect_controllers()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	print("ControllerManager initialized")
	print("  - Use Controller: ", use_controller)
	print("  - Look Sensitivity: ", look_sensitivity)
	print("  - Invert Y-axis: ", invert_y_axis)
	print("  - Left Deadzone: ", left_stick_deadzone)
	print("  - Right Deadzone: ", right_stick_deadzone)

func _detect_controllers() -> void:
	connected_controllers.clear()
	for device in Input.get_connected_joypads():
		connected_controllers.append(device)
		if connected_controllers.size() == 1:
			current_device_id = device
	
	if connected_controllers.size() > 0:
		print("Detected %d controller(s)" % connected_controllers.size())
		print("Controller name: %s" % Input.get_joy_name(current_device_id))

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if not connected_controllers.has(device):
			connected_controllers.append(device)
		if connected_controllers.size() == 1:
			current_device_id = device
		print("Controller connected: %s (ID: %d)" % [Input.get_joy_name(device), device])
		controller_connected.emit(device)
	else:
		connected_controllers.erase(device)
		if device == current_device_id and connected_controllers.size() > 0:
			current_device_id = connected_controllers[0]
		print("Controller disconnected (ID: %d)" % device)
		controller_disconnected.emit(device)

func is_controller_connected() -> bool:
	return connected_controllers.size() > 0

func get_controller_name() -> String:
	if is_controller_connected():
		return Input.get_joy_name(current_device_id)
	return "No Controller"

## Get movement input from left stick with deadzone
func get_movement_input() -> Vector2:
	if not is_controller_connected() or not use_controller:
		return Vector2.ZERO
	
	var raw_input := Vector2(
		Input.get_joy_axis(current_device_id, axis_map["move_left_right"]),
		Input.get_joy_axis(current_device_id, axis_map["move_forward_back"])
	)
	
	return apply_deadzone(raw_input, left_stick_deadzone) * move_sensitivity

## Get look input from right stick with deadzone
func get_look_input() -> Vector2:
	if not is_controller_connected() or not use_controller:
		return Vector2.ZERO
	
	var raw_input := Vector2(
		Input.get_joy_axis(current_device_id, axis_map["look_left_right"]),
		Input.get_joy_axis(current_device_id, axis_map["look_up_down"])
	)
	
	var look := apply_deadzone(raw_input, right_stick_deadzone) * (look_sensitivity / 100)
	
	# Apply Y-axis inversion if enabled
	if invert_y_axis:
		look.y = -look.y
	
	return look

## Apply circular deadzone to stick input
func apply_deadzone(input: Vector2, deadzone: float) -> Vector2:
	var magnitude := input.length()
	
	if magnitude < deadzone:
		return Vector2.ZERO
	
	# Normalize and rescale to remove deadzone
	var normalized := input.normalized()
	var adjusted_magnitude := (magnitude - deadzone) / (1.0 - deadzone)
	
	return normalized * adjusted_magnitude

## Get trigger value (0.0 to 1.0)
func get_trigger_value(is_right_trigger: bool = true) -> float:
	if not is_controller_connected() or not use_controller:
		return 0.0
	
	var axis: JoyAxis = axis_map["trigger_right"] if is_right_trigger else axis_map["trigger_left"]
	var value := Input.get_joy_axis(current_device_id, axis)
	
	# Apply deadzone
	if abs(value) < trigger_deadzone:
		return 0.0
	
	return clamp((abs(value) - trigger_deadzone) / (1.0 - trigger_deadzone), 0.0, 1.0)

## Vibrate controller (rumble)
func vibrate(weak_magnitude: float = 0.0, strong_magnitude: float = 0.0, duration: float = 0.2) -> void:
	if not is_controller_connected() or not vibration_enabled:
		return
	
	# Apply vibration strength multiplier
	weak_magnitude *= vibration_strength
	strong_magnitude *= vibration_strength
	
	Input.start_joy_vibration(current_device_id, weak_magnitude, strong_magnitude, duration)

## Stop controller vibration
func stop_vibration() -> void:
	if is_controller_connected():
		Input.stop_joy_vibration(current_device_id)

## Vibration presets
func vibrate_light() -> void:
	vibrate(0.3, 0.0, 0.1)

func vibrate_medium() -> void:
	vibrate(0.5, 0.3, 0.2)

func vibrate_heavy() -> void:
	vibrate(0.7, 0.9, 0.3)

## Settings Management
func load_controller_settings() -> void:
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		print("No controller settings file found, using defaults")
		return
	
	use_controller = config.get_value("controller", "enabled", use_controller)
	left_stick_deadzone = config.get_value("controller", "left_deadzone", left_stick_deadzone)
	right_stick_deadzone = config.get_value("controller", "right_deadzone", right_stick_deadzone)
	trigger_deadzone = config.get_value("controller", "trigger_deadzone", trigger_deadzone)
	look_sensitivity = config.get_value("controller", "look_sensitivity", look_sensitivity)
	move_sensitivity = config.get_value("controller", "move_sensitivity", move_sensitivity)
	invert_y_axis = config.get_value("controller", "invert_y_axis", invert_y_axis)
	vibration_enabled = config.get_value("controller", "vibration_enabled", vibration_enabled)
	vibration_strength = config.get_value("controller", "vibration_strength", vibration_strength)
	
	print("Controller settings loaded:")
	print("  - Look Sensitivity: ", look_sensitivity)
	print("  - Invert Y: ", invert_y_axis)

func save_controller_settings() -> void:
	config.set_value("controller", "enabled", use_controller)
	config.set_value("controller", "left_deadzone", left_stick_deadzone)
	config.set_value("controller", "right_deadzone", right_stick_deadzone)
	config.set_value("controller", "trigger_deadzone", trigger_deadzone)
	config.set_value("controller", "look_sensitivity", look_sensitivity)
	config.set_value("controller", "move_sensitivity", move_sensitivity)
	config.set_value("controller", "invert_y_axis", invert_y_axis)
	config.set_value("controller", "vibration_enabled", vibration_enabled)
	config.set_value("controller", "vibration_strength", vibration_strength)
	
	var err := config.save(SETTINGS_PATH)
	if err == OK:
		print("Controller settings saved successfully")
		print("  - Look Sensitivity: ", look_sensitivity)
		print("  - File path: ", SETTINGS_PATH)
	else:
		push_error("Failed to save controller settings: " + str(err))
