class_name Door
extends StaticBody2D
## 实体门：可打开/关闭，影响碰撞和视线遮挡
## 对应 Bible 04_physics：关闭时阻挡身体及弹丸；影响可见性遮挡

signal opened(door_id: String)
signal closed(door_id: String)

@export var door_id: String = ""
@export var is_open: bool = false
@export var collision_shape: CollisionShape2D = null
@export var occluder: LightOccluder2D = null


func _ready() -> void:
	_update_state()


func open() -> void:
	if is_open:
		return
	is_open = true
	_update_state()
	opened.emit(door_id)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_update_state()
	closed.emit(door_id)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _update_state() -> void:
	## 碰撞：关闭时启用，打开时禁用
	if collision_shape != null:
		collision_shape.disabled = is_open
	## 遮挡：关闭时启用，打开时禁用（让光线和视线通过）
	if occluder != null:
		occluder.visible = not is_open


func get_persistent_state() -> Dictionary:
	return {"is_open": is_open}


func restore_persistent_state(state: Dictionary) -> void:
	is_open = state.get("is_open", false)
	_update_state()
