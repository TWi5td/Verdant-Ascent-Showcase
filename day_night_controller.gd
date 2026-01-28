extends Node

@export var cycle_duration_seconds: float = 900.0
@export var sunrise_hour: float = 6.0
@export var sunset_hour: float = 18.0
@export var show_sun_disc: bool = false
@export var sun_disc_size: float = 20.0  # Size of the visible sun disc

@onready var sun_pivot : Node3D = $"../SunPivot"
@onready var sun_light : DirectionalLight3D = $"../SunPivot/SunLight"
@onready var sun_disc : MeshInstance3D = $"../SunPivot/SunDisc"
@onready var env: Environment = $"../WorldEnvironment".environment
@onready var sky_mesh: MeshInstance3D = $"../LowPolySky"

var time_of_day: float = 0.0

func _ready() -> void:
	time_of_day = sunrise_hour
	
	sun_pivot.global_position = Vector3.ZERO  # SunPivot at world center
	var sun_distance: float = 500.0
	var disc_distance: float = 450.0  # Closer than light so it's always in front
	
	# Position the directional light
	sun_light.position = Vector3(0, sun_distance, 0)
	
	# Rotate the directional light to point down toward the pivot center
	sun_light.rotation.x = -PI / 2  # Point downward (-90 degrees)
	
	# Configure sun disc - position it closer so it appears in front
	if sun_disc:
		sun_disc.position = Vector3(0, disc_distance, 0)
		sun_disc.visible = show_sun_disc
		
		if sun_disc.mesh is SphereMesh:
			var sphere_mesh = sun_disc.mesh as SphereMesh
			sphere_mesh.radius = sun_disc_size
			sphere_mesh.height = sun_disc_size * 2
	
	# Disable glow/bloom for cleaner look
	if env:
		env.glow_enabled = false

func _process(delta: float) -> void:
	# advance time
	time_of_day += (24.0 / cycle_duration_seconds) * delta
	if time_of_day >= 24.0:
		time_of_day -= 24.0
	
	# Rotate sun around X axis (east to west arc)
	# Map time_of_day to angle: 6am (sunrise) = -90°, 12pm (noon) = 0°, 6pm (sunset) = 90°
	var hour_angle: float = ((time_of_day - 12.0) / 12.0) * PI  # -PI to PI range
	sun_pivot.rotation.x = hour_angle
	
	# Calculate sun height for lighting (-1 to 1, where 1 is noon)
	var sun_height: float = sin(hour_angle + PI/2)
	
	# Smooth transition factor with twilight periods
	var transition_factor: float = smoothstep(-0.2, 0.2, sun_height)
	
	# Light intensity with smooth fade
	sun_light.light_energy = transition_factor * 1.5
	sun_light.visible = transition_factor > 0.01
	
	# Sun color changes based on height (redder near horizon)
	var sun_color: Color
	if sun_height < 0.2:  # Near horizon
		sun_color = Color(1.0, 0.6, 0.3)  # Orange/red
	else:
		sun_color = Color(1.0, 0.95, 0.9).lerp(Color(1.0, 0.6, 0.3), 1.0 - sun_height)
	
	# Set light color
	sun_light.light_color = sun_color
	
	# Update sun disc if visible
	if sun_disc and show_sun_disc:
		sun_disc.visible = transition_factor > 0.01
		
		if sun_disc.visible:
			var disc_mat := sun_disc.get_surface_override_material(0)
			if not disc_mat:
				disc_mat = StandardMaterial3D.new()
				sun_disc.set_surface_override_material(0, disc_mat)
			
			disc_mat.emission_enabled = true
			disc_mat.emission_energy_multiplier = 0.5  # Very subtle glow
			disc_mat.emission = sun_color
			disc_mat.albedo_color = sun_color
			disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Sky tint with smooth transitions
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
		
		# Day colors
		var day_top: Color = Color("87CEEB")      # sky blue
		var day_horizon: Color = Color("FFA500")  # orange

		# Twilight colors
		var twilight_top: Color = Color("4A5A8A")  # purple-blue
		var twilight_horizon: Color = Color("FF6B35")  # orange-red

		# Night colors
		var night_top: Color = Color("0A0A1F")
		var night_horizon: Color = Color("1C2526")
		
		# Blend based on sun position
		if transition_factor > 0.5:  # Day
			var day_blend: float = (transition_factor - 0.5) * 2.0
			sky_mat.sky_top_color = twilight_top.lerp(day_top, day_blend)
			sky_mat.sky_horizon_color = twilight_horizon.lerp(day_horizon, day_blend)
		else:  # Night/Twilight
			var night_blend: float = transition_factor * 2.0
			sky_mat.sky_top_color = night_top.lerp(twilight_top, night_blend)
			sky_mat.sky_horizon_color = night_horizon.lerp(twilight_horizon, night_blend)
	
	# low poly sky gradient
	if sky_mesh:
		var sky_shader_mat: ShaderMaterial = sky_mesh.get_surface_override_material(0)
		if sky_shader_mat:
			sky_shader_mat.set_shader_parameter("time", time_of_day)

func _hour_to_normalized(h: float) -> float:
	var normalized: float = (h - sunrise_hour) / (sunset_hour - sunrise_hour)
	return clamp(normalized, 0.0, 1.0)
