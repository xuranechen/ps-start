extends Node


var process = null
var http_ip = ""
var http_port = ""
var streaming_port = ""
var app_path = ""
var is_connect = false
var is_ready = false
var connected_users = 0
var timer = 10
var ready_time = 0

@onready var manager = $"../../../../.."
@onready var instance_manager = $".."
@onready var bg = $ColorRect
@onready var ip_address = $ColorRect/VBoxContainer/IPAddress
@onready var app_name = $ColorRect/VBoxContainer/AppName
@onready var run_times = $ColorRect/VBoxContainer/RunTimes
@onready var users = $ColorRect/VBoxContainer/Users
@onready var close_btn = $ColorRect/VBoxContainer/Button

func _init_item(proc: Dictionary, ip: String , port: String, stream_port: String, exe_path: String) -> void:
	process = proc
	http_ip = ip
	http_port = port
	streaming_port = stream_port
	app_path = exe_path
	bg.color = Color(0.5, 0.5, 0.5)
	ip_address.text = "http://" + http_ip + ":" + http_port + "/"
	app_name.text = exe_path

func _close_instance() -> void:
	manager._stop_cirrus_instance(int(streaming_port))
	manager._stop_app_instance(int(streaming_port))
	instance_manager.item_dict[streaming_port] = null
	instance_manager.items.erase(self)
	queue_free()

# 实例是否准备好
func _client_ready(state: bool) -> void:
	is_ready = state
	if not is_ready:
		bg.color = Color(0.5, 0.5, 0.5)  # 灰色
	else:
		bg.color = Color(0, 0, 1)  # 蓝色
		ready_time = Time.get_unix_time_from_system()

# 有用户连接到实例
func _client_connected() -> void:
	connected_users += 1
	users.text = str(connected_users)
	is_connect = true
	bg.color = Color(0, 0.482, 0.145)  # 绿色

# 用户从实例断开
func _client_disconnected() -> void:
	if connected_users > 0:
		connected_users -= 1
		users.text = str(connected_users)
	
	if connected_users > 0 or not is_ready:
		return
	
	is_connect = false
	bg.color = Color(0, 0, 1)  # 蓝色
	get_tree().create_timer(10).timeout.connect(_delay_destroy)

# 无用户连接时，实例自动释放
func _delay_destroy() -> void:
	if not is_connect:
		_close_instance()

func _process(delta: float) -> void:
	if not is_ready:
		return
	run_times.text = str(int(Time.get_unix_time_from_system() - ready_time))
