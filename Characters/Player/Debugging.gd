extends PanelContainer
@onready var property_container: VBoxContainer = %Debug_VBoxContainer

var property := {}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		visible = !visible

func add_debug_property(title: String, value: String) -> void:
	if not property.has(title):
		var lable :Label = Label.new()
		property_container.add_child(lable)
		property[title] = lable
	property[title].text = title + ": "+ value
