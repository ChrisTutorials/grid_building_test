class_name GBTestConfigManager
extends RefCounted

## Test configuration manager that provides centralized test configuration
## and helps minimize setup failure points by managing test parameters

# ================================
# Test Configuration Constants
# ================================

const DEFAULT_TEST_CONFIG = {
	"tile_size": 16,
	"grid_size": 40,
	"collision_extents": Vector2(8, 8),
	"circle_radius": 8.0,
	"capsule_radius": 48.0,
	"capsule_height": 128.0,
	"test_timeout": 30.0,
	"max_retries": 3,
	"log_level": "INFO"
}

const PERFORMANCE_TEST_CONFIG = {
	"tile_size": 32,
	"grid_size": 100,
	"collision_extents": Vector2(16, 16),
	"circle_radius": 16.0,
	"capsule_radius": 64.0,
	"capsule_height": 256.0,
	"test_timeout": 60.0,
	"max_retries": 1,
	"log_level": "WARNING"
}

const DEBUG_TEST_CONFIG = {
	"tile_size": 8,
	"grid_size": 20,
	"collision_extents": Vector2(4, 4),
	"circle_radius": 4.0,
	"capsule_radius": 24.0,
	"capsule_height": 64.0,
	"test_timeout": 120.0,
	"max_retries": 5,
	"log_level": "DEBUG"
}

# ================================
# Configuration Management
# ================================

## Get the current test configuration
static func get_test_config() -> Dictionary:
	var config = DEFAULT_TEST_CONFIG.duplicate()
	
	# Override with environment variables if available
	var env_config = _get_environment_config()
	for key in env_config:
		config[key] = env_config[key]
	
	return config

## Get a specific configuration value
static func get_config_value(key: String, default_value = null):
	var config = get_test_config()
	return config.get(key, default_value)

## Set a configuration value
static func set_config_value(key: String, value) -> void:
	var config = get_test_config()
	config[key] = value

## Get environment-specific configuration
static func get_environment_config(environment: String = "") -> Dictionary:
	match environment.to_upper():
		"PERFORMANCE":
			return PERFORMANCE_TEST_CONFIG.duplicate()
		"DEBUG":
			return DEBUG_TEST_CONFIG.duplicate()
		_:
			return DEFAULT_TEST_CONFIG.duplicate()

# ================================
# Test Parameter Generation
# ================================

## Generate test parameters based on configuration
static func generate_test_parameters(param_type: String, count: int = 5) -> Array:
	var config = get_test_config()
	var params = []
	
	match param_type.to_upper():
		"TILE_SIZE":
			var base_size = config.tile_size
			for i in range(count):
				params.append(base_size * (i + 1))
		"GRID_SIZE":
			var base_size = config.grid_size
			for i in range(count):
				params.append(base_size / (i + 1))
		"COLLISION_EXTENTS":
			var base_extents = config.collision_extents
			for i in range(count):
				params.append(base_extents * (i + 1))
		"CIRCLE_RADIUS":
			var base_radius = config.circle_radius
			for i in range(count):
				params.append(base_radius * (i + 1))
		"CAPSULE_RADIUS":
			var base_radius = config.capsule_radius
			for i in range(count):
				params.append(base_radius * (i + 1))
		"CAPSULE_HEIGHT":
			var base_height = config.capsule_height
			for i in range(count):
				params.append(base_height * (i + 1))
		_:
			params = [1, 2, 4, 8, 16] # Default fallback
	
	return params

## Generate test positions based on configuration
static func generate_test_positions(
	start_pos: Vector2 = Vector2.ZERO,
	end_pos: Vector2 = Vector2(100, 100),
	step_multiplier: float = 1.0
) -> Array[Vector2]:
	var config = get_test_config()
	var tile_size = config.tile_size
	var step = Vector2(tile_size, tile_size) * step_multiplier
	
	var positions: Array[Vector2] = []
	var current = start_pos
	
	while current.x <= end_pos.x and current.y <= end_pos.y:
		positions.append(current)
		current += step
	
	return positions

## Generate test transforms with configuration-based variations
static func generate_test_transforms(
	base_transform: Transform2D = Transform2D.IDENTITY,
	position_count: int = 5,
	rotation_count: int = 4,
	scale_count: int = 3
) -> Array[Transform2D]:
	var config = get_test_config()
	var tile_size = config.tile_size
	
	var transforms: Array[Transform2D] = []
	
	# Generate position variations
	var positions = []
	for i in range(position_count):
		positions.append(Vector2(i * tile_size, i * tile_size))
	
	# Generate rotation variations
	var rotations = []
	for i in range(rotation_count):
		rotations.append(i * PI / 2)
	
	# Generate scale variations
	var scales = []
	for i in range(scale_count):
		scales.append(Vector2.ONE * (i + 1))
	
	# Combine all variations
	for pos in positions:
		for rot in rotations:
			for scale in scales:
				var transform = base_transform
				transform.origin = pos
				transform = transform.rotated(rot)
				transform = transform.scaled(scale)
				transforms.append(transform)
	
	return transforms

# ================================
# Test Validation Configuration
# ================================

## Get validation rules based on configuration
static func get_validation_rules() -> Dictionary:
	var config = get_test_config()
	
	return {
		"max_execution_time": config.test_timeout,
		"max_retry_attempts": config.max_retries,
		"required_log_level": config.log_level,
		"validate_dependencies": true,
		"validate_scene_graph": true,
		"validate_resource_loading": true
	}

## Get performance thresholds based on configuration
static func get_performance_thresholds() -> Dictionary:
	var config = get_test_config()
	
	return {
		"setup_time_threshold": 5.0,
		"execution_time_threshold": config.test_timeout * 0.8,
		"cleanup_time_threshold": 3.0,
		"memory_usage_threshold": 100 * 1024 * 1024, # 100MB
		"frame_time_threshold": 16.67 # 60 FPS
	}

# ================================
# Environment Configuration
# ================================

## Get configuration from environment variables
static func _get_environment_config() -> Dictionary:
	var env_config = {}
	
	# Check for test environment variable
	var test_env = OS.get_environment("TEST_ENVIRONMENT")
	if test_env:
		env_config["environment"] = test_env
	
	# Check for test timeout
	var test_timeout = OS.get_environment("TEST_TIMEOUT")
	if test_timeout:
		env_config["test_timeout"] = test_timeout.to_float()
	
	# Check for log level
	var log_level = OS.get_environment("TEST_LOG_LEVEL")
	if log_level:
		env_config["log_level"] = log_level
	
	# Check for retry count
	var retry_count = OS.get_environment("TEST_MAX_RETRIES")
	if retry_count:
		env_config["max_retries"] = retry_count.to_int()
	
	return env_config

## Set environment variables for testing
static func set_test_environment(environment: String) -> void:
	OS.set_environment("TEST_ENVIRONMENT", environment)
	
	var config = get_environment_config(environment)
	for key in config:
		OS.set_environment("TEST_%s" % key.to_upper(), str(config[key]))

# ================================
# Configuration Validation
# ================================

## Validate that the current configuration is valid
static func validate_configuration() -> Array[String]:
	var issues: Array[String] = []
	var config = get_test_config()
	
	# Check for required values
	var required_keys = ["tile_size", "grid_size", "test_timeout", "max_retries"]
	for key in required_keys:
		if not config.has(key) or config[key] == null:
			issues.append("Missing required configuration key: %s" % key)
	
	# Check for valid value ranges
	if config.has("tile_size") and config.tile_size <= 0:
		issues.append("Tile size must be positive")
	
	if config.has("grid_size") and config.grid_size <= 0:
		issues.append("Grid size must be positive")
	
	if config.has("test_timeout") and config.test_timeout <= 0:
		issues.append("Test timeout must be positive")
	
	if config.has("max_retries") and config.max_retries < 0:
		issues.append("Max retries cannot be negative")
	
	return issues

## Check if configuration is valid for testing
static func is_configuration_valid() -> bool:
	var issues = validate_configuration()
	return issues.size() == 0

# ================================
# Configuration Persistence
# ================================

## Save configuration to a file
static func save_configuration(file_path: String, config: Dictionary = {}) -> bool:
	var target_config = config if config.size() > 0 else get_test_config()
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(JSON.stringify(target_config))
	file.close()
	return true

## Load configuration from a file
static func load_configuration(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		return {}
	
	return json.data

## Reset configuration to defaults
static func reset_configuration() -> void:
	# Clear environment variables
	var env_vars = ["TEST_ENVIRONMENT", "TEST_TIMEOUT", "TEST_LOG_LEVEL", "TEST_MAX_RETRIES"]
	for env_var in env_vars:
		OS.unset_environment(env_var)
	
	# Reset to default config
	var config = DEFAULT_TEST_CONFIG.duplicate()
	for key in config:
		set_config_value(key, config[key])
