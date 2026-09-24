class_name weapons extends Resource

@export var name : StringName

@export_category("Weapons Stats")
@export var fire_rate : float #0.1 10/sec
@export var max_ammo : int
@export var total_ammo : int
@export var reload_time : float
@export var range : float
@export var Bullet : PackedScene

@export_category("Weapons Orientation")
@export var position : Vector3
@export var rotation : Vector3
@export var scale : Vector3
@export_category("Visual setting")
@export var modle : PackedScene
