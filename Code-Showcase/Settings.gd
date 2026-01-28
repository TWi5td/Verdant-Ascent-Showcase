extends Node

const SETTINGS_PATH := "user://settings.cfg"
var config := ConfigFile.new()

# Defaults
var fullscreen := false
var vsync := true
var resolution := Vector2(1280, 720)

var master_volume := 100.0
var music_volume := 100.0
var sfx_volume := 100.0

var keybinds := {
	"forward": KEY_W,
	"backward": KEY_S,
	"left": KEY_A,
	"right": KEY_D,
	"jump": KEY_SPACE,
	"crouch": KEY_C,
	"sprint": KEY_SHIFT,
	"exit": KEY_ESCAPE,
	"debug": KEY_F3
}

# Controller button bindings
var controller_binds := {
	"jump": JOY_BUTTON_A,
	"crouch": JOY_BUTTON_B,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"interact": JOY_BUTTON_X,
	"pause": JOY_BUTTON_START,
	"back": JOY_BUTTON_BACK
}

signal settings_ready

func _ready() -> void:
	load_cfg()
	apply_all()
	emit_signal("settings_ready")
	
	print(OS.get_data_dir())

func load_cfg() -> void:
	if config.load(SETTINGS_PATH) != OK:
		return
	
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	vsync = config.get_value("video", "vsync", vsync)
	resolution = config.get_value("video", "resolution", resolution)
	
	master_volume = config.get_value("audio", "master", master_volume)
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	
	for action: String in keybinds.keys():
		keybinds[action] = config.get_value("input", action, keybinds[action])
	
	# Load controller bindings
	for action: String in controller_binds.keys():
		controller_binds[action] = config.get_value("controller_input", action, controller_binds[action])

func save_video(set_only := false) -> void:
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "resolution", resolution)
	if not set_only: config.save(SETTINGS_PATH)

func save_audio(set_only := false) -> void:
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	if not set_only: config.save(SETTINGS_PATH)

func save_keybinds(set_only := false) -> void:
	for action: String in keybinds.keys():
		config.set_value("input", action, keybinds[action])
	if not set_only: config.save(SETTINGS_PATH)

func save_controller_binds(set_only := false) -> void:
	for action: String in controller_binds.keys():
		config.set_value("controller_input", action, controller_binds[action])
	if not set_only: config.save(SETTINGS_PATH)

func save_all() -> void:
	save_video(true)
	save_audio(true)
	save_keybinds(true)
	save_controller_binds()
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Failed to save settings: " + str(err))

func center_window() -> void:
	var screen_center: Vector2i = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
	var window_size: Vector2i = DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_center - window_size / 2)

func apply_video() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(resolution)
	
	GameEvents.settings_changed.emit("video", {
		"fullscreen": fullscreen,
		"vsync": vsync,
		"resolution": resolution
	})
	
	# center window when not in full screen
	if not fullscreen:
		await get_tree().process_frame
		center_window()

func apply_audio() -> void:
	var buses := ["Master", "Music", "SFX"]
	for bus_name: String in buses:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			push_warning("Audio bus '%s' not found" % bus_name)
			continue
		
		var volume: float = 0.0
		match bus_name:
			"Master": volume = master_volume
			"Music": volume = music_volume
			"SFX": volume = sfx_volume
		
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume / 100.0))

func apply_keybinds() -> void:
	for action: String in keybinds.keys():
		if InputMap.has_action(action):
			# Remove keyboard events only, keep controller events
			var events_to_remove: Array[InputEvent] = []
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:
					events_to_remove.append(event)
			for event in events_to_remove:
				InputMap.action_erase_event(action, event)
			
			# Add new keyboard binding
			var event_key: InputEventKey = InputEventKey.new()
			event_key.keycode = keybinds[action]
			InputMap.action_add_event(action, event_key)

func apply_controller_binds() -> void:
	for action: String in controller_binds.keys():
		if InputMap.has_action(action):
			# Remove controller events only, keep keyboard events
			var events_to_remove: Array[InputEvent] = []
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadButton:
					events_to_remove.append(event)
			for event in events_to_remove:
				InputMap.action_erase_event(action, event)
			
			# Add new controller binding
			var event_button: InputEventJoypadButton = InputEventJoypadButton.new()
			event_button.button_index = controller_binds[action]
			InputMap.action_add_event(action, event_button)

func apply_all() -> void:
	apply_video()
	apply_audio()
	apply_keybinds()
	apply_controller_binds()
