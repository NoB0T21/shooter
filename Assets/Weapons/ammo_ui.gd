extends Label3D

func _ready() -> void:
	PlayerStats.ammo_update.connect(_on_ammo_update)
	_on_ammo_update(PlayerStats.ammos, PlayerStats.maxammos)

func _on_ammo_update(current:int, reserved:int) -> void:
	text = "%d / %d" % [current, reserved]
