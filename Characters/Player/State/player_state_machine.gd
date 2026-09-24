class_name StateMachine
extends Node

@export var CURRENT_STATE: State
var States: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			States[child.name] = child
			child.transition.connect(on_child_transition)
		else :
			push_warning("State machine contains incampatibale child node")
	
	await  owner.ready
	CURRENT_STATE.enter()

func _process(delta: float) -> void:
	CURRENT_STATE.update(delta)

func _physics_process(delta: float) -> void:
	CURRENT_STATE.physics_update(delta)

func on_child_transition(new_state_name: StringName) -> void:
	var new_state :State = States.get(new_state_name)
	if new_state != null:
		if DebugPanel.visible:
			DebugPanel.add_debug_property("State",new_state_name)
		if new_state != CURRENT_STATE:
			CURRENT_STATE.exit()
			PlayerStats._is_sliding = false
			PlayerStats.cost = 0.0
			new_state.enter()
			CURRENT_STATE = new_state
	else :
		push_warning("State does not exist")
