extends Node

# 预加载场景
@onready var instance_scene = preload("res://Scenes/app_instance.tscn")

# 实例管理容器
var item_dict: Dictionary = {}
var items: Array = []

func create_instance(proc: Dictionary, ip: String, http_port: String, streaming_port: String, app_path: String) -> void:
	# 实例化场景
	var temp_instance = instance_scene.instantiate()
	add_child(temp_instance)
	temp_instance._init_item(proc, ip, http_port, streaming_port, app_path)
	item_dict[streaming_port] = temp_instance
	items.append(temp_instance)
	
func remove_instance(streaming_port: String) -> void:
	# 查找并移除特定实例
	if item_dict.has(streaming_port):
		var instance = item_dict[streaming_port]
		items.erase(instance)
		item_dict.erase(streaming_port)
		instance.queue_free()

func clear_all_instances() -> void:
	# 移除所有实例
	for child in get_children():
		child.queue_free()
