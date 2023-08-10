extends Spatial
class_name RLEnvironment, "../icons/env_node_icon.png"

const STATUS_KEY = "status"
const CONFIG_KEY = "config"
const RESET_KEY = "reset"
const ACTION_KEY = "action"
const OBSERVATION_KEY = "observation"
const WORLD_KEY = "world"
const AGENT_KEY = "agent"
const ENVIRONMENT_KEY = "environment"

# The environment is designed for a single agent.
# One should assign the value in `_ready` function.
var agent: RLAgent

# The world the agent interacts with.
# One should assign the value in `_ready` function.
var world: RLEnvWorld

# Amount of physics steps to repeat same action.
onready var repeat_action: int = 4

# Timer in terms of physics frames.
onready var physics_frames_timer = PhysicsFramesTimer.new(repeat_action)

# Communication server to handle request via TCP protocol.
onready var communication = Communication.new()

func _enter_tree():
	# Disable physics on the environment launch.
	get_tree().set_pause(true)

# If one implements custom `_ready` method in his own subclass the method will be called nevertheless.
func _ready():
	# Environment is not pausable while `RLAgent` and `RLEnvWorld` are pausable.
	set_pause_mode(Node.PAUSE_MODE_PROCESS)
	communication.connect("got_connection", self, "_on_got_connection")

func _process(delta):
	communication.server_poll()

func _physics_process(delta):
	physics_frames_timer.step()

# One can extend the method to perform additional logic before or after or override it.
# Generally, the method enables physics processing to emulate real-time interaction.  
# Example:
# ```
#	func _step(action):
#		# some code here
#		yield(._step(action), "completed")
# ```
# or
# ```
# 	func _step(action):
#		# some code here
# 		agent.set_action(action)
# 		get_tree().set_pause(false)  # Enable physics	
# 		yield(physics_frames_timer.start(), "timer_end")
# 		get_tree().set_pause(true)  # Disable physics	
# ```
func _step(action):
	agent.set_action(action)
	get_tree().set_pause(false)  # Enable physics
	physics_frames_timer.start()
	yield(physics_frames_timer, "timer_end")
	get_tree().set_pause(true)  # Disable physics
	
# One should override the method in his own subclass.
# Generally, the method should reset a world and an agent.
func _reset():
	push_error("One should override the method in his own subclass.")

# Handle incoming connection
func _on_got_connection(request: Dictionary):
	if request.has(RESET_KEY):
		_reset()
	elif request.has(ACTION_KEY):
		yield(_step(request[ACTION_KEY]), "completed")
	elif request.has(CONFIG_KEY):
		_configure(request[CONFIG_KEY])
	elif request.has(STATUS_KEY):
		pass
	if request.has(OBSERVATION_KEY):
		_send_response(request[OBSERVATION_KEY])
		_after_send_response()
	communication.close()

# The method currently does not support any binary data. 
# One should override the method to implement such a logic.
func _send_response(observation_request: Dictionary):
	var response = Dictionary()
	if observation_request.has(AGENT_KEY):
		response[AGENT_KEY] = agent.get_data(observation_request[AGENT_KEY])
	if observation_request.has(WORLD_KEY):
		response[WORLD_KEY] = world.get_data(observation_request[WORLD_KEY])
	communication.put_json(response)

# Optional method to perform additional logic after response is sent.
func _after_send_response():
	pass

# One can extend or override the method to implement custom logic.
func _configure(configuration_request: Dictionary):
	if AGENT_KEY in configuration_request.keys():
		agent.configure(configuration_request[AGENT_KEY])
	if WORLD_KEY in configuration_request.keys():
		world.configure(configuration_request[WORLD_KEY])
	if ENVIRONMENT_KEY in configuration_request.keys():
		var env_config = configuration_request[ENVIRONMENT_KEY]
		if "repeat_action" in env_config.keys():
			repeat_action = env_config["repeat_action"]
			physics_frames_timer.set_limit(repeat_action)